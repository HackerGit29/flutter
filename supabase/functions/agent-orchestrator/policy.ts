import type { PolicyDecision, ResolvedAppliance } from "./types.ts";

/**
 * Résout un nom d'appareil (ex: "chauffe-eau") vers ses identifiants techniques.
 * Utilise une recherche ILIKE scope par user_id.
 * Retourne null si aucun ou plusieurs appareils correspondent.
 */
export async function resolveApplianceByName(params: {
  supabase: any;
  requesterId: string;
  applianceName: string;
}): Promise<ResolvedAppliance | null> {
  const name = params.applianceName.trim();

  const { data, error } = await params.supabase
    .from("appliances")
    .select(`
      id,
      name,
      relay_index,
      box_id,
      boxes!inner (
        id,
        user_id,
        uid_hardware
      )
    `)
    .eq("user_id", params.requesterId)
    .ilike("name", `%${name}%`)
    .limit(2);

  if (error) throw error;

  if (!data || data.length !== 1) {
    return null;
  }

  const row = data[0];

  return {
    appliance_id: row.id,
    appliance_name: row.name,
    box_id: row.box_id,
    box_uid: row.boxes.uid_hardware ?? row.box_id,
    relay_index: row.relay_index,
  };
}

/**
 * Vérifie la politique d'autorisation pour une action appareil.
 * 1. Ownership déjà vérifié par la résolution (scope user_id)
 * 2. Rate limit : max 10 commandes/minute par boîtier
 */
export async function checkDeviceActionPolicy(params: {
  supabase: any;
  requesterId: string;
  resolved: ResolvedAppliance;
  action: "on" | "off";
}): Promise<PolicyDecision> {
  const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();

  const { data: recentCommands, error } = await params.supabase
    .from("device_commands")
    .select("id")
    .eq("user_id", params.requesterId)
    .eq("box_id", params.resolved.box_id)
    .gte("created_at", oneMinuteAgo);

  if (error) throw error;

  if ((recentCommands?.length ?? 0) >= 10) {
    return {
      allowed: false,
      reason: "rate_limit_exceeded",
    };
  }

  return {
    allowed: true,
  };
}

/**
 * Appareils à risque : confirmation modale obligatoire avant allumage/extinction.
 * Hardcodé ici (pas de migration), suffit pour le scope actuel.
 */
export const CRITICAL_APPLIANCES = [
  "chauffe-eau",
  "chauffe eau",
  "climatiseur",
  "clim",
  "four",
  "cuisinière",
  "cuisiniere",
];

/**
 * Évalue la criticité métier d'un appareil à partir de son nom.
 * Retourne "high" si le nom matche un appareil critique (insensible casse/accents).
 */
export function evaluateCriticality(applianceName: string): "high" | "low" {
  const lower = applianceName.toLowerCase();
  return CRITICAL_APPLIANCES.some((c) => lower.includes(c)) ? "high" : "low";
}
