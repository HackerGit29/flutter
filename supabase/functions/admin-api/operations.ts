import {
  HttpError,
  isUuid,
  jsonResponse,
  paginated,
  parsePagination,
} from "./http.ts";
import { type AdminContext, createAdminClient } from "./auth.ts";
import { auditAdminAction } from "./audit.ts";
import { toCsv } from "./csv.ts";
import { normalizeGeoItems } from "./geo_bulk_validation.ts";

const MAX_EXPORT_ROWS = 20_000;
const EXPORT_TTL_SECONDS = 3600;
const CSV_DATASETS = new Set(["users", "boxes", "energy", "commands"]);
const EXPORT_STATUS_VALUES: Record<string, ReadonlySet<string>> = {
  users: new Set(["active", "suspended"]),
  boxes: new Set(["active", "inactive", "blocked"]),
  commands: new Set([
    "pending",
    "processing",
    "sent",
    "acknowledged",
    "failed",
    "rejected",
    "timeout",
  ]),
};

export function isValidExportStatus(dataset: string, status: string): boolean {
  return EXPORT_STATUS_VALUES[dataset]?.has(status) ?? false;
}

export function validateExportDateRange(
  dataset: string,
  from: string | null,
  to: string | null,
): void {
  if (dataset === "energy" && (!from || !to)) {
    throw new HttpError(
      "validation_error",
      "Les filtres from et to sont requis pour l'export énergie",
    );
  }
  if (from && to && new Date(from) > new Date(to)) {
    throw new HttpError("validation_error", "from doit précéder to");
  }
  if (
    from && to &&
    new Date(to).getTime() - new Date(from).getTime() > 366 * 86_400_000
  ) {
    throw new HttpError(
      "validation_error",
      "Période maximale: 366 jours",
    );
  }
}

function dateFilter(value: string | null, label: string): string | null {
  if (value === null) return null;
  const parsed = new Date(value);
  if (!isValidIsoDate(value)) {
    throw new HttpError(
      "validation_error",
      `${label} invalide (ISO-8601 attendu)`,
    );
  }
  return parsed.toISOString();
}

function applyDeviceFilters(query: any, url: URL): any {
  const status = url.searchParams.get("status");
  if (status) {
    if (
      ![
        "pending",
        "processing",
        "sent",
        "acknowledged",
        "failed",
        "rejected",
        "timeout",
      ].includes(status)
    ) {
      throw new HttpError("validation_error", "status de commande invalide");
    }
    query = query.eq("status", status);
  }
  const boxId = url.searchParams.get("box_id");
  if (boxId) {
    if (!isUuid(boxId)) {
      throw new HttpError("validation_error", "box_id invalide (UUID attendu)");
    }
    query = query.eq("box_id", boxId);
  }
  const userId = url.searchParams.get("user_id");
  if (userId) {
    if (!isUuid(userId)) {
      throw new HttpError(
        "validation_error",
        "user_id invalide (UUID attendu)",
      );
    }
    query = query.eq("user_id", userId);
  }
  const from = dateFilter(url.searchParams.get("from"), "from");
  const to = dateFilter(url.searchParams.get("to"), "to");
  if (from) query = query.gte("created_at", from);
  if (to) query = query.lte("created_at", to);
  return query;
}

export async function handleIotHealth(
  _url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("admin_iot_health");
  if (error || !data) {
    console.error("admin_iot_health error:", error);
    throw new HttpError(
      "internal_error",
      "Calcul de la santé IoT impossible",
      500,
    );
  }
  return jsonResponse(data);
}

export async function handleListIotCommands(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();
  let query = admin.from("device_commands").select(
    "id, box_id, user_id, action, appliance_name, requested_by, status, created_at, sent_at, acknowledged_at, error_message, ack_payload",
    { count: "exact" },
  );
  query = applyDeviceFilters(query, url);
  const { data, error, count } = await query.order("created_at", {
    ascending: false,
  }).range(p.from, p.to);
  if (error) {
    console.error("list IoT commands error:", error);
    throw new HttpError(
      "internal_error",
      "Lecture des commandes impossible",
      500,
    );
  }
  const rows = (data ?? []).map((command: any) => ({
    ...command,
    latency_ms: command.acknowledged_at
      ? Math.max(
        0,
        new Date(command.acknowledged_at).getTime() -
          new Date(command.created_at).getTime(),
      )
      : null,
  }));
  return jsonResponse(paginated(rows, count ?? rows.length, p));
}

