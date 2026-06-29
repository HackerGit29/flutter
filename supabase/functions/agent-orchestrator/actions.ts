import { resolveApplianceByName } from "./policy.ts";
import type { ResolvedAppliance } from "./types.ts";

/**
 * Insère une commande dans la file device_commands.
 * Le Worker MQTT la lira et publiera sur le broker.
 */
export async function enqueueDeviceCommand(params: {
  supabase: any;
  requesterId: string;
  resolved: ResolvedAppliance;
  action: "on" | "off";
  source?: string;
}) {
  const { data, error } = await params.supabase
    .from("device_commands")
    .insert({
      user_id: params.requesterId,
      box_id: params.resolved.box_id,
      box_uid: params.resolved.box_uid,
      appliance_id: params.resolved.appliance_id,
      appliance_name: params.resolved.appliance_name,
      relay_index: params.resolved.relay_index,
      action: params.action,
      status: "pending",
      requested_by: params.source ?? "ai_agent",
    })
    .select("id, status")
    .single();

  if (error) throw error;

  return data;
}

/**
 * Récupère la consommation en temps réel pour un appareil ou général.
 * Lit depuis realtime_power (valeur live cumulée).
 */
export async function getRealtimeConsumption(params: {
  supabase: any;
  requesterId: string;
  applianceId?: string;
}) {
  let query = params.supabase
    .from("realtime_power")
    .select("appliance_id, power_kwh, instant_power_w, updated_at, appliances!inner(name)")
    .eq("user_id", params.requesterId);

  if (params.applianceId) {
    query = query.eq("appliance_id", params.applianceId);
  }

  const { data, error } = await query;

  if (error) throw error;

  if (!data || data.length === 0) return null;

  return data.map((row: any) => ({
    appliance_id: row.appliance_id,
    appliance_name: row.appliances?.name ?? "",
    power_kwh: Number(row.power_kwh),
    instant_power_w: row.instant_power_w !== null ? Number(row.instant_power_w) : null,
    updated_at: row.updated_at,
  }));
}

/**
 * Récupère l'état actuel d'un appareil (relais).
 */
export async function getDeviceStatus(params: {
  supabase: any;
  requesterId: string;
  applianceName: string;
}) {
  const { data, error } = await params.supabase
    .from("appliances")
    .select(`
      name,
      is_on,
      location,
      relay_index,
      boxes!inner (uid_hardware)
    `)
    .eq("user_id", params.requesterId)
    .ilike("name", `%${params.applianceName.trim()}%`)
    .limit(1)
    .single();

  if (error) return null;

  return data;
}

/**
 * Récupère l'historique de consommation pour un appareil ou général.
 */
export async function getEnergyHistory(params: {
  supabase: any;
  requesterId: string;
  applianceId?: string;
  period: "day" | "week" | "month" | "year";
}) {
  const now = new Date();
  let startDate: Date;

  switch (params.period) {
    case "day":
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      break;
    case "week":
      const dayOfWeek = now.getDay();
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dayOfWeek);
      break;
    case "month":
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
      break;
    case "year":
      startDate = new Date(now.getFullYear(), 0, 1);
      break;
  }

  let query = params.supabase
    .from("energy_data")
    .select("kwh, cumulative_kwh, date")
    .eq("user_id", params.requesterId)
    .gte("date", startDate.toISOString().split("T")[0])
    .order("date", { ascending: true });

  if (params.applianceId) {
    query = query.eq("appliance_id", params.applianceId);
  }

  const { data, error } = await query;

  if (error) throw error;

  return data ?? [];
}

export type LivePowerRow = {
  appliance_id: string;
  appliance_name: string;
  power_kwh: number;
  instant_power_w: number | null;
  updated_at: string;
};

/**
 * Lit realtime_power pour l'utilisateur courant.
 * Si applianceName est fourni, résout puis filtre (null si ambigu).
 */
export async function getLiveConsumption(params: {
  supabase: any;
  requesterId: string;
  applianceName?: string;
}): Promise<LivePowerRow[] | null> {
  let query = params.supabase
    .from("realtime_power")
    .select("appliance_id, power_kwh, instant_power_w, updated_at, appliances!inner(name)")
    .eq("user_id", params.requesterId);

  if (params.applianceName) {
    const resolved = await resolveApplianceByName({
      supabase: params.supabase,
      requesterId: params.requesterId,
      applianceName: params.applianceName,
    });
    if (!resolved) return null;
    query = query.eq("appliance_id", resolved.appliance_id);
  }

  const { data, error } = await query;
  if (error) throw error;

  return (data ?? []).map((row: any) => ({
    appliance_id: row.appliance_id,
    appliance_name: row.appliances?.name ?? "",
    power_kwh: Number(row.power_kwh),
    instant_power_w: row.instant_power_w !== null ? Number(row.instant_power_w) : null,
    updated_at: row.updated_at,
  }));
}

/**
 * Appelle la RPC SECURITY DEFINER sum_total_consumption.
 * total + détail par appareil, scope strict par requester_id.
 */
export async function getTotalConsumption(params: {
  supabase: any;
  requesterId: string;
  period: "day" | "week" | "month" | "year";
}) {
  const { data, error } = await params.supabase.rpc("sum_total_consumption", {
    requester_id: params.requesterId,
    period: params.period,
  });
  if (error) throw error;
  return data;
}
