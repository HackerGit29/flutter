import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

const AZURE_ENDPOINT = Deno.env.get("AZURE_OPENAI_ENDPOINT") ?? "";
const AZURE_KEY = Deno.env.get("AZURE_OPENAI_API_KEY") ?? "";
const AZURE_EMBED_DEPLOYMENT = Deno.env.get("AZURE_OPENAI_EMBEDDING_DEPLOYMENT") ??
  "text-embedding-3-small";
const AZURE_CHAT_DEPLOYMENT = Deno.env.get("AZURE_OPENAI_DEPLOYMENT") ?? "gpt-4o";
const AZURE_API_VERSION = Deno.env.get("AZURE_OPENAI_API_VERSION") ?? "2024-10-21";

function yesterdayISO(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
}

async function azureEmbedding(text: string): Promise<number[] | null> {
  if (!AZURE_ENDPOINT || !AZURE_KEY) return null;
  try {
    const res = await fetch(
      `${AZURE_ENDPOINT}/openai/deployments/${AZURE_EMBED_DEPLOYMENT}/embeddings?api-version=${AZURE_API_VERSION}`,
      {
        method: "POST",
        headers: { "api-key": AZURE_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({ input: text }),
      },
    );
    if (!res.ok) return null;
    const json = await res.json();
    return json.data?.[0]?.embedding ?? null;
  } catch {
    return null;
  }
}

async function azureSummary(prompt: string): Promise<string | null> {
  if (!AZURE_ENDPOINT || !AZURE_KEY) return null;
  try {
    const res = await fetch(
      `${AZURE_ENDPOINT}/openai/deployments/${AZURE_CHAT_DEPLOYMENT}/chat/completions?api-version=${AZURE_API_VERSION}`,
      {
        method: "POST",
        headers: { "api-key": AZURE_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: [
            {
              role: "system",
              content:
                "Tu génères des résumés FR courts de consommation énergétique quotidienne. " +
                "Réponds en 2-3 phrases maximum.",
            },
            { role: "user", content: prompt },
          ],
          temperature: 0.3,
          max_tokens: 200,
        }),
      },
    );
    if (!res.ok) return null;
    const json = await res.json();
    return json.choices?.[0]?.message?.content ?? null;
  } catch {
    return null;
  }
}

async function summarizeUser(userId: string, date: string) {
  const { data: rows, error } = await supabase
    .from("energy_data")
    .select("appliance_id, total_day, appliances!inner(name, location)")
    .eq("user_id", userId)
    .eq("date", date);

  if (error) {
    console.error(`[summarizer] ${userId} read error:`, error);
    return;
  }

  if (!rows || rows.length === 0) return; // pas de data, on skip

  const total = rows.reduce(
    (acc: number, r: any) => acc + Number(r.total_day ?? 0),
    0,
  );
  const top = rows
    .slice()
    .sort((a: any, b: any) => Number(b.total_day) - Number(a.total_day))
    .slice(0, 5)
    .map((r: any) =>
      `- ${r.appliances?.name ?? "?"} (${r.appliances?.location ?? "?"}): ${
        Number(r.total_day).toFixed(2)
      } kWh`
    )
    .join("\n");

  const prompt =
    `Date : ${date}\nTotal du jour : ${total.toFixed(2)} kWh\n` +
    `Détail par appareil :\n${top}\n` +
    `Génère un résumé conversationnel FR pour cet utilisateur.`;
  const summary = await azureSummary(prompt);
  if (!summary) {
    console.warn(`[summarizer] ${userId} Azure KO, skip embedding`);
    return;
  }

  const embedding = await azureEmbedding(summary);
  if (!embedding) {
    console.warn(`[summarizer] ${userId} embedding KO, skip upsert`);
    return;
  }

  const sourceId = `${userId}:${date}`;
  const { error: upsertError } = await supabase
    .from("chat_embeddings")
    .upsert(
      {
        owner_id: userId,
        scope: "user",
        source_type: "consumption_summary",
        source_id: sourceId,
        content: summary,
        metadata: {
          source_type: "consumption_summary",
          date,
          total_kwh: total,
        },
        embedding,
      },
      { onConflict: "source_id" },
    );

  if (upsertError) {
    console.error(`[summarizer] ${userId} upsert error:`, upsertError);
  } else {
    console.log(`[summarizer] ${userId} ${date} OK (${total.toFixed(2)} kWh)`);
  }
}

Deno.serve(async () => {
  const date = yesterdayISO();

  const { data: users, error } = await supabase
    .from("subscriptions")
    .select("user_id")
    .eq("is_active", true);

  if (error) {
    console.error("[summarizer] users lookup error:", error);
    return new Response(JSON.stringify({ ok: false, error: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  for (const row of users ?? []) {
    await summarizeUser(row.user_id, date);
  }

  return new Response(JSON.stringify({ ok: true, date, count: users?.length ?? 0 }), {
    headers: { "Content-Type": "application/json" },
  });
});