export async function handleRetryIotCommand(
  id: string,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(id)) {
    throw new HttpError(
      "validation_error",
      "commandId invalide (UUID attendu)",
    );
  }
  const admin = createAdminClient();
  const { data: command, error } = await admin.from("device_commands").select(
    "*",
  ).eq("id", id).maybeSingle();
  if (error) {
    throw new HttpError(
      "internal_error",
      "Lecture de la commande impossible",
      500,
    );
  }
  if (!command) throw new HttpError("not_found", "Commande introuvable", 404);
  if (command.status !== "failed" && command.status !== "timeout") {
    throw new HttpError(
      "conflict",
      "Seules les commandes failed ou timeout peuvent être réessayées",
      409,
    );
  }
  const { data: retried, error: retryError } = await admin.from(
    "device_commands",
  ).insert({
    user_id: command.user_id,
    box_id: command.box_id,
    box_uid: command.box_uid,
    appliance_id: command.appliance_id,
    appliance_name: command.appliance_name,
    relay_index: command.relay_index,
    action: command.action,
    status: "pending",
    requested_by: "admin_retry",
    reason: `retry:${command.id}`,
  }).select("id, box_id, user_id, status, created_at, action, appliance_name")
    .single();
  if (retryError || !retried) {
    if (retryError?.code === "23505") {
      throw new HttpError(
        "conflict",
        "Une relance est déjà en cours pour cette commande",
        409,
      );
    }
    console.error("retry IoT command error:", retryError);
    throw new HttpError(
      "internal_error",
      "Relance de la commande impossible",
      500,
    );
  }
  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "retry_command",
    targetType: "device_command",
    targetId: retried.id,
    details: { original_command_id: command.id },
  });
  return jsonResponse(retried, 201);
}

export async function handleListSyncLogs(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();
  let query = admin.from("sync_logs").select(
    "id, box_id, user_id, status, error_message, timestamp",
    { count: "exact" },
  );
  const boxId = url.searchParams.get("box_id");
  const userId = url.searchParams.get("user_id");
  if (boxId) {
    if (!isUuid(boxId)) {
      throw new HttpError("validation_error", "box_id invalide (UUID attendu)");
    }
    query = query.eq("box_id", boxId);
  }
  if (userId) {
    if (!isUuid(userId)) {
      throw new HttpError(
        "validation_error",
        "user_id invalide (UUID attendu)",
      );
    }
    query = query.eq("user_id", userId);
  }
  const status = url.searchParams.get("status");
  if (status) query = query.eq("status", status);
  const from = dateFilter(url.searchParams.get("from"), "from");
  const to = dateFilter(url.searchParams.get("to"), "to");
  if (from) query = query.gte("timestamp", from);
  if (to) query = query.lte("timestamp", to);
  const { data, error, count } = await query.order("timestamp", {
    ascending: false,
  }).range(p.from, p.to);
  if (error) {
    console.error("list sync logs error:", error);
    throw new HttpError(
      "internal_error",
      "Lecture des synchronisations impossible",
      500,
    );
  }
  const rows = (data ?? []).map((row: any) => ({
    ...row,
    created_at: row.timestamp,
    message: row.error_message ?? null,
  }));
  return jsonResponse(paginated(rows, count ?? rows.length, p));
}

export async function handleAgentAudit(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const p = parsePagination(url);
  const admin = createAdminClient();
  let query = admin.from("agent_audit_logs").select(
    "id, user_id, action, target_type, target_id, status, details, created_at",
    { count: "exact" },
  );
  const userId = url.searchParams.get("user_id");
  if (userId) {
    if (!isUuid(userId)) {
      throw new HttpError(
        "validation_error",
        "user_id invalide (UUID attendu)",
      );
    }
    query = query.eq("user_id", userId);
  }
  const action = url.searchParams.get("action");
  if (action) query = query.eq("action", action);
  const status = url.searchParams.get("status");
  if (status) {
    if (
      !["allowed", "blocked", "failed", "success", "pending"].includes(status)
    ) throw new HttpError("validation_error", "status audit invalide");
    query = query.eq("status", status);
  }
  const from = dateFilter(url.searchParams.get("from"), "from");
  const to = dateFilter(url.searchParams.get("to"), "to");
  if (from) query = query.gte("created_at", from);
  if (to) query = query.lte("created_at", to);
  const { data, error, count } = await query.order("created_at", {
    ascending: false,
  }).range(p.from, p.to);
  if (error) {
    console.error("agent audit query error:", error);
    throw new HttpError(
      "internal_error",
      "Lecture de l'audit agent impossible",
      500,
    );
  }
  return jsonResponse(paginated(data ?? [], count ?? data?.length ?? 0, p));
}

