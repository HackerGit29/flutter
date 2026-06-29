import "https://deno.land/std@0.224.0/dotenv/load.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

async function aggregateDaily() {
  const today = new Date().toISOString().slice(0, 10);
  const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
  const week = getWeekNumber(new Date());
  const month = new Date().getMonth() + 1;
  const year = new Date().getFullYear();

  const { data: readings, error } = await supabase
    .from("realtime_power")
    .select("appliance_id, user_id, power_kwh, instant_power_w");

  if (error || !readings) {
    console.error("Failed to fetch realtime_power:", error?.message);
    return;
  }

  let aggregated = 0;

  for (const r of readings) {
    const cumulative = Number(r.power_kwh ?? 0);

    // Read previous day's cumulative snapshot
    const { data: prev } = await supabase
      .from("energy_data")
      .select("cumulative_kwh")
      .eq("appliance_id", r.appliance_id)
      .order("date", { ascending: false })
      .limit(1);

    const previousCumulative = prev?.[0]?.cumulative_kwh
      ? Number(prev[0].cumulative_kwh)
      : null;

    // Compute delta: today's consumption = current cumulative - last snapshot
    const delta = previousCumulative != null
      ? Math.max(0, cumulative - previousCumulative)
      : cumulative;

    const { error: upsertError } = await supabase.from("energy_data").upsert({
      appliance_id: r.appliance_id,
      user_id: r.user_id,
      date: today,
      kwh: delta,
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
}

function getWeekNumber(date: Date): number {
  const start = new Date(date.getFullYear(), 0, 1);
  const diff = (date.getTime() - start.getTime() + (start.getTimezoneOffset() - date.getTimezoneOffset()) * 60000) / 86400000;
  return Math.ceil((diff + start.getDay() + 1) / 7);
}

if (import.meta.main) {
  await aggregateDaily();
}
