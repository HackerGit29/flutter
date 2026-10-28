import { HttpError } from "./http.ts";

const ALLOWED_FIELDS = new Set([
  "name",
  "center_lat",
  "center_lng",
  "radius_km",
  "target_clients",
  "is_active",
]);

export type ZonePatch = {
  name?: string;
  center_lat?: number;
  center_lng?: number;
  radius_km?: number;
  target_clients?: number;
  is_active?: boolean;
};

export function normalizeZoneInput(body: unknown, partial = false): ZonePatch {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new HttpError("validation_error", "Body JSON objet attendu");
  }
  const input = body as Record<string, unknown>;
  const unknownFields = Object.keys(input).filter((field) =>
    !ALLOWED_FIELDS.has(field)
  );
  if (unknownFields.length) {
    throw new HttpError(
      "validation_error",
      `Champs inconnus: ${unknownFields.join(", ")}`,
    );
  }
  if (Object.keys(input).length === 0) {
    throw new HttpError("validation_error", "Au moins un champ est requis");
  }

  const output: ZonePatch = {};
  if (input.name !== undefined) {
    if (
      typeof input.name !== "string" || !input.name.trim() ||
      input.name.trim().length > 120
    ) {
      throw new HttpError(
        "validation_error",
        "name doit contenir 1 à 120 caractères",
      );
    }
    output.name = input.name.trim();
  } else if (!partial) {
    throw new HttpError("validation_error", "name requis");
  }

  for (
    const [field, min, max] of [
      ["center_lat", -90, 90],
      ["center_lng", -180, 180],
      ["radius_km", Number.MIN_VALUE, 20040],
    ] as const
  ) {
    const value = input[field];
    if (value === undefined) {
      if (!partial) throw new HttpError("validation_error", `${field} requis`);
      continue;
    }
    if (
      typeof value !== "number" || !Number.isFinite(value) || value < min ||
      value > max
    ) {
      throw new HttpError("validation_error", `${field} hors limites`);
    }
    output[field] = value;
  }

  if (input.target_clients !== undefined) {
    if (
      !Number.isInteger(input.target_clients) ||
      (input.target_clients as number) < 0
    ) {
      throw new HttpError(
        "validation_error",
        "target_clients doit être un entier positif ou nul",
      );
    }
    output.target_clients = input.target_clients as number;
  } else if (!partial) {
    output.target_clients = 0;
  }

  if (input.is_active !== undefined) {
    if (typeof input.is_active !== "boolean") {
      throw new HttpError("validation_error", "is_active doit être un booléen");
    }
    output.is_active = input.is_active;
  } else if (!partial) {
    output.is_active = true;
  }
  return output;
}
