// Edge Function admin-api — routes Boxes
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.8
//
// GET    /v1/boxes                → liste paginée + filtres (viewer+)
// GET    /v1/boxes/:id            → détail (appliances, commandes, syncs) (viewer+)
// POST   /v1/boxes                → création (+ appliances optionnelles) (operator+)
// PATCH  /v1/boxes/:id            → maj champs (operator+)
// POST   /v1/boxes/:id/assign     → transfert boîtier + appliances (operator+)
// POST   /v1/boxes/:id/reset      → remise à zéro (super_admin)
// POST   /v1/boxes/:id/force-sync → force last_sync + log (operator+)
//
// Toutes les écritures passent par auditAdminAction (§7).

import {
  HttpError,
  isUuid,
  jsonResponse,
  paginated,
  parsePagination,
} from "./http.ts";
import { createAdminClient, type AdminContext } from "./auth.ts";
import { auditAdminAction } from "./audit.ts";

const BOX_COLUMNS =
  "id, uid_hardware, name, location, user_id, status, firmware_version, " +
  "last_sync, latitude, longitude, geo_precision, installed_at, created_at";

const VALID_BOX_STATUS = ["active", "inactive", "blocked"];
const VALID_GEO_PRECISION = ["exact", "approx", "city", "manual"];

type BoxRow = {
  id: string;
  uid_hardware: string | null;
  name: string;
  location: string | null;
  user_id: string | null;
  status: string;
  firmware_version: string | null;
  last_sync: string | null;
  latitude: number | null;
  longitude: number | null;
  geo_precision: string | null;
  installed_at: string | null;
  created_at: string;
};

/** GET /v1/boxes?status=&user_id=&q=&firmware=&page=&page_size= */
export async function handleListBoxes(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();

  let query = admin
    .from("boxes")
    .select(`${BOX_COLUMNS}, user:users(email, status), appliances(count)`, {
      count: "exact",
    });

  const status = url.searchParams.get("status");
  if (status) {
    if (!VALID_BOX_STATUS.includes(status)) {
      throw new HttpError("validation_error", `status invalide: ${status}`);
    }
    query = query.eq("status", status);
  }

  const userId = url.searchParams.get("user_id");
  if (userId) {
    if (!isUuid(userId)) {
      throw new HttpError("validation_error", "user_id invalide (UUID attendu)");
    }
    query = query.eq("user_id", userId);
  }

  const firmware = url.searchParams.get("firmware");
  if (firmware) {
    query = query.eq("firmware_version", firmware);
  }

  const q = url.searchParams.get("q");
  if (q && q.trim().length >= 2) {
    const term = q.trim().replace(/[%_,()]/g, " ");
    query = query.or(`name.ilike.%${term}%,uid_hardware.ilike.%${term}%`);
  }

  const { data, error, count } = await query
    .order("created_at", { ascending: false })
    .range(p.from, p.to);

  if (error) {
    console.error("list boxes error:", error);
    throw new HttpError("internal_error", "Lecture des boîtiers impossible", 500);
  }

  const now = Date.now();
  const boxes = ((data ?? []) as any[]).map((b) => ({
    ...Object.fromEntries(
      Object.entries(b).filter(([k]) => k !== "user" && k !== "appliances"),
    ),
    user_email: b.user?.email ?? null,
    user_status: b.user?.status ?? null,
    appliance_count: b.appliances?.[0]?.count ?? 0,
    online: b.status === "active" &&
      b.last_sync != null &&
      now - new Date(b.last_sync).getTime() < 5 * 60_000,
  }));

  return jsonResponse(paginated(boxes, count ?? boxes.length, p));
}

