/**
 * Contrats de l'API `admin-api`.
 *
 * Miroir TypeScript de `docs/cahier-des-charges-admin-dashboard.md` §5.2,
 * complété par les types introduits avec les routes géo, IoT, agent,
 * abonnements, exports et notes.
 *
 * Règle : ce fichier décrit **exactement** la forme des réponses de l'Edge
 * Function (snake_case, dates ISO-8601 UTC). Toute divergence est un bug du
 * backend, pas un cas à absorber ici.
 */

/* ------------------------------------------------------------------ */
/* Primitives                                                          */
/* ------------------------------------------------------------------ */

/** Niveau d'accès du backoffice. `viewer` < `operator` < `super_admin`. */
export type AdminLevel = 'viewer' | 'operator' | 'super_admin';

/** Ordre de comparaison des niveaux, du plus faible au plus élevé. */
export const ADMIN_LEVEL_RANK: Record<AdminLevel, number> = {
  viewer: 0,
  operator: 1,
  super_admin: 2,
};

/**
 * Identité renvoyée par `GET /v1/me`.
 *
 * Permet au front de connaître son propre niveau d'accès sans interroger la
 * base directement — c'est `admin-api` qui fait autorité.
 */
export interface AdminIdentity {
  id: string;
  email: string;
  role: UserRole;
  level: AdminLevel;
}

/**
 * Session d'un administrateur connecté.
 *
 * Le niveau vient **du backend** (`users.admin_level`) : le front ne fait que
 * masquer ce qui est déjà interdit côté serveur. Il ne s'agit jamais d'une
 * mesure de sécurité, seulement d'un confort d'interface.
 */
export interface AdminSession {
  id: string;
  email: string;
  level: AdminLevel;
  /** JWT Supabase, transmis en `Authorization: Bearer` à `admin-api`. */
  accessToken: string;
  /** Expiration du jeton, en millisecondes depuis l'époque. */
  expiresAt: number | null;
}

/** Vrai si `level` atteint au moins `minLevel`. */
export function hasLevel(level: AdminLevel | null, minLevel: AdminLevel): boolean {
  if (!level) return false;
  return ADMIN_LEVEL_RANK[level] >= ADMIN_LEVEL_RANK[minLevel];
}

/** Rôle applicatif d'un compte. */
export type UserRole = 'user' | 'vip' | 'admin';

/** Statut d'un compte. */
export type UserStatus = 'active' | 'suspended';

/** Statut d'un boîtier. */
export type BoxStatus = 'active' | 'inactive' | 'blocked';

/** Type d'abonnement. */
export type SubType = 'free' | 'vip';

/** Cycle de vie d'une commande appareil. */
export type DeviceCommandStatus = 'pending' | 'sent' | 'acknowledged' | 'failed' | 'rejected' | 'timeout';

/** Précision d'une position géographique. */
export type GeoPrecision = 'exact' | 'approx' | 'city' | 'manual';

/** Format d'export. */
export type ExportFormat = 'csv' | 'xlsx';

/** Jeux de données exportables. */
export type ExportDataset = 'users' | 'boxes' | 'energy' | 'commands';

/* ------------------------------------------------------------------ */
/* Enveloppe de pagination                                             */
/* ------------------------------------------------------------------ */

export interface Paginated<T> {
  data: T[];
  page: number;
  page_size: number;
  total: number;
}

/** Forme d'erreur normalisée de l'API. */
export interface ApiErrorBody {
  error: {
    code: string;
    message: string;
  };
}

/* ------------------------------------------------------------------ */
/* Abonnements                                                         */
/* ------------------------------------------------------------------ */

export interface Subscription {
  id: string;
  user_id: string;
  type: SubType;
  start_date: string;
  end_date: string | null;
  is_active: boolean;
  auto_renew: boolean;
  license_key?: string | null;
}

/** Abonnement enrichi du nom du client, tel que renvoyé par `/v1/subscriptions`. */
export interface AdminSubscription extends Subscription {
  user_email: string | null;
  /** Montant mensuel en euros, déduit du tarif VIP en configuration. */
  monthly_amount_eur: number;
  /** Jours restants avant `end_date` (négatif si dépassé). */
  days_until_expiry: number | null;
}

/* ------------------------------------------------------------------ */
/* Utilisateurs                                                        */
/* ------------------------------------------------------------------ */

export interface AdminUser {
  id: string;
  email: string;
  role: UserRole;
  admin_level: AdminLevel | null;
  status: UserStatus;
  created_at: string;
  /** Abonnement actif, ou `null`. */
  subscription: Subscription | null;
  /** Nombre de boîtiers rattachés. */
  box_count: number;
  /** Dernière activité, max(sync_logs, analytics_events), ou `null`. */
  last_activity_at: string | null;
}

/** Boîtier résumé, tel qu'intégré dans la fiche 360°. */
export interface BoxSummary {
  id: string;
  uid_hardware: string;
  name: string;
  status: BoxStatus;
  last_sync: string | null;
  online: boolean;
  latitude: number | null;
  longitude: number | null;
}