export async function handleAgentAnalytics(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const from = dateFilter(url.searchParams.get("from"), "from") ??
    new Date(Date.now() - 30 * 86400_000).toISOString();
  const to = dateFilter(url.searchParams.get("to"), "to") ??
    new Date().toISOString();
  if (new Date(from) > new Date(to)) {
    throw new HttpError("validation_error", "from doit précéder to");
  }
  if (new Date(to).getTime() - new Date(from).getTime() > 366 * 86400_000) {
    throw new HttpError("validation_error", "Période maximale: 366 jours");
  }
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("admin_agent_analytics", {
    p_from: from,
    p_to: to,
  });
  if (error || !data) {
    console.error("admin_agent_analytics error:", error);
    throw new HttpError(
      "internal_error",
      "Calcul des analytics agent impossible",
      500,
    );
  }
  return jsonResponse({ from, to, ...data });
}

export const EXPORT_COLUMNS: Record<string, string[]> = {
  users: ["id", "email", "role", "status", "created_at"],
  boxes: [
    "id",
    "uid_hardware",
    "name",
    "location",
    "user_id",
    "status",
    "firmware_version",
    "last_sync",
    "latitude",
    "longitude",
    "geo_precision",
    "installed_at",
    "created_at",
  ],
  energy: ["id", "user_id", "appliance_id", "date", "kwh", "cumulative_kwh"],
  commands: [
    "id",
    "user_id",
    "box_id",
    "box_uid",
    "appliance_id",
    "action",
    "status",
    "requested_by",
    "created_at",
    "sent_at",
    "acknowledged_at",
    "error_message",
  ],
};

export function validateCsvExportInput(
  input: unknown,
): asserts input is {
  dataset: string;
  format?: string;
  filters?: Record<string, unknown>;
} {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new HttpError("validation_error", "Body JSON objet attendu");
  }
  const request = input as Record<string, unknown>;
  if (
    typeof request.dataset !== "string" || !CSV_DATASETS.has(request.dataset)
  ) {
    throw new HttpError(
      "validation_error",
      "dataset invalide (users|boxes|energy|commands)",
    );
  }
  if (request.format !== undefined && request.format !== "csv") {
    throw new HttpError(
      "unsupported_format",
      "Seul le format CSV est pris en charge pour cet export immédiat",
      422,
    );
  }
  const allowedKeys = new Set(["dataset", "format", "filters"]);
  const unknownKeys = Object.keys(request).filter((key) =>
    !allowedKeys.has(key)
  );
  if (unknownKeys.length) {
    throw new HttpError(
      "validation_error",
      `Champs inconnus: ${unknownKeys.join(", ")}`,
    );
  }
  if (
    request.filters !== undefined &&
    (!request.filters || typeof request.filters !== "object" ||
      Array.isArray(request.filters))
  ) {
    throw new HttpError("validation_error", "filters doit être un objet");
  }
  const filters = (request.filters ?? {}) as Record<string, unknown>;
  const allowedFilters = request.dataset === "users"
    ? new Set(["status", "from", "to"])
    : request.dataset === "boxes"
    ? new Set(["user_id", "status", "from", "to"])
    : request.dataset === "energy"
    ? new Set(["user_id", "from", "to"])
    : new Set(["user_id", "box_id", "status", "from", "to"]);
  const unknownFilters = Object.keys(filters).filter((key) =>
    !allowedFilters.has(key)
  );
  if (unknownFilters.length) {
    throw new HttpError(
      "validation_error",
      `Filtres inconnus: ${unknownFilters.join(", ")}`,
    );
  }
  if (request.dataset !== "commands" && filters.box_id !== undefined) {
    throw new HttpError(
      "validation_error",
      "Filtre box_id réservé aux commandes",
    );
  }
  for (const key of ["user_id", "box_id"] as const) {
    if (
      filters[key] !== undefined &&
      (typeof filters[key] !== "string" || !isUuid(filters[key]))
    ) {
      throw new HttpError("validation_error", `Filtre ${key} invalide`);
    }
  }
  if (
    filters.status !== undefined &&
    (typeof filters.status !== "string" ||
      !isValidExportStatus(request.dataset, filters.status))
  ) {
    throw new HttpError("validation_error", "Filtre status invalide");
  }
  for (const key of ["from", "to"] as const) {
    if (
      filters[key] !== undefined &&
      (typeof filters[key] !== "string" ||
        !isValidIsoDate(filters[key]))
    ) {
      throw new HttpError("validation_error", `Filtre ${key} invalide`);
    }
  }
  const from = filters.from === undefined ? null : String(filters.from);
  const to = filters.to === undefined ? null : String(filters.to);
  validateExportDateRange(request.dataset, from, to);
}

