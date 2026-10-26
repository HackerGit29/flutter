// Edge Function admin-api — routes Users
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.7
//
// GET   /v1/users              → liste paginée (viewer+)
// GET   /v1/users/:id          → fiche 360° (viewer+)
// GET   /v1/users/:id/timeline → timeline fusionnée (viewer+)
// PATCH /v1/users/:id/status   → suspendre/activer (operator+)
// PATCH /v1/users/:id/role     → rôle + admin_level (super_admin)
//
// Toutes les écritures passent par auditAdminAction (§7).

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  HttpError,
  isUuid,
  jsonError,
  jsonResponse,
  paginated,
  parsePagination,
} from "./http.ts";
import { createAdminClient, type AdminContext } from "./auth.ts";
import { auditAdminAction } from "./audit.ts";

const USER_LIST_COLUMNS =
  "id, email, role, admin_level, status, created_at";

type UserRow = {
  id: string;
  email: string;
  role: string;
  admin_level: string | null;
  status: string;
  created_at: string;
};

/** GET /v1/users?status=&role=&sub=&q=&sort=&page=&page_size= */
export async function handleListUsers(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();

  // Typage `any` assumé : l'inférence postgrest-js sur les embeddings
  // (!inner, count) explose la profondeur de type — les entrées sont
  // validées manuellement ci-dessous.
  let query: any = admin
    .from("users")
    .select(`${USER_LIST_COLUMNS}, subscription:subscriptions(type, is_active, end_date), boxes(count)`, {
      count: "exact",
    });

  const status = url.searchParams.get("status");
  if (status) {
    if (!["active", "suspended"].includes(status)) {
      throw new HttpError("validation_error", `status invalide: ${status}`);
    }
    query = query.eq("status", status);
  }

  const role = url.searchParams.get("role");
  if (role) {
    if (!["admin", "user", "vip"].includes(role)) {
      throw new HttpError("validation_error", `role invalide: ${role}`);
    }
    query = query.eq("role", role);
  }

  // Filtrage par type d'abonnement : embedding + filter via inner join
  const sub = url.searchParams.get("sub");
  if (sub) {
    if (!["free", "vip"].includes(sub)) {
      throw new HttpError("validation_error", `sub invalide: ${sub}`);
    }
    query = query
      .select(`${USER_LIST_COLUMNS}, subscription:subscriptions(type, is_active, end_date)!inner`, {
        count: "exact",
      })
      .eq("subscription.type", sub);
  }

  const q = url.searchParams.get("q");
  if (q && q.trim().length >= 2) {
    query = query.ilike("email", `%${q.trim()}%`);
  }

  const sort = url.searchParams.get("sort") ?? "created_at_desc";
  const sortMap: Record<string, { column: string; ascending: boolean }> = {
    created_at_desc: { column: "created_at", ascending: false },
    created_at_asc: { column: "created_at", ascending: true },
    email_asc: { column: "email", ascending: true },
    email_desc: { column: "email", ascending: false },
  };
  const sortSpec = sortMap[sort];
  if (!sortSpec) {
    throw new HttpError(
      "validation_error",
      `sort invalide: ${sort} (${Object.keys(sortMap).join("|")})`,
    );
  }

  const { data, error, count } = await query
    .order(sortSpec.column, { ascending: sortSpec.ascending })
    .range(p.from, p.to);

  if (error) {
    console.error("list users error:", error);
    throw new HttpError("internal_error", "Lecture des utilisateurs impossible", 500);
  }

  const users = ((data ?? []) as any[]).map((u) => ({
    id: u.id,
    email: u.email,
    role: u.role,
    admin_level: u.admin_level,
    status: u.status,
    created_at: u.created_at,
    subscription: Array.isArray(u.subscription) ? u.subscription[0] ?? null : u.subscription ?? null,
    box_count: u.boxes?.[0]?.count ?? 0,
  }));

  return jsonResponse(paginated(users, count ?? users.length, p));
}

/** GET /v1/users/:id — fiche 360° */
export async function handleGetUser(
  userId: string,
  _ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(userId)) {
    throw new HttpError("validation_error", "userId invalide (UUID attendu)");
  }
  const admin = createAdminClient();

  const { data: user, error } = await admin
    .from("users")
    .select(`${USER_LIST_COLUMNS}, updated_at`)
    .eq("id", userId)
    .single();

  if (error || !user) {
    throw new HttpError("not_found", "Utilisateur introuvable", 404);
  }

  const u = user as UserRow & { updated_at: string | null };

  // Agrégats de la fiche — requêtes parallèles, chacune tolérante à l'erreur
  const thirtyDaysAgo = new Date(Date.now() - 30 * 86400_000).toISOString();
  const [subRes, boxesRes, kwh30Res, kwhYearRes, cmdRes, lastSyncRes] =
    await Promise.all([
      admin.from("subscriptions").select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(1),
      admin.from("boxes")
        .select("id, uid_hardware, name, location, status, firmware_version, last_sync, latitude, longitude, created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false }),
      admin.from("energy_data").select("kwh")
        .eq("user_id", userId)
        .gte("date", thirtyDaysAgo.slice(0, 10)),
      admin.rpc("sum_total_consumption", {
        requester_id: userId,
        period: "year",
      }),
      admin.from("device_commands").select("status", { count: "exact", head: true })
        .eq("user_id", userId)
        .gte("created_at", thirtyDaysAgo),
      admin.from("sync_logs").select("timestamp, status")
        .eq("user_id", userId)
        .order("timestamp", { ascending: false })
        .limit(1),
    ]);

  const kwh30 = (kwh30Res.data ?? []).reduce(
    (sum: number, r: any) => sum + (r.kwh ?? 0),
    0,
  );
  const totalYear = (kwhYearRes.data as any)?.total_kwh ?? 0;

  return jsonResponse({
    id: u.id,
    email: u.email,
    role: u.role,
    admin_level: u.admin_level,
    status: u.status,
    created_at: u.created_at,
    subscription: subRes.data?.[0] ?? null,
    boxes: boxesRes.data ?? [],
    totals: {
      kwh_30d: Math.round(kwh30 * 1000) / 1000,
      kwh_year: totalYear,
      box_count: (boxesRes.data ?? []).length,
      commands_30d: cmdRes.count ?? 0,
    },
    last_sync: lastSyncRes.data?.[0]?.timestamp ?? null,
  });
}

