import type { TipContext, TipAppliance } from "./tips.ts";

/**
 * Agrège les données DB nécessaires au moteur de règles pour un user donné.
 * Toutes les requêtes sont parallélisées.
 */
export async function buildTipContext(
  supabase: any,
  userId: string,
): Promise<TipContext> {
  const today = new Date().toISOString().slice(0, 10);
  const yesterday = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);
  const weekAgo = new Date(Date.now() - 7 * 86_400_000).toISOString().slice(0, 10);

  const [
    todayRes,
    yesterdayRes,
    weekRes,
    appliancesRes,
    realtimeRes,
    subscriptionRes,
  ] = await Promise.all([
    supabase
      .from("energy_data")
      .select("appliance_id, total_day, appliances!inner(name)")
      .eq("user_id", userId)
      .eq("date", today),
    supabase
      .from("energy_data")
      .select("total_day")
      .eq("user_id", userId)
      .eq("date", yesterday)
      .maybeSingle(),
    supabase
      .from("energy_data")
      .select("date, total_day")
      .eq("user_id", userId)
      .gte("date", weekAgo),
    supabase
      .from("appliances")
      .select("id, name, is_on")
      .eq("user_id", userId),
    supabase
      .from("realtime_power")
      .select("appliance_id, instant_power_w, appliances!inner(name)")
      .eq("user_id", userId),
    supabase
      .from("subscriptions")
      .select("type")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);

  const todayRows = todayRes.data ?? [];
  const yesterdayTotal = Number(yesterdayRes.data?.total_day ?? 0);

  const weekRows = weekRes.data ?? [];
  const weekDays = new Set<string>();
  for (const r of weekRows) weekDays.add(r.date);
  const weekAvgDailyKwh = weekDays.size > 0
    ? weekRows.reduce((acc: number, r: any) => acc + Number(r.total_day ?? 0), 0) /
      Math.max(weekDays.size, 1)
    : 0;

  const appliances = appliancesRes.data ?? [];
  const realtime = realtimeRes.data ?? [];

  // Index appliance_id → typicalWatts (moyenne 7j en W, approx kWh*1000/24)
  const typicalByAppliance = new Map<string, number>();
  for (const r of weekRows) {
    const w = (Number(r.total_day) * 1000) / 24;
    typicalByAppliance.set(
      r.appliance_id as string,
      Number(typicalByAppliance.get(r.appliance_id) ?? 0) + w,
    );
  }
  for (const [id, totalW] of typicalByAppliance) {
    typicalByAppliance.set(id, totalW / Math.max(weekDays.size, 1));
  }

  const todayTotal = todayRows.reduce(
    (acc: number, r: any) => acc + Number(r.total_day ?? 0),
    0,
  );

  // Construction topAppliances (par conso agrégée du jour)
  const topAppliances: TipAppliance[] = todayRows
    .map((r: any) => {
      const id = r.appliance_id as string;
      const kwh = Number(r.total_day ?? 0);
      const live = realtime.find((x: any) => x.appliance_id === id);
      const appliance = appliances.find((a: any) => a.id === id);
      return {
        id,
        name: r.appliances?.name ?? appliance?.name ?? "?",
        kwh,
        share: todayTotal > 0 ? kwh / todayTotal : 0,
        isOn: appliance?.is_on ?? false,
        liveWatts: live ? Number(live.instant_power_w ?? 0) : null,
        typicalWatts: typicalByAppliance.get(id) ?? null,
      };
    })
    .sort((a: TipAppliance, b: TipAppliance) => b.kwh - a.kwh);

  // inactiveAppliancesOn : is_on=true mais pas dans todayRows (kwh jour = 0)
  const inactiveAppliancesOn = appliances
    .filter((a: any) =>
      a.is_on === true && !todayRows.some((r: any) => r.appliance_id === a.id),
    )
    .map((a: any) => a.name as string);

  // peakHourKwh : pas de granularité horaire dans energy_data → on omet
  // (la règle `evening_peak` ne matchera pas tant qu'on n'a pas cette donnée).
  const peakHourKwh = undefined;

  return {
    userId,
    todayKwh: todayTotal,
    yesterdayKwh: yesterdayTotal,
    weekAvgDailyKwh,
    topAppliances,
    inactiveAppliancesOn,
    peakHourKwh,
    subscriptionType: (subscriptionRes.data?.type as "free" | "vip") ?? "free",
  };
}