export function isValidIsoDate(value: string): boolean {
  const match =
    /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(Z|[+-]\d{2}:\d{2})?)?$/i
      .exec(value);
  if (!match) return false;

  const [, year, month, day, hour, minute, second, offset] = match;
  const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
  if (
    date.getUTCFullYear() !== Number(year) ||
    date.getUTCMonth() !== Number(month) - 1 ||
    date.getUTCDate() !== Number(day)
  ) return false;
  if (
    hour !== undefined &&
    (Number(hour) > 23 || Number(minute) > 59 || Number(second ?? 0) > 59)
  ) {
    return false;
  }
  if (offset && offset.toUpperCase() !== "Z") {
    const offsetHour = Number(offset.slice(1, 3));
    const offsetMinute = Number(offset.slice(4, 6));
    if (
      offsetHour > 14 || offsetMinute > 59 ||
      (offsetHour === 14 && offsetMinute !== 0)
    ) return false;
  }
  return !Number.isNaN(new Date(value).getTime());
}

async function fetchExportRows(
  admin: any,
  dataset: string,
  filters: Record<string, unknown>,
): Promise<Record<string, unknown>[]> {
  const table = dataset === "commands"
    ? "device_commands"
    : dataset === "energy"
    ? "energy_data"
    : dataset;
  let query = admin.from(table).select(EXPORT_COLUMNS[dataset]);
  for (const key of ["user_id", "box_id", "status"] as const) {
    const value = filters[key];
    if (value !== undefined) {
      if (
        typeof value !== "string" ||
        (key !== "status" && !isUuid(value)) ||
        (key === "status" && !isValidExportStatus(dataset, value))
      ) {
        throw new HttpError("validation_error", `Filtre ${key} invalide`);
      }
      query = query.eq(key, value);
    }
  }
  const from = filters.from === undefined
    ? null
    : dateFilter(String(filters.from), "from");
  const to = filters.to === undefined
    ? null
    : dateFilter(String(filters.to), "to");
  const dateColumn = dataset === "energy" ? "date" : "created_at";
  validateExportDateRange(dataset, from, to);
  if (from) {
    query = query.gte(
      dateColumn,
      dataset === "energy" ? from.slice(0, 10) : from,
    );
  }
  if (to) {
    query = query.lte(dateColumn, dataset === "energy" ? to.slice(0, 10) : to);
  }

  const { data, error } = await query.order(dateColumn, { ascending: true })
    .limit(MAX_EXPORT_ROWS + 1);
  if (error) {
    console.error("export query error:", error);
    throw new HttpError(
      "internal_error",
      "Lecture des données à exporter impossible",
      500,
    );
  }
  if ((data?.length ?? 0) > MAX_EXPORT_ROWS) {
    throw new HttpError(
      "export_too_large",
      `Export limité à ${MAX_EXPORT_ROWS} lignes`,
      413,
    );
  }
  return data ?? [];
}

