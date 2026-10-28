import { HttpError, isUuid } from "./http.ts";

export type GeoBulkItem = {
  box_id: string;
  latitude: number;
  longitude: number;
  geo_precision: string;
};

export function normalizeGeoItems(body: unknown): GeoBulkItem[] {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new HttpError("validation_error", "Body JSON objet attendu");
  }
  const items = (body as Record<string, unknown>).items;
  if (!Array.isArray(items) || items.length < 1 || items.length > 200) {
    throw new HttpError(
      "validation_error",
      "items doit contenir entre 1 et 200 éléments",
    );
  }
  const normalized = items.map((item, index) => {
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      throw new HttpError("validation_error", `items[${index}] invalide`);
    }
    const row = item as Record<string, unknown>;
    if (typeof row.box_id !== "string" || !isUuid(row.box_id)) {
      throw new HttpError(
        "validation_error",
        `items[${index}].box_id invalide`,
      );
    }
    if (
      !Number.isFinite(row.lat) || typeof row.lat !== "number" ||
      row.lat < -90 || row.lat > 90 || !Number.isFinite(row.lng) ||
      typeof row.lng !== "number" || row.lng < -180 || row.lng > 180
    ) {
      throw new HttpError(
        "validation_error",
        `items[${index}] coordonnées invalides`,
      );
    }
    if (
      typeof row.precision !== "string" ||
      !["exact", "approx", "city", "manual"].includes(row.precision)
    ) {
      throw new HttpError(
        "validation_error",
        `items[${index}].precision invalide`,
      );
    }
    return {
      box_id: row.box_id,
      latitude: row.lat,
      longitude: row.lng,
      geo_precision: row.precision,
    };
  });
  if (
    new Set(normalized.map((item) => item.box_id)).size !== normalized.length
  ) throw new HttpError("validation_error", "box_id dupliqué dans items");
  return normalized;
}
