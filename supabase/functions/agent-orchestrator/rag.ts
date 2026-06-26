/**
 * Calcule un embedding via Azure OpenAI (text-embedding-3-small).
 */
export async function createEmbedding(input: string): Promise<number[]> {
  const endpoint = Deno.env.get("AZURE_OPENAI_ENDPOINT");
  const apiKey = Deno.env.get("AZURE_OPENAI_API_KEY");
  const deployment = Deno.env.get("AZURE_OPENAI_EMBEDDING_DEPLOYMENT") ??
    "text-embedding-3-small";
  const apiVersion = Deno.env.get("AZURE_OPENAI_API_VERSION") ?? "2024-10-21";

  if (!endpoint || !apiKey) {
    throw new Error("Azure OpenAI non configuré pour les embeddings.");
  }

  const url =
    `${endpoint}/openai/deployments/${deployment}/embeddings?api-version=${apiVersion}`;

  const dimensions = Deno.env.get("AZURE_OPENAI_EMBEDDING_DIMENSIONS");

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "api-key": apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      input,
      ...(dimensions ? { dimensions: parseInt(dimensions) } : {}),
    }),
  });

  if (!response.ok) {
    throw new Error(await response.text());
  }

  const json = await response.json();
  return json.data[0].embedding;
}

/**
 * Recherche les embeddings pertinents pour un utilisateur.
 * Utilise la fonction RPC match_user_embeddings scope par owner_id.
 */
export async function searchUserRag(params: {
  supabase: any;
  requesterId: string;
  query: string;
}) {
  try {
    const embedding = await createEmbedding(params.query);

    const { data, error } = await params.supabase.rpc("match_user_embeddings", {
      query_embedding: embedding,
      requester_id: params.requesterId,
      match_count: 5,
    });

    if (error) throw error;

    return data ?? [];
  } catch (error) {
    console.error("RAG search error:", error);
    return [];
  }
}

/**
 * Recherche dans le RAG utilisateur et ne garde QUE les résumés conso.
 * Le match_user_embeddings RPC filtre déjà par owner_id (sécurité préservée).
 */
export async function searchConsumptionSummaries(params: {
  supabase: any;
  requesterId: string;
  query: string;
  matchCount?: number;
}) {
  const results = await searchUserRag(params);
  return (results ?? []).filter(
    (r: any) => r.metadata?.source_type === "consumption_summary",
  );
}

/**
 * RAG complet = docs user classiques + résumés conso, dédoublonnés par id.
 * Remplace l'appel direct à searchUserRag dans index.ts.
 */
export async function searchCombinedUserRag(params: {
  supabase: any;
  requesterId: string;
  query: string;
}) {
  const [docs, summaries] = await Promise.all([
    searchUserRag(params).then((rows) =>
      (rows ?? []).filter(
        (r: any) => r.metadata?.source_type !== "consumption_summary",
      )
    ),
    searchConsumptionSummaries(params),
  ]);

  const seen = new Set<string>();
  const merged: any[] = [];
  for (const r of [...docs, ...summaries]) {
    if (seen.has(r.id)) continue;
    seen.add(r.id);
    merged.push(r);
  }
  return merged;
}
