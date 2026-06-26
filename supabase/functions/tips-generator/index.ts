import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildTipContext } from "./context.ts";
import { pickTip } from "./tips.ts";
import { evaluateLiveRules } from "./liveRules.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

async function generateDailyTipForUser(userId: string, today: string) {
  const ctx = await buildTipContext(supabase, userId);
  const tip = pickTip(ctx);

  const { error } = await supabase.from("daily_energy_tip").upsert({
    user_id: userId,
    date: today,
    title: tip.title,
    body: tip.body,
    icon: tip.icon,
    severity: tip.severity,
    rule_id: tip.ruleId,
    context: tip.context,
    generated_at: new Date().toISOString(),
  }, { onConflict: "user_id" });

  if (error) console.error(`[tips-generator] daily upsert ${userId}:`, error);
  else console.log(`[tips-generator] daily ${userId} rule=${tip.ruleId}`);
}

async function evaluateLiveTip(userId: string, applianceId: string) {
  const ctx = await buildTipContext(supabase, userId);
  const live = evaluateLiveRules(ctx, applianceId);
  if (!live) return null;

  const { error } = await supabase.from("energy_tips_realtime").insert({
    user_id: userId,
    title: live.title,
    body: live.body,
    icon: live.icon,
    severity: live.severity,
    source: "live_spike",
    rule_id: live.ruleId,
  });
  if (error) {
    console.error(`[tips-generator] realtime insert ${userId}:`, error);
    return null;
  }
  console.log(`[tips-generator] live push ${userId} rule=${live.ruleId}`);
  return live;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const today = new Date().toISOString().slice(0, 10);

  if (req.method === "POST" && url.pathname.endsWith("/evaluate-live")) {
    let body: { userId?: string; applianceId?: string };
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const { userId, applianceId } = body;
    if (!userId || !applianceId) {
      return new Response(
        JSON.stringify({ error: "userId, applianceId required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const tip = await evaluateLiveTip(userId, applianceId);
    return new Response(
      JSON.stringify({ ok: true, pushed: !!tip, tip }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // Mode batch (cron)
  const { data: users, error } = await supabase
    .from("subscriptions")
    .select("user_id")
    .eq("is_active", true);
  if (error) {
    return new Response(
      JSON.stringify({ ok: false, error: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  for (const row of users ?? []) {
    await generateDailyTipForUser(row.user_id, today);
  }
  return new Response(
    JSON.stringify({ ok: true, count: users?.length ?? 0, date: today }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