/** GET /v1/users/:id/timeline — fusion sync_logs + device_commands + agent_audit_logs + admin_actions */
export async function handleUserTimeline(
  userId: string,
  _ctx: AdminContext,
  limitParam: string | null,
): Promise<Response> {
  if (!isUuid(userId)) {
    throw new HttpError("validation_error", "userId invalide (UUID attendu)");
  }
  const limit = Math.min(500, Math.max(1, parseInt(limitParam ?? "200", 10) || 200));
  const admin = createAdminClient();

  const [syncRes, cmdRes, agentRes, actionsRes] = await Promise.all([
    admin.from("sync_logs")
      .select("timestamp, status, box_id, error_message")
      .eq("user_id", userId)
      .order("timestamp", { ascending: false })
      .limit(limit),
    admin.from("device_commands")
      .select("created_at, action, appliance_name, status, requested_by")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(limit),
    admin.from("agent_audit_logs")
      .select("created_at, action, status, target_type, target_id")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(limit),
    admin.from("admin_actions")
      .select("timestamp, action, target_type, target_id, admin_id")
      .eq("target_id", userId)
      .order("timestamp", { ascending: false })
      .limit(limit),
  ]);

  const items = [
    ...(syncRes.data ?? []).map((r: any) => ({
      at: r.timestamp,
      kind: "sync",
      label: `Sync boîtier (${r.status})`,
      details: { box_id: r.box_id, error: r.error_message },
    })),
    ...(cmdRes.data ?? []).map((r: any) => ({
      at: r.created_at,
      kind: "device_command",
      label: `${r.action} — ${r.appliance_name ?? "?"} (${r.status})`,
      details: { requested_by: r.requested_by },
    })),
    ...(agentRes.data ?? []).map((r: any) => ({
      at: r.created_at,
      kind: "agent_audit",
      label: `${r.action} (${r.status})`,
      details: { target_type: r.target_type, target_id: r.target_id },
    })),
    ...(actionsRes.data ?? []).map((r: any) => ({
      at: r.timestamp,
      kind: "admin_action",
      label: `${r.action} (${r.target_type})`,
      details: { admin_id: r.admin_id },
    })),
  ]
    .sort((a, b) => (a.at < b.at ? 1 : -1))
    .slice(0, limit);

  return jsonResponse({ user_id: userId, items });
}

/** PATCH /v1/users/:id/status — { status: 'active' | 'suspended' } (operator+) */
export async function handleUpdateUserStatus(
  userId: string,
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(userId)) {
    throw new HttpError("validation_error", "userId invalide (UUID attendu)");
  }
  const status = (body as any)?.status;
  if (!["active", "suspended"].includes(status)) {
    return jsonError(
      "validation_error",
      "status invalide (active|suspended)",
      400,
    );
  }

  const admin = createAdminClient();
  const { data: updated, error } = await admin
    .from("users")
    .update({ status })
    .eq("id", userId)
    .select("id, email, status")
    .single();

  if (error || !updated) {
    console.error("update user status error:", error);
    throw new HttpError("internal_error", "Mise à jour impossible", 500);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: status === "suspended" ? "suspend_user" : "activate_user",
    targetType: "user",
    targetId: userId,
    details: { email: updated.email, new_status: status },
  });

  return jsonResponse(updated);
}

/** PATCH /v1/users/:id/role — { role, admin_level } (super_admin) */
export async function handleUpdateUserRole(
  userId: string,
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(userId)) {
    throw new HttpError("validation_error", "userId invalide (UUID attendu)");
  }
  const { role, admin_level } = (body as any) ?? {};

  const patch: Record<string, unknown> = {};
  if (role !== undefined) {
    if (!["admin", "user", "vip"].includes(role)) {
      return jsonError("validation_error", "role invalide (admin|user|vip)", 400);
    }
    patch.role = role;
  }
  if (admin_level !== undefined) {
    if (admin_level !== null && !["viewer", "operator", "super_admin"].includes(admin_level)) {
      return jsonError(
        "validation_error",
        "admin_level invalide (viewer|operator|super_admin|null)",
        400,
      );
    }
    patch.admin_level = admin_level;
  }
  if (Object.keys(patch).length === 0) {
    return jsonError("validation_error", "role ou admin_level requis", 400);
  }

  // Garde-fou : ne pas rétrograder son propre compte
  if (userId === ctx.adminId && (patch.role !== undefined && patch.role !== "admin")) {
    return jsonError("validation_error", "Impossible de rétrograder son propre compte", 400);
  }

  const admin = createAdminClient();
  const { data: updated, error } = await admin
    .from("users")
    .update(patch)
    .eq("id", userId)
    .select("id, email, role, admin_level")
    .single();

  if (error || !updated) {
    console.error("update user role error:", error);
    throw new HttpError("internal_error", "Mise à jour impossible", 500);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "assign_role",
    targetType: "user",
    targetId: userId,
    details: { email: updated.email, ...patch },
  });

  return jsonResponse(updated);
}
