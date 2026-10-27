// Edge Function admin-api — routes Admin & audit
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.13 / §7
//
// GET  /v1/admin/actions     → journal admin_actions filtré (viewer+)
// GET  /v1/admin/audit-logs  → fusion admin_actions + agent_audit_logs (super_admin)
// GET  /v1/admin/notes       → notes internes support, filtrées (operator+)
// POST /v1/admin/notes       → création d'une note interne (operator+)
//
// Les notes sont strictement internes (jamais exposées à l'app client, §4.1).
// Contrairement aux autres écritures, une note n'est pas tracée dans
// admin_actions : la note porte déjà son auteur (admin_id) et son horodatage,
// elle EST son propre journal.

import {
  HttpError,
  isUuid,
  jsonResponse,
  paginated,
  parsePagination,
} from "./http.ts";
import { createAdminClient, type AdminContext } from "./auth.ts";

const ADMIN_ACTION_COLUMNS =
  "id, admin_id, action, target_type, target_id, details, timestamp";

const VALID_NOTE_TARGET = ["user", "box", "subscription"];

/* ------------------------------------------------------------------ */
/* GET /v1/admin/actions                                               */
/* ------------------------------------------------------------------ */

/** GET /v1/admin/actions?admin_id=&action=&target_type=&target_id=&from=&to=&page= */
export async function handleListAdminActions(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();

  let query = admin
    .from("admin_actions")
    .select(`${ADMIN_ACTION_COLUMNS}, admin:users(email)`, { count: "exact" });

  const adminId = url.searchParams.get("admin_id");
  if (adminId) {
    if (!isUuid(adminId)) {
      throw new HttpError("validation_error", "admin_id invalide (UUID attendu)");
    }
    query = query.eq("admin_id", adminId);
  }

  const action = url.searchParams.get("action");
  if (action) {
    query = query.eq("action", action);
  }

  const targetType = url.searchParams.get("target_type");
  if (targetType) {
    query = query.eq("target_type", targetType);
  }

  const targetId = url.searchParams.get("target_id");
  if (targetId) {
    query = query.eq("target_id", targetId);
  }

  applyTimeRange(query, "timestamp", url);

  const { data, error, count } = await query
    .order("timestamp", { ascending: false })
    .range(p.from, p.to);

  if (error) {
    console.error("list admin_actions error:", error);
    throw new HttpError("internal_error", "Journal d'audit impossible", 500);
  }

  const actions = ((data ?? []) as any[]).map((r) => ({
    id: r.id,
    admin_id: r.admin_id,
    admin_email: r.admin?.email ?? null,
    action: r.action,
    target_type: r.target_type,
    target_id: r.target_id,
    details: r.details ?? {},
    created_at: r.timestamp,
  }));

  return jsonResponse(paginated(actions, count ?? actions.length, p));
}

/* ------------------------------------------------------------------ */
/* GET /v1/admin/audit-logs (fusion)                                   */
/* ------------------------------------------------------------------ */

/**
 * GET /v1/admin/audit-logs?source=&action=&status=&user_id=&admin_id=&from=&to=&page=&page_size=
 *
 * Fusion des deux journaux (admin_actions + agent_audit_logs) triée par date
 * décroissante. Chaque entrée porte un `source` pour discriminer l'origine.
 *
 * Trade-off assumé (même motif que handleUserTimeline) : la fusion de deux
 * tables hétérogènes ne se pagine pas en SQL sans vue dédiée. On borna la
 * fenêtre à `window` entrées par source (défaut 250, max 500) puis on pagine
 * en mémoire sur l'union triée — suffisant pour une vue « audit récent ».
 */
export async function handleFusedAuditLogs(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();

  const window = Math.min(
    500,
    Math.max(1, parseInt(url.searchParams.get("window") ?? "250", 10) || 250),
  );

  const source = url.searchParams.get("source") ?? "all";
  if (!["all", "admin", "agent"].includes(source)) {
    throw new HttpError(
      "validation_error",
      `source invalide: ${source} (all|admin|agent)`,
    );
  }

  const wantAdmin = source === "all" || source === "admin";
  const wantAgent = source === "all" || source === "agent";

  const adminRes = wantAdmin
    ? await fetchAdminActionsForFusion(url, admin, window)
    : [];
  const agentRes = wantAgent
    ? await fetchAgentLogsForFusion(url, admin, window)
    : [];

  const fused = [...adminRes, ...agentRes]
    .sort((a, b) => (a.at < b.at ? 1 : -1))
    .slice(p.from, p.to + 1);

  return jsonResponse({
    data: fused,
    page: p.page,
    page_size: p.pageSize,
    // Total borné à la fenêtre fusionnée (vue « audit récent »).
    total: adminRes.length + agentRes.length,
  });
}

async function fetchAdminActionsForFusion(
  url: URL,
  admin: any,
  window: number,
): Promise<any[]> {
  let query = admin
    .from("admin_actions")
    .select(`${ADMIN_ACTION_COLUMNS}, admin:users(email)`);

  const adminId = url.searchParams.get("admin_id");
  if (adminId && isUuid(adminId)) query = query.eq("admin_id", adminId);

  const action = url.searchParams.get("action");
  if (action) query = query.eq("action", action);

  const targetType = url.searchParams.get("target_type");
  if (targetType) query = query.eq("target_type", targetType);

  applyTimeRange(query, "timestamp", url);

  const { data, error } = await query
    .order("timestamp", { ascending: false })
    .limit(window);
  if (error) {
    console.error("fusion admin_actions error:", error);
    return [];
  }

  return ((data ?? []) as any[]).map((r) => ({
    id: r.id,
    source: "admin",
    at: r.timestamp,
    action: r.action,
    target_type: r.target_type,
    target_id: r.target_id,
    actor_id: r.admin_id,
    actor_email: r.admin?.email ?? null,
    status: null,
    details: r.details ?? {},
  }));
}