export async function handleCreateCsvExport(
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  validateCsvExportInput(body);
  const input = body;
  const filters = input.filters ?? {};
  // Direct handler callers still get the same strict validation as the router.
  validateCsvExportInput({ ...input, filters });
  const admin = createAdminClient();
  const rows = await fetchExportRows(admin, input.dataset, filters);
  const columns = EXPORT_COLUMNS[input.dataset];
  const csv = `\uFEFF${toCsv(columns, rows)}`;
  const exportId = crypto.randomUUID();
  const path = `${ctx.adminId}/${exportId}.csv`;
  const { error: uploadError } = await admin.storage.from("admin-exports")
    .upload(path, new Blob([csv], { type: "text/csv; charset=utf-8" }), {
      contentType: "text/csv; charset=utf-8",
      upsert: false,
    });
  if (uploadError) {
    console.error("CSV upload error:", uploadError);
    throw new HttpError(
      "internal_error",
      "Stockage de l'export impossible",
      500,
    );
  }
  const { data: signed, error: signedError } = await admin.storage.from(
    "admin-exports",
  ).createSignedUrl(path, EXPORT_TTL_SECONDS, {
    download: `aricie-${input.dataset}-${
      new Date().toISOString().slice(0, 10)
    }.csv`,
  });
  if (signedError || !signed?.signedUrl) {
    await admin.storage.from("admin-exports").remove([path]);
    console.error("CSV signed URL error:", signedError);
    throw new HttpError(
      "internal_error",
      "Création du lien de téléchargement impossible",
      500,
    );
  }
  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "create_export",
    targetType: "user",
    targetId: ctx.adminId,
    details: { dataset: input.dataset, format: "csv", rows: rows.length, path },
  });
  return jsonResponse({
    export_id: exportId,
    status: "ready",
    row_count: rows.length,
    format: "csv",
    download_url: signed.signedUrl,
    expires_in_seconds: EXPORT_TTL_SECONDS,
  }, 201);
}

export async function handleGetCsvExport(
  id: string,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(id)) {
    throw new HttpError("validation_error", "exportId invalide (UUID attendu)");
  }
  const admin = createAdminClient();
  const path = `${ctx.adminId}/${id}.csv`;
  const { data: file, error: fileError } = await admin.storage.from(
    "admin-exports",
  ).list(ctx.adminId, {
    limit: 1,
    search: `${id}.csv`,
  });
  if (
    fileError ||
    !file?.some((entry: { name: string }) => entry.name === `${id}.csv`)
  ) {
    throw new HttpError("not_found", "Export introuvable ou expiré", 404);
  }
  const { data, error } = await admin.storage.from("admin-exports")
    .createSignedUrl(path, EXPORT_TTL_SECONDS);
  if (error || !data?.signedUrl) {
    throw new HttpError("not_found", "Export introuvable ou expiré", 404);
  }
  return jsonResponse({
    export_id: id,
    status: "ready",
    download_url: data.signedUrl,
    expires_in_seconds: EXPORT_TTL_SECONDS,
  });
}

