import { HttpError, isUuid, jsonResponse } from "./http.ts";
import { type AdminContext, createAdminClient } from "./auth.ts";
import { auditAdminAction } from "./audit.ts";
import { normalizeZoneInput } from "./zone_validation.ts";

const COLUMNS =
  "id, name, center_lat, center_lng, radius_km, target_clients, is_active, created_at";

export async function handleListZones(
  _url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const admin = createAdminClient();
  const { data, error } = await admin.from("coverage_zones").select(COLUMNS)
    .order("created_at", { ascending: false });
  if (error) {
    console.error("list coverage zones error:", error);
    throw new HttpError("internal_error", "Lecture des zones impossible", 500);
  }
  return jsonResponse(data ?? []);
}

export async function handleCreateZone(
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  const values = normalizeZoneInput(body);
  const admin = createAdminClient();
  const { data, error } = await admin.from("coverage_zones").insert(values)
    .select(COLUMNS).single();
  if (error || !data) {
    console.error("create coverage zone error:", error);
    throw new HttpError(
      "internal_error",
      "Création de la zone impossible",
      500,
    );
  }
  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "create_zone",
    targetType: "coverage_zone",
    targetId: data.id,
    details: values,
  });
  return jsonResponse(data, 201);
}

export async function handleUpdateZone(
  id: string,
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(id)) {
    throw new HttpError("validation_error", "zoneId invalide (UUID attendu)");
  }
  const patch = normalizeZoneInput(body, true);
  const admin = createAdminClient();
  const { data, error } = await admin.from("coverage_zones").update(patch).eq(
    "id",
    id,
  ).select(COLUMNS).maybeSingle();
  if (error) {
    console.error("update coverage zone error:", error);
    throw new HttpError(
      "internal_error",
      "Mise à jour de la zone impossible",
      500,
    );
  }
  if (!data) throw new HttpError("not_found", "Zone introuvable", 404);
  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "update_zone",
    targetType: "coverage_zone",
    targetId: id,
    details: patch,
  });
  return jsonResponse(data);
}

export async function handleDeleteZone(
  id: string,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(id)) {
    throw new HttpError("validation_error", "zoneId invalide (UUID attendu)");
  }
  const admin = createAdminClient();
  const { data, error } = await admin.from("coverage_zones").delete().eq(
    "id",
    id,
  ).select("id").maybeSingle();
  if (error) {
    console.error("delete coverage zone error:", error);
    throw new HttpError(
      "internal_error",
      "Suppression de la zone impossible",
      500,
    );
  }
  if (!data) throw new HttpError("not_found", "Zone introuvable", 404);
  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "delete_zone",
    targetType: "coverage_zone",
    targetId: id,
  });
  return new Response(null, { status: 204 });
}