async function fetchAgentLogsForFusion(
  url: URL,
  admin: any,
  window: number,
): Promise<any[]> {
  let query = admin.from("agent_audit_logs").select("*");

  const userId = url.searchParams.get("user_id");
  if (userId && isUuid(userId)) query = query.eq("user_id", userId);

  const action = url.searchParams.get("action");
  if (action) query = query.eq("action", action);

  const status = url.searchParams.get("status");
  if (status) query = query.eq("status", status);

  applyTimeRange(query, "created_at", url);

  const { data, error } = await query
    .order("created_at", { ascending: false })
    .limit(window);
  if (error) {
    console.error("fusion agent_audit_logs error:", error);
    return [];
  }

  return ((data ?? []) as any[]).map((r) => ({
    id: r.id,
    source: "agent",
    at: r.created_at,
    action: r.action,
    target_type: r.target_type,
    target_id: r.target_id,
    actor_id: r.user_id,
    actor_email: null,
    status: r.status,
    details: r.details ?? {},
  }));
}

/* ------------------------------------------------------------------ */
/* Notes internes support                                              */
/* ------------------------------------------------------------------ */

const NOTE_COLUMNS =
  "id, admin_id, target_type, target_id, body, created_at";

/** GET /v1/admin/notes?target_type=&target_id=&page=&page_size= */
export async function handleListNotes(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();

  let query = admin
    .from("admin_notes")
    .select(`${NOTE_COLUMNS}, admin:users(email)`, { count: "exact" });

  const targetType = url.searchParams.get("target_type");
  if (targetType) {
    if (!VALID_NOTE_TARGET.includes(targetType)) {
      throw new HttpError(
        "validation_error",
        `target_type invalide: ${targetType} (${VALID_NOTE_TARGET.join("|")})`,
      );
    }
    query = query.eq("target_type", targetType);
  }

  const targetId = url.searchParams.get("target_id");
  if (targetId) {
    if (!isUuid(targetId)) {
      throw new HttpError("validation_error", "target_id invalide (UUID attendu)");
    }
    query = query.eq("target_id", targetId);
  }

  const { data, error, count } = await query
    .order("created_at", { ascending: false })
    .range(p.from, p.to);

  if (error) {
    console.error("list notes error:", error);
    throw new HttpError("internal_error", "Lecture des notes impossible", 500);
  }

  const notes = ((data ?? []) as any[]).map((r) => ({
    id: r.id,
    admin_id: r.admin_id,
    admin_email: r.admin?.email ?? null,
    target_type: r.target_type,
    target_id: r.target_id,
    body: r.body,
    created_at: r.created_at,
    // Pas de colonne updated_at en BDD et pas de route PATCH : toujours null.
    updated_at: null,
  }));

  return jsonResponse(paginated(notes, count ?? notes.length, p));
}

/** POST /v1/admin/notes — { target_type, target_id, body } (operator+) */
export async function handleCreateNote(
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  const b = (body as any) ?? {};
  const { target_type, target_id, body: noteBody } = b;

  if (!target_type || !VALID_NOTE_TARGET.includes(target_type)) {
    throw new HttpError(
      "validation_error",
      `target_type requis (${VALID_NOTE_TARGET.join("|")})`,
    );
  }
  if (!target_id || !isUuid(target_id)) {
    throw new HttpError("validation_error", "target_id requis (UUID attendu)");
  }
  if (!noteBody || typeof noteBody !== "string" || !noteBody.trim()) {
    throw new HttpError("validation_error", "body requis (note non vide)");
  }

  const admin = createAdminClient();
  const { data: created, error } = await admin
    .from("admin_notes")
    .insert({
      admin_id: ctx.adminId,
      target_type,
      target_id,
      body: noteBody.trim(),
    })
    .select(NOTE_COLUMNS)
    .single();

  if (error || !created) {
    console.error("create note error:", error);
    throw new HttpError("internal_error", "Création de la note impossible", 500);
  }

  const row = created as any;
  return jsonResponse(
    {
      id: row.id,
      admin_id: row.admin_id,
      admin_email: ctx.email || null,
      target_type: row.target_type,
      target_id: row.target_id,
      body: row.body,
      created_at: row.created_at,
      updated_at: null,
    },
    201,
  );
}

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

/** Applique un filtre de plage temporelle ?from=&to= (ISO-8601) sur une colonne. */
function applyTimeRange(query: any, column: string, url: URL): void {
  const from = url.searchParams.get("from");
  const to = url.searchParams.get("to");
  if (from) {
    if (Number.isNaN(new Date(from).getTime())) {
      throw new HttpError("validation_error", "from invalide (ISO-8601 attendu)");
    }
    query = query.gte(column, from);
  }
  if (to) {
    if (Number.isNaN(new Date(to).getTime())) {
      throw new HttpError("validation_error", "to invalide (ISO-8601 attendu)");
    }
    query = query.lte(column, to);
  }
}