/** Objet d'une action d'admin dans la timeline. */
export interface UserTimelineItem {
  at: string;
  kind: 'auth' | 'sync' | 'device_command' | 'agent_audit' | 'admin_action' | 'event';
  label: string;
  details?: Record<string, unknown>;
}

/** Totaux énergétiques d'un client. */
export interface UserEnergyTotals {
  kwh_30d: number;
  kwh_365d: number;
}

/** Fiche client 360° (`GET /v1/users/:id`). */
export interface AdminUserDetail {
  user: AdminUser;
  boxes: BoxSummary[];
  subscription: Subscription | null;
  totals: UserEnergyTotals;
  /** Taux de commandes acquittées, 0..1, ou `null` si aucune commande. */
  device_success_rate: number | null;
  /** Nombre de messages envoyés à l'agent sur 30 jours. */
  agent_messages_30d: number;
}

/* ------------------------------------------------------------------ */
/* Boîtiers                                                            */
/* ------------------------------------------------------------------ */

export interface AdminAppliance {
  id: string;
  box_id: string;
  name: string;
  /** Catégorie métier dérivée du nom (`chauffe-eau`, `chauffage`…). */
  category: string | null;
  relay_index: number | null;
  is_on: boolean | null;
  power_w: number | null;
}

export interface AdminBox {
  id: string;
  uid_hardware: string;
  name: string;
  location: string | null;
  user_id: string | null;
  user_email?: string | null;
  status: BoxStatus;
  firmware_version: string | null;
  last_sync: string | null;
  latitude: number | null;
  longitude: number | null;
  geo_precision: GeoPrecision | null;
  installed_at: string | null;
  created_at: string;
  appliance_count?: number;
  /** `last_sync` il y a moins de 5 minutes. */
  online?: boolean;
}

/** Commande appareil telle que journalisée dans `device_commands`. */
export interface DeviceCommand {
  id: string;
  box_id: string | null;
  user_id: string | null;
  /** Nom du tool de l'agent, ex. `turn_off_appliance`. */
  tool_name: string | null;
  /** Nom métier de l'appareil visé, ex. `chauffe-eau`. */
  appliance_name: string | null;
  status: DeviceCommandStatus;
  created_at: string;
  sent_at: string | null;
  acknowledged_at: string | null;
  /** Latence en millisecondes entre création et acquittement. */
  latency_ms: number | null;
  error_message: string | null;
  ack_payload?: Record<string, unknown> | null;
}

/** Ligne de `sync_logs`. */
export interface SyncLog {
  id: string;
  box_id: string | null;
  user_id: string | null;
  status: string;
  message: string | null;
  created_at: string;
}

/** Détail d'un boîtier (`GET /v1/boxes/:id`). */
export interface AdminBoxDetail {
  box: AdminBox;
  appliances: AdminAppliance[];
  commands: DeviceCommand[];
  sync_logs: SyncLog[];
}

/* ------------------------------------------------------------------ */
/* Géo                                                                 */
/* ------------------------------------------------------------------ */

export interface GeoPoint {
  lat: number;
  lng: number;
  /** Poids pour la heatmap (kWh, nombre de clients…). */
  weight: number;
  meta?: Record<string, unknown>;
}

/** Cluster de boîtiers agrégé par geohash. */
export interface CoverageCluster {
  geohash: string;
  lat: number;
  lng: number;
  box_count: number;
  user_count: number;
  vip_count: number;
  /** Somme des kWh sur la période demandée, si calculée. */
  kwh?: number;
  zone_id: string | null;
}

/** Zone commerciale cible, définie par l'entreprise. */
export interface CoverageZone {
  id: string;
  name: string;
  center_lat: number;
  center_lng: number;
  radius_km: number;
  target_clients: number;
  is_active: boolean;
  created_at: string;
  /** Nombre de boîtiers effectivement dans le rayon. */
  current_clients: number;
  vip_count: number;
  kwh_30d: number;
}

/** Réponse de `GET /v1/geo/coverage`. */
export interface CoverageResponse {
  precision: number;
  clusters: CoverageCluster[];
  zones: CoverageZone[];
  /** Nombre total de boîtiers géolocalisés correspondant au filtre. */
  total_boxes: number;
  /** Nombre de boîtiers sans position — signale un trou de données. */
  unlocated_boxes: number;
}

/** Métrique de heatmap disponible. */
export type HeatmapMetric = 'boxes' | 'users' | 'kwh' | 'new_installations';

/** Réponse de `GET /v1/geo/heatmap`. */
export interface HeatmapResponse {
  metric: HeatmapMetric;
  points: GeoPoint[];
  /** Valeur maximale, pour normaliser l'échelle de couleur. */
  max_weight: number;
}

/* ------------------------------------------------------------------ */
/* KPI                                                                 */
/* ------------------------------------------------------------------ */

export type KpiPeriod = 'day' | 'week' | 'month' | 'quarter';