/** GET /v1/boxes/:id — détail complet */
export async function handleGetBox(
  boxId: string,
  _ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(boxId)) {
    throw new HttpError("validation_error", "boxId invalide (UUID attendu)");
  }
  const admin = createAdminClient();

  const { data: box, error } = await admin
    .from("boxes")
    .select(`${BOX_COLUMNS}, user:users(email, status)`)
    .eq("id", boxId)
    .single();

  if (error || !box) {
    throw new HttpError("not_found", "Boîtier introuvable", 404);
  }
  const b = box as unknown as BoxRow & {
    user: { email: string; status: string } | null;
  };

  const [appliancesRes, commandsRes, syncsRes] = await Promise.all([
    admin.from("appliances")
      .select("id, relay_index, name, location, is_on, created_at")
      .eq("box_id", boxId)
      .order("relay_index"),
    admin.from("device_commands")
      .select("id, action, appliance_name, status, requested_by, created_at, acknowledged_at, error_message")
      .eq("box_id", boxId)
      .order("created_at", { ascending: false })
      .limit(20),
    admin.from("sync_logs")
      .select("id, status, error_message, timestamp")
      .eq("box_id", boxId)
      .order("timestamp", { ascending: false })
      .limit(20),
  ]);

  return jsonResponse({
    ...b,
    user_email: b.user?.email ?? null,
    appliances: appliancesRes.data ?? [],
    recent_commands: commandsRes.data ?? [],
    recent_syncs: syncsRes.data ?? [],
  });
}

/** POST /v1/boxes — création (operator+) */
export async function handleCreateBox(
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  const b = (body as any) ?? {};
  const { uid_hardware, name, location, user_id, latitude, longitude, geo_precision } = b;

  if (!uid_hardware || typeof uid_hardware !== "string" || uid_hardware.length <= 8) {
    throw new HttpError(
      "validation_error",
      "uid_hardware requis (plus de 8 caractères, cf. contrainte BDD)",
    );
  }
  if (!name || typeof name !== "string" || !name.trim()) {
    throw new HttpError("validation_error", "name requis");
  }
  if (geo_precision !== undefined && geo_precision !== null &&
    !VALID_GEO_PRECISION.includes(geo_precision)) {
    throw new HttpError("validation_error", `geo_precision invalide: ${geo_precision}`);
  }

  const admin = createAdminClient();

  // Vérifie que le propriétaire existe si fourni
  if (user_id) {
    if (!isUuid(user_id)) {
      throw new HttpError("validation_error", "user_id invalide (UUID attendu)");
    }
    const { data: owner } = await admin
      .from("users").select("id").eq("id", user_id).single();
    if (!owner) {
      throw new HttpError("not_found", "Utilisateur propriétaire introuvable", 404);
    }
  }

  const insertResult = await admin
    .from("boxes")
    .insert({
      uid_hardware,
      name: name.trim(),
      location: location ?? null,
      user_id: user_id ?? null,
      status: "active",
      latitude: latitude ?? null,
      longitude: longitude ?? null,
      geo_precision: geo_precision ?? null,
      installed_at: latitude != null ? new Date().toISOString() : null,
    })
    .select(BOX_COLUMNS)
    .single();
  const created = insertResult.data as BoxRow | null;
  const error = insertResult.error;

  if (error || !created) {
    if (error?.code === "23505") {
      throw new HttpError("conflict", "Un boîtier avec cet UID existe déjà", 409);
    }
    console.error("create box error:", error);
    throw new HttpError("internal_error", "Création du boîtier impossible", 500);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "create_box",
    targetType: "box",
    targetId: created.id,
    details: { uid_hardware, name, user_id: user_id ?? null },
  });

  return jsonResponse(created, 201);
}

/** PATCH /v1/boxes/:id — mise à jour partielle (operator+) */
export async function handleUpdateBox(
  boxId: string,
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(boxId)) {
    throw new HttpError("validation_error", "boxId invalide (UUID attendu)");
  }
  const b = (body as any) ?? {};

  const patch: Record<string, unknown> = {};
  for (const field of ["name", "location", "firmware_version", "latitude", "longitude"]) {
    if (b[field] !== undefined) patch[field] = b[field];
  }
  if (b.status !== undefined) {
    if (!VALID_BOX_STATUS.includes(b.status)) {
      throw new HttpError("validation_error", `status invalide: ${b.status}`);
    }
    patch.status = b.status;
  }
  if (b.geo_precision !== undefined) {
    if (b.geo_precision !== null && !VALID_GEO_PRECISION.includes(b.geo_precision)) {
      throw new HttpError("validation_error", `geo_precision invalide: ${b.geo_precision}`);
    }
    patch.geo_precision = b.geo_precision;
  }
  if (b.installed_at !== undefined) patch.installed_at = b.installed_at;

  if (Object.keys(patch).length === 0) {
    throw new HttpError("validation_error", "Aucun champ à mettre à jour");
  }

  const admin = createAdminClient();
  const { data: updated, error } = await admin
    .from("boxes")
    .update(patch)
    .eq("id", boxId)
    .select(BOX_COLUMNS)
    .single();

  if (error || !updated) {
    console.error("update box error:", error);
    throw new HttpError("internal_error", "Mise à jour impossible", 500);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "update_box",
    targetType: "box",
    targetId: boxId,
    details: { fields: Object.keys(patch) },
  });

  return jsonResponse(updated);
}

