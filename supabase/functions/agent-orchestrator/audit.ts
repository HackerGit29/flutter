/**
 * Journalise une action de l'agent dans agent_audit_logs.
 * Toutes les décisions (autorisées, bloquées, échouées) sont tracées.
 */
export async function audit(params: {
  supabase: any;
  requesterId: string;
  action: string;
  targetType?: string;
  targetId?: string;
  status: "allowed" | "blocked" | "failed" | "success" | "pending";
  details?: Record<string, unknown>;
}) {
  try {
    await params.supabase.from("agent_audit_logs").insert({
      user_id: params.requesterId,
      action: params.action,
      target_type: params.targetType ?? null,
      target_id: params.targetId ?? null,
      status: params.status,
      details: params.details ?? {},
    });
  } catch (error) {
    console.error("Audit log error:", error);
    // Ne pas bloquer le flux principal si l'audit échoue
  }
}