export interface KpiSummary {
  period: KpiPeriod;
  total_users: number;
  active_users_30d: number;
  new_users: number;
  /** 0..1. */
  churn_rate: number;
  vip_subscribers: number;
  /** Euros. */
  mrr_vip: number;
  total_boxes: number;
  online_boxes: number;
  total_kwh_30d: number;
  agent_messages_30d: number;
  /** ACK / commandes, 0..1. */
  device_success_rate: number;
  /** Répartition des boîtiers par version de firmware. */
  firmware_distribution?: { version: string; count: number }[];
  /** Répartition des appareils par catégorie. */
  appliance_categories?: { category: string; count: number; kwh_30d: number }[];
  /** Variation vs période précédente, en points de pourcentage. */
  deltas?: Partial<Record<keyof KpiSummary, number>>;
}

export type KpiMetric = 'users' | 'boxes' | 'kwh' | 'agent_messages' | 'device_commands';

export type KpiGranularity = 'day' | 'week' | 'month';

export interface KpiTimeseriesPoint {
  date: string;
  value: number;
}

export interface KpiTimeseries {
  metric: KpiMetric;
  points: KpiTimeseriesPoint[];
}

/** Ligne de rétention d'une cohorte mensuelle. */
export interface CohortRow {
  /** Mois de la cohorte, ex. `2026-09`. */
  cohort: string;
  size: number;
  /** M0..M11, ratio 0..1 ou `null` si le recul n'est pas encore suffisant. */
  retention: (number | null)[];
}

/* ------------------------------------------------------------------ */
/* IoT                                                                 */
/* ------------------------------------------------------------------ */

export interface IotHealth {
  total_boxes: number;
  online_boxes: number;
  offline_boxes: number;
  /** Hors ligne depuis plus de 24 h. */
  stale_boxes: number;
  commands_24h: number;
  ack_rate_24h: number;
  /** Latence d'acquittement en millisecondes. */
  latency_p50_ms: number | null;
  latency_p95_ms: number | null;
  /** Boîtiers les plus en erreur sur 24 h. */
  top_errored_boxes: { box_id: string; uid_hardware: string; failed: number; total: number }[];
  firmware_distribution: { version: string; count: number }[];
}

/* ------------------------------------------------------------------ */
/* Agent IA                                                            */
/* ------------------------------------------------------------------ */

export interface AgentToolMetric {
  tool_name: string;
  calls_count: number;
  /** Part de calls ayant déclenché une demande de confirmation, 0..1. */
  confirmation_rate: number;
  success_rate: number;
  blocked_by_policy: number;
}

export interface AgentAnalytics {
  /** Volume de messages par jour. */
  messages_by_day: KpiTimeseriesPoint[];
  /** Volume d'appels d'outils par jour. */
  tool_calls_by_day: KpiTimeseriesPoint[];
  tools: AgentToolMetric[];
  tool_pending_confirmed: number | null;
  tool_pending_canceled: number | null;
  policy_blocked: number;
  confirmation_events_tracked?: boolean;
  pending_tool_actions_observed?: number;
}

/* ------------------------------------------------------------------ */
/* Audit                                                              */
/* ------------------------------------------------------------------ */

export interface AdminActionLog {
  id: string;
  admin_id: string;
  admin_email: string | null;
  action: string;
  target_type: string | null;
  target_id: string | null;
  details: Record<string, unknown>;
  created_at: string;
}

export interface AgentAuditLog {
  id: string;
  user_id: string | null;
  action: string;
  target_type: string | null;
  target_id: string | null;
  status: string;
  details: Record<string, unknown>;
  created_at: string;
}

/* ------------------------------------------------------------------ */
/* Notes internes & support                                           */
/* ------------------------------------------------------------------ */

export type NoteTargetType = 'user' | 'box' | 'subscription';

export interface AdminNote {
  id: string;
  admin_id: string;
  admin_email: string | null;
  target_type: NoteTargetType;
  target_id: string;
  body: string;
  created_at: string;
  updated_at: string | null;
}

/* ------------------------------------------------------------------ */
/* Exports                                                            */
/* ------------------------------------------------------------------ */

export type ExportStatus = 'pending' | 'ready' | 'failed';

export interface ExportRequest {
  dataset: ExportDataset;
  format: ExportFormat;
  filters?: Record<string, string | number | boolean>;
}

export interface ExportJob {
  export_id: string;
  dataset: ExportDataset;
  format: ExportFormat;
  status: ExportStatus;
  row_count: number | null;
  error_message: string | null;
  created_at: string;
  expires_at: string | null;
  /** URL signée Storage, valable 1 h, présente si `status === 'ready'`. */
  download_url?: string;
}

/* ------------------------------------------------------------------ */
/* Licences                                                           */
/* ------------------------------------------------------------------ */

export interface License {
  id: string;
  subscription_id: string | null;
  user_id: string | null;
  user_email: string | null;
  license_key: string;
  status: 'active' | 'revoked' | 'expired';
  activated_at: string | null;
  expires_at: string | null;
  revoked_at: string | null;
  revoke_reason: string | null;
}
