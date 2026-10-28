// Edge Function admin-api — routes Abonnements
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.9 (A11)
//
// GET   /v1/subscriptions      → liste paginée + filtres (viewer+)
// PATCH /v1/subscriptions/:id  → maj opérateur billing (operator+)
//
// Contrat de réponse : AdminSubscription (admin/src/types/admin.ts) —
//   { ...Subscription, user_email, monthly_amount_eur, days_until_expiry }.
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

const SUB_COLUMNS =
  "id, user_id, type, start_date, end_date, is_active, auto_renew, created_at";

const VALID_SUB_TYPE = ["free", "vip"];

// Prix VIP mensuel en euros — même source que kpi.ts (config, TODO billing).
const VIP_MONTHLY_PRICE_EUR = Number(
  Deno.env.get("VIP_MONTHLY_PRICE_EUR") ?? "0",
);

type SubscriptionRow = {
  id: string;
  user_id: string;
  type: string;
  start_date: string;
  end_date: string | null;
  is_active: boolean;
  auto_renew: boolean;
  created_at: string;
};

/** GET /v1/subscriptions?type=&is_active=&expiring_within_days=&page=&page_size= */
export async function handleListSubscriptions(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();

  let query = admin
    .from("subscriptions")
    .select(`${SUB_COLUMNS}, user:users(email)`, { count: "exact" });

  const type = url.searchParams.get("type");
  if (type) {
    if (!VALID_SUB_TYPE.includes(type)) {
      throw new HttpError("validation_error", `type invalide: ${type}`);
    }
    query = query.eq("type", type);
  }

  const isActive = url.searchParams.get("is_active");
  if (isActive !== null && isActive !== "") {
    if (isActive !== "true" && isActive !== "false") {
      throw new HttpError(
        "validation_error",
        "is_active invalide (true|false)",
      );
    }
    query = query.eq("is_active", isActive === "true");
  }

  // Abonnements dont l'échéance tombe dans les N prochains jours.
  const expiringWithin = url.searchParams.get("expiring_within_days");
  if (expiringWithin) {
    const days = parseInt(expiringWithin, 10);
    if (Number.isNaN(days) || days < 0) {
      throw new HttpError(
        "validation_error",
        "expiring_within_days invalide (entier positif)",
      );
    }
    const nowIso = new Date().toISOString();
    const limitIso = new Date(Date.now() + days * 86400_000).toISOString();
    query = query
      .not("end_date", "is", null)
      .gte("end_date", nowIso)
      .lte("end_date", limitIso);
  }

  const sort = url.searchParams.get("sort") ?? "created_at_desc";
  const sortMap: Record<string, { column: string; ascending: boolean }> = {
    created_at_desc: { column: "created_at", ascending: false },
    created_at_asc: { column: "created_at", ascending: true },
    end_date_asc: { column: "end_date", ascending: true },
    end_date_desc: { column: "end_date", ascending: false },
  };
  const sortSpec = sortMap[sort];
  if (!sortSpec) {
    throw new HttpError(
      "validation_error",
      `sort invalide: ${sort} (${Object.keys(sortMap).join("|")})`,
    );
  }

  const { data, error, count } = await query
    .order(sortSpec.column, { ascending: sortSpec.ascending, nullsFirst: false })
    .range(p.from, p.to);

  if (error) {
    console.error("list subscriptions error:", error);
    throw new HttpError(
      "internal_error",
      "Lecture des abonnements impossible",
      500,
    );
  }

  const subs = ((data ?? []) as any[]).map((s) =>
    decorateSubscription(s, s.user?.email ?? null)
  );

  return jsonResponse(paginated(subs, count ?? subs.length, p));
}

/** PATCH /v1/subscriptions/:id — { type?, end_date?, is_active?, auto_renew? } (operator+) */
export async function handleUpdateSubscription(
  subId: string,
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(subId)) {
    throw new HttpError("validation_error", "subscriptionId invalide (UUID attendu)");
  }
  const b = (body as any) ?? {};

  const patch: Record<string, unknown> = {};
  if (b.type !== undefined) {
    if (!VALID_SUB_TYPE.includes(b.type)) {
      throw new HttpError("validation_error", `type invalide: ${b.type} (free|vip)`);
    }
    patch.type = b.type;
  }
  if (b.end_date !== undefined) {
    // null = abonnement sans échéance ; sinon ISO-8601.
    if (b.end_date !== null) {
      const parsed = new Date(b.end_date);
      if (Number.isNaN(parsed.getTime())) {
        throw new HttpError("validation_error", "end_date invalide (ISO-8601 attendu)");
      }
      patch.end_date = parsed.toISOString();
    } else {
      patch.end_date = null;
    }
  }
  if (b.is_active !== undefined) {
    if (typeof b.is_active !== "boolean") {
      throw new HttpError("validation_error", "is_active invalide (booléen attendu)");
    }
    patch.is_active = b.is_active;
  }
  if (b.auto_renew !== undefined) {
    if (typeof b.auto_renew !== "boolean") {
      throw new HttpError("validation_error", "auto_renew invalide (booléen attendu)");
    }
    patch.auto_renew = b.auto_renew;
  }

  if (Object.keys(patch).length === 0) {
    throw new HttpError(
      "validation_error",
      "Aucun champ à mettre à jour (type|end_date|is_active|auto_renew)",
    );
  }

  const admin = createAdminClient();
  const { data: updated, error } = await admin
    .from("subscriptions")
    .update(patch)
    .eq("id", subId)
    .select(`${SUB_COLUMNS}, user:users(email)`)
    .single();

  if (error || !updated) {
    if (error?.code === "PGRST116") {
      throw new HttpError("not_found", "Abonnement introuvable", 404);
    }
    console.error("update subscription error:", error);
    throw new HttpError("internal_error", "Mise à jour impossible", 500);
  }

  const row = updated as any;

  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "update_subscription",
    targetType: "subscription",
    targetId: subId,
    details: { user_id: row.user_id, ...patch },
  });

  return jsonResponse(decorateSubscription(row, row.user?.email ?? null));
}

/** Enrichit une ligne subscription vers le contrat AdminSubscription. */
function decorateSubscription(
  s: SubscriptionRow & { user?: { email: string | null } | null },
  userEmail: string | null,
) {
  const daysUntilExpiry = s.end_date
    ? Math.ceil(
      (new Date(s.end_date).getTime() - Date.now()) / 86400_000,
    )
    : null;

  return {
    id: s.id,
    user_id: s.user_id,
    type: s.type,
    start_date: s.start_date,
    end_date: s.end_date,
    is_active: s.is_active,
    auto_renew: s.auto_renew,
    created_at: s.created_at,
    user_email: userEmail,
    monthly_amount_eur: s.type === "vip" ? VIP_MONTHLY_PRICE_EUR : 0,
    days_until_expiry: daysUntilExpiry,
  };
}
