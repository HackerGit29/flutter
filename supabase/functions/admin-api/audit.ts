// Edge Function admin-api — journal d'audit des actions admin
// Toute écriture du backoffice est tracée dans admin_actions (§7 du CDC).
// L'audit ne doit jamais faire échouer l'action principale.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type AdminActionName =
  | "suspend_user"
  | "activate_user"
  | "assign_role"
  | "create_box"
  | "update_box"
  | "reset_box"
  | "force_sync"
  | "override_ownership";

export type AdminTargetType =
  | "user"
  | "device"
  | "license"
  | "subscription"
  | "box"
  | "appliance";

export async function auditAdminAction(params: {
  supabase: SupabaseClient;
  adminId: string;
  action: AdminActionName;
  targetType: AdminTargetType;
  targetId: string;
  details?: Record<string, unknown>;
}): Promise<void> {
  try {
    const { error } = await params.supabase.from("admin_actions").insert({
      admin_id: params.adminId,
      action: params.action,
      target_type: params.targetType,
      target_id: params.targetId,
      details: params.details ?? {},
    });
    if (error) console.error("Audit admin error:", error);
  } catch (error) {
    console.error("Audit admin error:", error);
  }
}
