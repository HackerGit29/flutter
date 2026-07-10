import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

async function aggregateDaily() {
  const today = new Date().toISOString().slice(0, 10);
  const week = getWeekNumber(new Date());
  const month = new Date().getMonth() + 1;
  const year = new Date().getFullYear();

  const { data: readings, error } = await supabase
    .from("realtime_power")
    .select("appliance_id, user_id, power_kwh, instant_power_w");

  if (error || !readings) {
    console.error("Failed to fetch realtime_power:", error?.message);
    return { aggregated: 0, total: 0, date: today };
  }

  let aggregated = 0;

  for (const r of readings) {
    const cumulative = Number(r.power_kwh ?? 0);

    // Snapshot cumulatif du dernier jour ANTÉRIEUR (date < today) : la conso du
    // jour = cumulatif courant − dernier cumulatif connu. Filtrer sur `date <
    // today` rend la fonction idempotente et ré-exécutable plusieurs fois par
    // jour sans écraser le total du jour par un simple incrément horaire.
    const { data: prev } = await supabase
      .from("energy_data")
      .select("cumulative_kwh")
      .eq("appliance_id", r.appliance_id)
      .lt("date", today)
      .order("date", { ascending: false })
      .limit(1);

    const previousCumulative = prev?.[0]?.cumulative_kwh
      ? Number(prev[0].cumulative_kwh)
      : null;

    const delta = previousCumulative != null
      ? Math.max(0, cumulative - previousCumulative)
      : cumulative;

    const { error: upsertError } = await supabase.from("energy_data").upsert({
      appliance_id: r.appliance_id,
      user_id: r.user_id,
      date: today,
      kwh: delta,
      // total_day : colonne legacy encore lue par tips-generator/context.ts
      // (le graphe lit kwh). On garde les deux synchronisées pour que les
      // conseils voient la conso du jour.
      total_day: delta,
      cumulative_kwh: cumulative,
      week,
      month,
      year,
    }, {
      onConflict: "appliance_id, date",
    });

    if (upsertError) {
      console.error(`Upsert failed for ${r.appliance_id}:`, upsertError.message);
    } else {
      aggregated++;
    }
  }

  console.log(`Aggregated ${aggregated}/${readings.length} readings for ${today}`);
  return { aggregated, total: readings.length, date: today };
}

function getWeekNumber(date: Date): number {
  const start = new Date(date.getFullYear(), 0, 1);
  const diff = (date.getTime() - start.getTime() + (start.getTimezoneOffset() - date.getTimezoneOffset()) * 60000) / 86400000;
  return Math.ceil((diff + start.getDay() + 1) / 7);
}

// ETL realtime_power → energy_data. Servi en HTTP pour être déclenché par le
// cron pg_cron (cf. migration energy_aggregator_cron) ou manuellement via
// `supabase functions invoke energy-aggregator`.
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const result = await aggregateDaily();
    return new Response(
      JSON.stringify({ ok: true, ...result }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