/** POST /v1/boxes/:id/assign — transfert boîtier + appliances (operator+) */
export async function handleAssignBox(
  boxId: string,
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(boxId)) {
    throw new HttpError("validation_error", "boxId invalide (UUID attendu)");
  }
  const { user_id } = (body as any) ?? {};
  if (!user_id || !isUuid(user_id)) {
    throw new HttpError("validation_error", "user_id requis (UUID attendu)");
  }

  const admin = createAdminClient();

  const { data: box } = await admin
    .from("boxes").select("id, user_id").eq("id", boxId).single();
  if (!box) {
    throw new HttpError("not_found", "Boîtier introuvable", 404);
  }

  const { data: owner } = await admin
    .from("users").select("id, email").eq("id", user_id).single();
  if (!owner) {
    throw new HttpError("not_found", "Nouvel utilisateur introuvable", 404);
  }

  // Transfert atomique boîtier + appliances (pattern overrideBoxOwnership)
  const [boxUpdate, appliancesUpdate] = await Promise.all([
    admin.from("boxes").update({ user_id }).eq("id", boxId).select("id").single(),
    admin.from("appliances").update({ user_id }).eq("box_id", boxId),
  ]);

  if (boxUpdate.error || !boxUpdate.data) {
    console.error("assign box error:", boxUpdate.error);
    throw new HttpError("internal_error", "Transfert impossible", 500);
  }
  if (appliancesUpdate.error) {
    console.error("assign appliances error:", appliancesUpdate.error);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "override_ownership",
    targetType: "box",
    targetId: boxId,
    details: { from_user_id: box.user_id, to_user_id: user_id, to_email: owner.email },
  });

  return jsonResponse({ id: boxId, user_id });
}

/** POST /v1/boxes/:id/reset — uid vidé, statut inactif, clé publique effacée (super_admin) */
export async function handleResetBox(
  boxId: string,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(boxId)) {
    throw new HttpError("validation_error", "boxId invalide (UUID attendu)");
  }
  const admin = createAdminClient();

  const { data: reset, error } = await admin
    .from("boxes")
    .update({
      uid_hardware: null,
      status: "inactive",
      public_key: null,
      latitude: null,
      longitude: null,
      geo_precision: null,
    })
    .eq("id", boxId)
    .select("id, uid_hardware, status")
    .single();

  if (error || !reset) {
    console.error("reset box error:", error);
    throw new HttpError("internal_error", "Reset impossible", 500);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "reset_box",
    targetType: "box",
    targetId: boxId,
  });

  return jsonResponse(reset);
}

/** POST /v1/boxes/:id/force-sync — (operator+) */
export async function handleForceSync(
  boxId: string,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(boxId)) {
    throw new HttpError("validation_error", "boxId invalide (UUID attendu)");
  }
  const admin = createAdminClient();

  const { data: box } = await admin
    .from("boxes").select("id, user_id").eq("id", boxId).single();
  if (!box) {
    throw new HttpError("not_found", "Boîtier introuvable", 404);
  }

  const now = new Date().toISOString();
  const [boxUpdate, logInsert] = await Promise.all([
    admin.from("boxes").update({ last_sync: now }).eq("id", boxId).select("id, last_sync").single(),
    admin.from("sync_logs").insert({
      box_id: boxId,
      user_id: box.user_id,
      status: "success",
      data: { forced_by_admin: true, admin_id: ctx.adminId },
      timestamp: now,
    }),
  ]);

  if (boxUpdate.error || !boxUpdate.data) {
    console.error("force sync error:", boxUpdate.error);
    throw new HttpError("internal_error", "Force-sync impossible", 500);
  }
  if (logInsert.error) {
    console.error("force sync log error:", logInsert.error);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "force_sync",
    targetType: "box",
    targetId: boxId,
  });

  return jsonResponse({ id: boxId, last_sync: now });
}
