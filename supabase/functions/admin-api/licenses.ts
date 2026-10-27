// Edge Function admin-api — routes Licences
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.9 / §6.9
//
// GET   /v1/licenses           → liste + statut activation dérivé (viewer+)
// POST  /v1/licenses/activate  → activation d'une licence (operator+)
// POST  /v1/licenses/revoke    → révocation motivée (super_admin)
//
// La table `licenses` ne stocke pas de statut : il est dérivé à la lecture
// (revoked_at -> revoked ; expiration_date passée -> expired ; sinon active)
// pour éviter une colonne dénormalisée qui dériverait de la vérité.
//
// Contrat de réponse : License (admin/src/types/admin.ts).
// Toute écriture passe par auditAdminAction (§7).

import {
  HttpError,
  isUuid,
  jsonResponse,
  paginated,
  parsePagination,
} from "./http.ts";
import { createAdminClient, type AdminContext } from "./auth.ts";
import { auditAdminAction } from "./audit.ts";

const LICENSE_COLUMNS =
  "id, subscription_id, license_key, activation_date, expiration_date, " +
  "revoked_at, revoke_reason, created_at";

type LicenseRow = {
  id: string;
  subscription_id: string | null;
  license_key: string;
  activation_date: string | null;
  expiration_date: string | null;
  revoked_at: string | null;
  revoke_reason: string | null;
  created_at: string;
  subscription?: {
    user_id: string | null;
    user: { email: string | null } | null;
  } | null;
};

/** Dérive le statut d'une licence à partir de ses colonnes de vie. */
function deriveStatus(row: LicenseRow): "active" | "revoked" | "expired" {
  if (row.revoked_at) return "revoked";
  if (row.expiration_date && new Date(row.expiration_date).getTime() < Date.now()) {
    return "expired";
  }
  return "active";
}

/** GET /v1/licenses?status=&subscription_id=&q=&page=&page_size= */
export async function handleListLicenses(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();

  let query = admin
    .from("licenses")
    .select(
      `${LICENSE_COLUMNS}, subscription:user_id(id, user_id, user:users(email))`,
      { count: "exact" },
    );

  const subscriptionId = url.searchParams.get("subscription_id");
  if (subscriptionId) {
    if (!isUuid(subscriptionId)) {
      throw new HttpError(
        "validation_error",
        "subscription_id invalide (UUID attendu)",
      );
    }
    query = query.eq("subscription_id", subscriptionId);
  }

  const q = url.searchParams.get("q");
  if (q && q.trim().length >= 2) {
    query = query.ilike("license_key", `%${q.trim()}%`);
  }

  // Filtre `status` : filtré côté SQL sur les colonnes de vie, pas en mémoire,
  // pour que la pagination reste exacte.
  const status = url.searchParams.get("status");
  if (status) {
    if (!["active", "revoked", "expired"].includes(status)) {
      throw new HttpError(
        "validation_error",
        `status invalide: ${status} (active|revoked|expired)`,
      );
    }
    if (status === "revoked") {
      query = query.not("revoked_at", "is", null);
    } else if (status === "expired") {
      query = query
        .is("revoked_at", null)
        .not("expiration_date", "is", null)
        .lt("expiration_date", new Date().toISOString());
    } else {
      // active : ni révoquée, ni expirée
      query = query.or(
        "and(revoked_at.is.null,expiration_date.is.null)," +
          "and(revoked_at.is.null,expiration_date.gte." +
          new Date().toISOString() + ")",
      );
    }
  }

  const { data, error, count } = await query
    .order("created_at", { ascending: false })
    .range(p.from, p.to);

  if (error) {
    console.error("list licenses error:", error);
    throw new HttpError("internal_error", "Lecture des licences impossible", 500);
  }

  const licenses = ((data ?? []) as any[]).map((row) =>
    decorateLicense(row as LicenseRow)
  );

  return jsonResponse(paginated(licenses, count ?? licenses.length, p));
}