export async function handleUserDataExport(
  userId: string,
  ctx: AdminContext,
): Promise<Response> {
  if (!isUuid(userId)) {
    throw new HttpError("validation_error", "userId invalide (UUID attendu)");
  }
  const admin = createAdminClient();
  const userResult = await admin.from("users").select(
    "id, email, role, status, created_at, updated_at",
  ).eq("id", userId).maybeSingle();
  if (userResult.error) {
    console.error("RGPD user profile query error:", userResult.error);
    throw new HttpError("internal_error", "Lecture du profil impossible", 500);
  }
  if (!userResult.data) {
    throw new HttpError("not_found", "Utilisateur introuvable", 404);
  }

  const subscriptionIds = await getSubscriptionIds(admin, userId);
  const queries: PromiseLike<{ data: any; error: any }>[] = [
    admin.from("boxes").select("*").eq("user_id", userId).limit(
      MAX_EXPORT_ROWS + 1,
    ),
    admin.from("appliances").select("*").eq("user_id", userId).limit(
      MAX_EXPORT_ROWS + 1,
    ),
    admin.from("subscriptions").select("*").eq("user_id", userId).limit(
      MAX_EXPORT_ROWS + 1,
    ),
    subscriptionIds.length
      ? admin.from("licenses").select(
        "id, subscription_id, activation_date, expiration_date, created_at, revoked_at, revoke_reason",
      ).in("subscription_id", subscriptionIds).limit(MAX_EXPORT_ROWS + 1)
      : Promise.resolve({ data: [], error: null }),
    admin.from("energy_data").select("*").eq("user_id", userId).limit(
      MAX_EXPORT_ROWS + 1,
    ),
    admin.from("sync_logs").select("*").eq("user_id", userId).limit(
      MAX_EXPORT_ROWS + 1,
    ),
    admin.from("device_commands").select("*").eq("user_id", userId).limit(
      MAX_EXPORT_ROWS + 1,
    ),
    admin.from("agent_audit_logs").select(
      "id, action, target_type, target_id, status, details, created_at",
    ).eq("user_id", userId).limit(MAX_EXPORT_ROWS + 1),
    admin.from("analytics_events").select(
      "id, box_id, event, properties, created_at",
    ).eq("user_id", userId).limit(MAX_EXPORT_ROWS + 1),
    admin.from("chat_embeddings").select(
      "id, scope, source_type, source_id, content, metadata, created_at",
    ).eq("owner_id", userId).limit(MAX_EXPORT_ROWS + 1),
    admin.from("energy_tips_realtime").select(
      "id, title, body, icon, severity, source, acknowledged, created_at",
    ).eq("user_id", userId).limit(MAX_EXPORT_ROWS + 1),
    admin.from("daily_energy_tip").select(
      "date, title, body, icon, severity, rule_id, context, generated_at",
    ).eq("user_id", userId).limit(MAX_EXPORT_ROWS + 1),
    admin.from("product_keys").select("id, is_used, used_at, created_at").eq(
      "used_by",
      userId,
    ).limit(MAX_EXPORT_ROWS + 1),
  ];
  const results = await Promise.all(queries);
  if (results.some((result) => result.error)) {
    console.error(
      "RGPD export query error:",
      results.find((result) => result.error)?.error,
    );
    throw new HttpError(
      "internal_error",
      "Export RGPD incomplet, aucune archive n'a été créée",
      500,
    );
  }
  if (
    results.some((result) =>
      Array.isArray(result.data) && result.data.length > MAX_EXPORT_ROWS
    )
  ) throw new HttpError("export_too_large", "Export RGPD trop volumineux", 413);
  const data: Record<string, unknown> = {
    generated_at: new Date().toISOString(),
    user: userResult.data,
    boxes: results[0].data,
    appliances: results[1].data,
    subscriptions: results[2].data,
    licenses: results[3].data,
    energy_data: results[4].data,
    sync_logs: results[5].data,
    device_commands: results[6].data,
    agent_audit_logs: results[7].data,
    analytics_events: results[8].data,
    chat_embeddings: results[9].data,
    energy_tips_realtime: results[10].data,
    daily_energy_tip: results[11].data,
    product_keys: results[12].data,
  };
  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "export_user_data",
    targetType: "user",
    targetId: userId,
    details: {
      row_counts: Object.fromEntries(
        Object.entries(data).filter((entry): entry is [string, unknown[]] =>
          Array.isArray(entry[1])
        ).map(([key, value]) => [key, value.length]),
      ),
    },
  });
  return new Response(JSON.stringify(data, null, 2), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Content-Disposition":
        `attachment; filename="aricie-user-${userId}-export.json"`,
      "Cache-Control": "no-store",
    },
  });
}

async function getSubscriptionIds(
  admin: any,
  userId: string,
): Promise<string[]> {
  const { data, error } = await admin.from("subscriptions").select("id").eq(
    "user_id",
    userId,
  ).limit(MAX_EXPORT_ROWS + 1);
  if (error) {
    throw new HttpError(
      "internal_error",
      "Lecture des abonnements pour export impossible",
      500,
    );
  }
  if ((data?.length ?? 0) > MAX_EXPORT_ROWS) {
    throw new HttpError(
      "export_too_large",
      "Trop d'abonnements liés à l'utilisateur",
      413,
    );
  }
  return (data ?? []).map((row: any) => row.id);
}

export async function handleBulkGeo(
  body: unknown,
  ctx: AdminContext,
): Promise<Response> {
  const normalized = normalizeGeoItems(body);
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("admin_update_boxes_geo_bulk", {
    p_items: normalized,
  });
  if (error) {
    console.error("bulk geo rpc error:", error);
    throw new HttpError(
      "validation_error",
      "Mise à jour batch refusée : vérifier les boîtiers et les coordonnées",
      400,
    );
  }
  await auditAdminAction({
    supabase: admin,
    adminId: ctx.adminId,
    action: "bulk_geo",
    targetType: "box",
    targetId: normalized[0].box_id,
    details: {
      count: normalized.length,
      box_ids: normalized.map((item) => item.box_id),
    },
  });
  return jsonResponse({ updated: (data ?? []).length, data: data ?? [] });
}