/** POST /v1/licenses/activate — { subscription_id, expiration_date? } (operator+) */
export async function handleActivateLicense(
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  const b = (body as any) ?? {};
  const { subscription_id, expiration_date } = b;

  if (!subscription_id || !isUuid(subscription_id)) {
    throw new HttpError(
      "validation_error",
      "subscription_id requis (UUID attendu)",
    );
  }

  let expirationIso: string | null = null;
  if (expiration_date !== undefined && expiration_date !== null) {
    const parsed = new Date(expiration_date);
    if (Number.isNaN(parsed.getTime())) {
      throw new HttpError(
        "validation_error",
        "expiration_date invalide (ISO-8601 attendu)",
      );
    }
    expirationIso = parsed.toISOString();
  }

  const admin = createAdminClient();

  // La souscription doit exister
  const { data: sub } = await admin
    .from("subscriptions")
    .select("id, user_id")
    .eq("id", subscription_id)
    .single();
  if (!sub) {
    throw new HttpError("not_found", "Abonnement introuvable", 404);
  }

  // Une licence active ne peut pas en remplacer une autre sur la même
  // souscription : on refuse pour éviter les doubles actifs.
  const nowIso = new Date().toISOString();
  const { data: existing } = await admin
    .from("licenses")
    .select("id")
    .eq("subscription_id", subscription_id)
    .is("revoked_at", null)
    .or(`expiration_date.is.null,expiration_date.gte.${nowIso}`)
    .limit(1);
  if (existing && existing.length > 0) {
    throw new HttpError(
      "conflict",
      "Une licence active existe déjà pour cet abonnement",
      409,
    );
  }

  const licenseKey = generateLicenseKey();

  const insertResult = await admin
    .from("licenses")
    .insert({
      subscription_id,
      license_key: licenseKey,
      activation_date: nowIso,
      expiration_date: expirationIso,
    })
    .select(LICENSE_COLUMNS)
    .single();
  const created = insertResult.data as LicenseRow | null;
  const error = insertResult.error;

  if (error || !created) {
    if (error?.code === "23505") {
      throw new HttpError("conflict", "Clé de licence déjà utilisée", 409);
    }
    console.error("activate license error:", error);
    throw new HttpError("internal_error", "Activation impossible", 500);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "activate_license",
    targetType: "license",
    targetId: created.id,
    details: {
      subscription_id,
      user_id: sub.user_id,
      license_key: licenseKey,
      expiration_date: expirationIso,
    },
  });

  return jsonResponse(
    decorateLicense({
      ...created,
      subscription: { user_id: sub.user_id, user: null },
    }),
    201,
  );
}

/** POST /v1/licenses/revoke — { license_id, reason } (super_admin) */
export async function handleRevokeLicense(
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  const b = (body as any) ?? {};
  const { license_id, reason } = b;

  if (!license_id || !isUuid(license_id)) {
    throw new HttpError("validation_error", "license_id requis (UUID attendu)");
  }
  if (!reason || typeof reason !== "string" || !reason.trim()) {
    throw new HttpError(
      "validation_error",
      "reason requis (motif de révocation obligatoire, §6.9)",
    );
  }

  const admin = createAdminClient();

  const { data: license } = await admin
    .from("licenses")
    .select("id, subscription_id, revoked_at")
    .eq("id", license_id)
    .single();
  if (!license) {
    throw new HttpError("not_found", "Licence introuvable", 404);
  }
  if (license.revoked_at) {
    throw new HttpError("conflict", "Licence déjà révoquée", 409);
  }

  const revokedAt = new Date().toISOString();
  const updateResult = await admin
    .from("licenses")
    .update({ revoked_at: revokedAt, revoke_reason: reason.trim() })
    .eq("id", license_id)
    .select(LICENSE_COLUMNS)
    .single();
  const updated = updateResult.data as LicenseRow | null;

  if (updateResult.error || !updated) {
    console.error("revoke license error:", updateResult.error);
    throw new HttpError("internal_error", "Révocation impossible", 500);
  }

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "revoke_license",
    targetType: "license",
    targetId: license_id,
    details: { reason: reason.trim(), subscription_id: license.subscription_id },
  });

  return jsonResponse(
    decorateLicense({
      ...updated,
      subscription: { user_id: null, user: null },
    }),
  );
}

/** Génère une clé de licence lisible, non devinable, unique. */
function generateLicenseKey(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sans O/0/I/1
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  let raw = "";
  for (const byte of bytes) {
    raw += alphabet[byte % alphabet.length];
  }
  // Groupes de 4 : ARICIE-XXXX-XXXX-XXXX-XXXX
  return "ARICIE-" + raw.match(/.{4}/g)!.join("-");
}

/** Enrichit une ligne `licenses` vers le contrat License du front. */
function decorateLicense(row: LicenseRow) {
  return {
    id: row.id,
    subscription_id: row.subscription_id,
    user_id: row.subscription?.user_id ?? null,
    user_email: row.subscription?.user?.email ?? null,
    license_key: row.license_key,
    status: deriveStatus(row),
    activated_at: row.activation_date,
    expires_at: row.expiration_date,
    revoked_at: row.revoked_at,
    revoke_reason: row.revoke_reason,
  };
}
