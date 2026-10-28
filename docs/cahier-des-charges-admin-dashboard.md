# Cahier des charges — Dashboard Admin web (Aricie Backoffice)

> **Statut** : Implémentation en cours — Octobre 2026
> **Cible** : Application web statique `admin/` dans le dépôt Flutter, réservée à l'équipe interne aricie
> **Backend** : Supabase (PostgreSQL, RLS, Edge Functions, Realtime)

---

## 1. Pourquoi un backoffice admin ?

L'app mobile embarque aujourd'hui un `AdminDashboardScreen` limité : lecture brute des tables,
quelques actions (création boîtier, suspension utilisateur, override de propriété). Ce n'est pas
un outil de pilotage. Un backoffice web séparé est nécessaire pour :

| Besoin business | Limite actuelle | Apport du backoffice |
|---|---|---|
| **Pilotage commercial** | Aucun agrégat : ni MRR, ni churn, ni cohortes | KPI temps réel : abonnements VIP, churn, rétention, LTV |
| **Géomarketing** | `boxes.location` est un texte libre ("Salon") — aucune géolocalisation | Carte de couverture nationale, heatmap d'installation, détection de zones saturées/creuses |
| **Support client** | Logs dispersés, pas de vue 360° client | Fiche client unifiée : boîtiers + conso + commandes MQTT + logs sync + audit agent |
| **Santé du parc IoT** | Onglet `device_commands` brute, pas d'alerte | Monitoring : taux ACK, latence MQTT, boîtiers inactifs, firmware à jour |
| **Conformité / audit** | `admin_actions` et `agent_audit_logs` jamais consultés | Journal d'audit consultable, exportable, filtrable (RGPD, SOC2-ready) |
| **Sécurité** | Admin = rôle dans la table `users`, mêmes credentials que les clients | Comptes admin dédiés, 2FA, RBAC fin (viewer/operator/super-admin) |
| **Décision produit** | Rien sur l'usage réel des appliances et de l'agent IA | Funnel agent (questions → tool calls → confirmations), usage relais par catégorie |

**Principe directeur** : l'app mobile reste l'outil *client* ; le backoffice est l'outil *entreprise*.
Aucune fonctionnalité décisionnelle n'est ajoutée au Flutter — l'inverse est aussi vrai : le
backoffice ne fait jamais de control device direct (cela reste le métier de l'app + MQTT).

---

## 2. Périmètre

### 2.1 Features admin existantes dans l'app mobile (à migrer / conserver)

Ces fonctionnalités existent dans `lib/screens/admin/` et sont à **reproduire améliorées** dans le
backoffice. La version mobile peut être **gelée** (lecture seule) une fois le backoffice en prod.

| # | Feature mobile (existant) | Fichier | Décision backoffice |
|---|---|---|---|
| A1 | Liste des boîtiers + détail | `admin_dashboard_screen.dart`, `admin_box_detail_screen.dart` | Migre — filtres, recherche, pagination serveur |
| A2 | Liste des utilisateurs + détail | `admin_user_detail_screen.dart` | Migre — fiche 360° enrichie |
| A3 | Liste des abonnements + détail | `admin_subscription_detail_screen.dart` | Migre — + métriques churn/LTV |
| A4 | Logs de sync | `admin_dashboard_screen.dart` (onglet) | Migre — agrégats + alertes |
| A5 | Journal admin_actions | idem | Migre — filtres par admin/cible/action |
| A6 | File device_commands | idem | Migre — devient onglet Monitoring IoT |
| A7 | Création boîtier (+ 3 appliances) | FAB + dialog | Migre — avec assignation géo |
| A8 | Suspendre / activer un user, changer son rôle | `supabase_admin_datasource.dart` | Migre — + 2FA step-up |
| A9 | Override de propriété boîtier | idem | Migre — avec confirmation renforcée + audit |
| A10 | Reset boîtier / force sync | idem | Migre |
| A11 | Mise à jour d'un abonnement | idem | Migre — opérateur billing |

### 2.2 Nouvelles features backoffice (hors mobile)

| # | Feature | Priorité | Section |
|---|---|---|---|
| B1 | **Carte de couverture clients** (installations sur carte, clusters, filtre par zone) | **P0** | §6.2 |
| B2 | **Heatmap énergie** (consommation agrégée par géo / par appareil) | **P0** | §6.3 |
| B3 | **KPI décisionnels** (MRR VIP, churn, cohortes, LTV, funnels) | **P0** | §6.1 |
| B4 | Fiche client 360° (vue unifiée) | **P0** | §6.4 |
| B5 | Monitoring santé parc IoT (taux ACK, latence, offline) | **P1** | §6.5 |
| B6 | Analytics agent IA (usage tools, confirmations, blocages policy) | **P1** | §6.6 |
| B7 | Export & rapports (CSV/Excel, rapports hebdo auto par email) | **P1** | §6.7 |
| B8 | Gestion support : notes internes, tickets liés à un client | **P2** | §6.8 |
| B9 | Gestion licences (activation/révocation, batch provisioning) | **P2** | §6.9 |
| B10 | RBAC fin + journal d'audit consultable | **P0** (sécurité) | §7 |

---

## 3. Architecture cible

```
┌────────────────────────────────────────────────────────┐
│  admin/ — Aricie Backoffice (dans le dépôt Flutter)    │
│  React 19 + TypeScript · Vite · MUI · TanStack Query  │
│  Site statique prévu pour Cloudflare Pages             │
└──────────────┬─────────────────────────────────────────┘
               │ HTTPS (JWT Supabase + claim admin)
               ▼
┌────────────────────────────────────────────────────────┐
│  Supabase                                              │
│  ├─ Postgres + RLS (private.is_admin())                │
│  ├─ Edge Function  admin-api  (routeur /v1/*)          │
│  │    → agrégats, KPI, géo, exports (service role      │
│  │      uniquement après vérif du rôle admin)          │
│  ├─ Realtime (device_commands, energy_data)            │
│  └─ Storage (exports CSV)                              │
└────────────────────────────────────────────────────────┘
```

**Choix assumés** :
- **Une seule Edge Function `admin-api`** en routeur (`/v1/kpi`, `/v1/boxes`, …) plutôt qu'une
  function par endpoint : partage du middleware d'auth/RBAC, déploiement atomique, coût cold-start
  unique. Le client Supabase du navigateur est réservé à l'authentification ; les données métier passent par l'API admin.
- **Carte** : MapLibre GL JS + OpenStreetMap sont prévus pour le rendu cartographique ; l'écran actuel interroge l'API, la visualisation cartographique reste à finaliser.
- **Pas de stockage géo côté client** : les positions sont centralisées en base (voir §5.1).

---

## 4. Modèle de données — ajouts nécessaires

Le schéma actuel **ne contient aucune donnée de géolocalisation** (vérifié : aucune colonne
lat/lng n'existe). C'est le point de départ obligatoire pour la carte et la heatmap.

### 4.1 Migration `20261026000001_admin_geo.sql`

```sql
-- Géolocalisation des boîtiers (installation)
ALTER TABLE boxes
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS geo_precision TEXT CHECK (geo_precision IN ('exact','approx','city','manual')),
  ADD COLUMN IF NOT EXISTS installed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_boxes_geo ON boxes (latitude, longitude)
  WHERE latitude IS NOT NULL;

-- Zones de couverture définies par l'entreprise (rayons, villes ciblées)
CREATE TABLE IF NOT EXISTS coverage_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,                       -- 'Lyon Est', 'Rennes agglo'
  center_lat DOUBLE PRECISION NOT NULL,
  center_lng DOUBLE PRECISION NOT NULL,
  radius_km DOUBLE PRECISION NOT NULL,
  target_clients INT DEFAULT 0,             -- objectif commercial
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE coverage_zones ENABLE ROW LEVEL SECURITY;
CREATE POLICY coverage_zones_admin ON coverage_zones
  FOR ALL TO authenticated USING (private.is_admin());

-- Événements produit (funnels, rétention, cohortes)
CREATE TABLE IF NOT EXISTS analytics_events (
  id BIGINT GENERATED ALWAYS AS PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  box_id UUID REFERENCES boxes(id) ON DELETE SET NULL,
  event TEXT NOT NULL,          -- 'app_open','chat_message','tool_confirmed','tip_shown'…
  properties JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user ON analytics_events(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_analytics_events_type ON analytics_events(event, created_at DESC);
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
-- écriture : service role uniquement ; lecture : admin
CREATE POLICY analytics_events_admin ON analytics_events
  FOR SELECT TO authenticated USING (private.is_admin());

-- Notes internes support (jamais visibles côté client)
CREATE TABLE IF NOT EXISTS admin_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES users(id),
  target_type TEXT NOT NULL CHECK (target_type IN ('user','box','subscription')),
  target_id UUID NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE admin_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_notes_admin ON admin_notes
  FOR ALL TO authenticated USING (private.is_admin());
```

### 4.2 RBAC fin

```sql
-- 20261026000002_admin_rbac.sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_level TEXT
  CHECK (admin_level IN ('viewer','operator','super_admin'));

-- Vue agrégée couverture (utilisée par l'API /v1/geo/coverage)
CREATE OR REPLACE VIEW admin_coverage_view AS
SELECT
  b.latitude, b.longitude,
  b.status, b.firmware_version,
  u.id AS user_id, s.type AS sub_type,
  COUNT(*) OVER () AS total_boxes
FROM boxes b
JOIN users u ON u.id = b.user_id
LEFT JOIN subscriptions s ON s.user_id = u.id AND s.is_active
WHERE b.latitude IS NOT NULL;
```

---

## 5. Contrats backend (API `admin-api`)

### 5.1 Conventions

- **Base URL** : `https://<project>.supabase.co/functions/v1/admin-api` (le frontend Vite la construit à partir de `VITE_SUPABASE_URL`).
- **Auth** : header `Authorization: Bearer <access_token Supabase>` + header `apikey`.
- **Garde-fou** : chaque route protégée vérifie le JWT et `users.role = 'admin'`, puis applique `admin_level` pour les écritures via `auth.getUser()` côté function — **jamais** un champ envoyé par le client. Le navigateur conserve uniquement la clé anon ; la clé `service_role` reste côté Edge Function.
- **Formats** : JSON, dates ISO-8601 UTC, `snake_case` aligné sur la BDD.
- **Pagination** : `?page=1&page_size=50` → réponse enveloppée `{ data, page, page_size, total }`.
- **Erreurs** : `{ error: { code, message } }` avec codes `unauthorized`, `forbidden`,
  `not_found`, `validation_error`, `rate_limited`.
- **Rate limit** : 120 req/min/IP (déjà le pattern `core/security/` côté mobile).

### 5.2 Types TypeScript (contrat partagé)

```typescript
// shared/admin-types.ts

export type AdminLevel = 'viewer' | 'operator' | 'super_admin';
export type BoxStatus = 'active' | 'inactive' | 'blocked';
export type SubType = 'free' | 'vip';
export type DeviceCommandStatus = 'pending' | 'sent' | 'acknowledged' | 'failed' | 'rejected';

export interface AdminUser {
  id: string;
  email: string;
  role: 'admin' | 'user' | 'vip';
  admin_level: AdminLevel | null;
  status: 'active' | 'suspended';
  created_at: string;
  subscription: Subscription | null;
  box_count: number;
  last_activity_at: string | null;   // max(sync_logs, analytics_events)
}

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
  geo_precision: 'exact' | 'approx' | 'city' | 'manual' | null;
  installed_at: string | null;
  created_at: string;
  appliance_count?: number;
  online?: boolean;                  // last_sync < 5 min
}

export interface GeoPoint {
  lat: number;
  lng: number;
  weight?: number;                   // pour heatmap (kwh, nb clients…)
  meta?: Record<string, unknown>;
}

export interface CoverageCluster {
  geohash: string;                   // precision 4~6
  lat: number; lng: number;
  box_count: number;
  user_count: number;
  vip_count: number;
  zone_id: string | null;            // coverage_zones couvrant le point
}

export interface KpiSummary {
  period: 'day' | 'week' | 'month' | 'quarter';
  total_users: number;
  active_users_30d: number;
  new_users: number;
  churn_rate: number;                // 0..1
  vip_subscribers: number;
  mrr_vip: number;                   // € — déduit du pricing en config
  total_boxes: number;
  online_boxes: number;
  total_kwh_30d: number;
  agent_messages_30d: number;
  device_success_rate: number;       // ACK / commands
}

export interface CohortRow {
  cohort: string;                    // '2026-09'
  size: number;
  retention: (number | null)[];      // M0..M11, ratio 0..1
}

export interface UserTimelineItem {
  at: string;
  kind: 'auth' | 'sync' | 'device_command' | 'agent_audit' | 'admin_action' | 'event';
  label: string;
  details?: Record<string, unknown>;
}

export interface Paginated<T> {
  data: T[];
  page: number;
  page_size: number;
  total: number;
}
```

### 5.3 Routes API

#### 5.3.1 KPI & pilotage — `GET /v1/kpi/summary`

| Param | Type | Description |
|---|---|---|
| `period` | `day\|week\|month\|quarter` | défaut `month` |

Réponse : `KpiSummary` (§5.2). Implémentation : agrégats SQL pré-calculés par cron
(materialized view `mv_kpi_daily`, refresh toutes les heures).

#### 5.3.2 Séries temporelles — `GET /v1/kpi/timeseries`

| Param | Type |
|---|---|
| `metric` | `users\|boxes\|kwh\|agent_messages\|device_commands` |
| `from`, `to` | ISO date |
| `granularity` | `day\|week\|month` |

Réponse : `{ metric, points: { date: string; value: number }[] }`

#### 5.3.3 Cohortes & rétention — `GET /v1/kpi/cohorts`

Réponse : `CohortRow[]` — cohorte mensuelle par date d'inscription, rétention mesurée via
`analytics_events.app_open`.

#### 5.3.4 Géo / carte de couverture — `GET /v1/geo/coverage`

| Param | Type | Description |
|---|---|---|
| `bbox` | `minLng,minLat,maxLng,maxLat` | bornes de la vue carte |
| `precision` | geohash 3–6 | granularité des clusters (auto selon zoom) |
| `zone_id` | UUID optionuel | filtrer sur une coverage_zone |

Réponse :
```json
{
  "precision": 5,
  "clusters": [
    { "geohash": "u09tv", "lat": 45.757, "lng": 4.832,
      "box_count": 42, "user_count": 31, "vip_count": 9, "zone_id": null }
  ],
  "zones": [ { "id": "...", "name": "Lyon Est", "center_lat": 45.76, "center_lng": 4.85,
               "radius_km": 15, "target_clients": 50, "current_clients": 42 } ]
}
```

#### 5.3.5 Heatmap — `GET /v1/geo/heatmap`

| Param | Type |
|---|---|
| `metric` | `boxes\|users\|kwh\|new_installations` |
| `from`, `to` | ISO date (ignoré si metric=boxes/users) |

Réponse : `{ metric, points: GeoPoint[] }` — chaque point = boîtier ou cluster avec `weight`.

#### 5.3.6 Zones de couverture (CRUD, operator+) — `/v1/geo/zones`

- `GET /v1/geo/zones` → `CoverageZone[]`
- `POST /v1/geo/zones` (body : name, center_lat, center_lng, radius_km, target_clients)
- `PATCH /v1/geo/zones/:id`, `DELETE /v1/geo/zones/:id`

#### 5.3.7 Utilisateurs — `/v1/users`

| Route | Niveau | Description |
|---|---|---|
| `GET /v1/users` | viewer | `Paginated<AdminUser>` — filtres `?status=&role=&sub=&q=&sort=` |
| `GET /v1/users/:id` | viewer | Fiche 360° : `AdminUser` + `boxes[]`, `subscription`, `totals` (kwh 30/365j), `device_success_rate` |
| `GET /v1/users/:id/timeline` | viewer | `UserTimelineItem[]` fusionné (max 500) |
| `PATCH /v1/users/:id/status` | operator | `{ status: 'active'\|'suspended' }` → audité |
| `PATCH /v1/users/:id/role` | super_admin | `{ role, admin_level }` → audité |
| `GET /v1/users/:id/export` | operator | archive JSON RGPD (dump complet) |

#### 5.3.8 Boîtiers — `/v1/boxes`

| Route | Niveau | Description |
|---|---|---|
| `GET /v1/boxes` | viewer | `Paginated<AdminBox>` — filtres `?status=&user_id=&q=&firmware=` |
| `GET /v1/boxes/:id` | viewer | détail + appliances + dernières commands + derniers sync_logs |
| `POST /v1/boxes` | operator | création (`uid_hardware,name,location,user_id?,latitude?,longitude?`) |
| `PATCH /v1/boxes/:id` | operator | update (nom, location, géo, status) |
| `POST /v1/boxes/:id/assign` | operator | `{ user_id }` — transfère boîtier + appliances, audité |
| `POST /v1/boxes/:id/reset` | super_admin | reset uid/status/public_key, audité |
| `POST /v1/boxes/:id/force-sync` | operator | rétro-compatible `forceSync` mobile |
| `POST /v1/boxes/geo-bulk` | operator | batch géolocalisation `{ items: [{box_id,lat,lng,precision}] }` |

#### 5.3.9 Abonnements & licences — `/v1/subscriptions`, `/v1/licenses`

| Route | Niveau | Description |
|---|---|---|
| `GET /v1/subscriptions` | viewer | filtres `type,is_active,expiring_within_days` |
| `PATCH /v1/subscriptions/:id` | operator | `{ type?, end_date?, is_active?, auto_renew? }` |
| `GET /v1/licenses` | viewer | liste avec statut activation |
| `POST /v1/licenses/activate` | operator | `{ subscription_id, expiration_date? }` |
| `POST /v1/licenses/revoke` | super_admin | `{ license_id, reason }` |

#### 5.3.10 Monitoring IoT — `/v1/iot`

| Route | Description |
|---|---|
| `GET /v1/iot/health` | KPIs parc : online/offline, taux ACK 24h, latence p50/p95, top errored boxes |
| `GET /v1/iot/commands` | `Paginated<DeviceCommand>` — filtres status/box/user/date |
| `POST /v1/iot/commands/:id/retry` | operator — resoumet une commande `failed` ou `timeout`, avec déduplication des relances actives |
| `GET /v1/iot/sync-logs` | filtres box_id/user_id/status/date |

#### 5.3.11 Agent IA — `/v1/agent`

| Route | Description |
|---|---|
| `GET /v1/agent/analytics` | volume messages/jour, appels des tools de contrôle, taux de succès et blocages policy ; le backend indique explicitement si les confirmations sont suivies (actuellement non) |
| `GET /v1/agent/audit` | `Paginated<agent_audit_logs>` — filtres action/status/user |

#### 5.3.12 Exports — `/v1/exports`

| Route | Description |
|---|---|
| `POST /v1/exports` | `{ dataset: 'users'\|'boxes'\|'energy'\|'commands', filters, format: 'csv' }` → `{ export_id, status: 'ready', row_count, download_url, expires_in_seconds }` (génération immédiate, limite 20 000 lignes) |
| `GET /v1/exports/:id` | Renvoie une URL signée pour l'export du compte admin connecté, valable une heure ; stockage dans le bucket privé `admin-exports`. XLSX et traitement asynchrone ne sont pas encore implémentés. |

#### 5.3.13 Admin & audit — `/v1/admin`

| Route | Niveau | Description |
|---|---|---|
| `GET /v1/admin/actions` | viewer | journal `admin_actions` filtré |
| `GET /v1/admin/audit-logs` | super_admin | fusion `admin_actions` + `agent_audit_logs` |
| `GET/POST /v1/admin/notes` | operator | notes internes support (§4.1 `admin_notes`) |

---

## 6. Features backoffice — détail

### 6.1 KPI décisionnels (P0)

Écran d'accueil « Overview » :
- **Commerciaux** : total clients, nouveaux 30j, VIP, MRR VIP, churn mensuel, LTV estimé
  (LTV = durée moyenne VIP × prix mensuel), cohortes de rétention (heatmap rétention classique)
- **IoT** : boîtiers installés / online / bloqués, taux de succès des commandes, firmware déployés
  (répartition par version)
- **Énergie** : kWh totaux 30j, consommation moyenne par foyer, top appliances (chauffe-eaudominera)
- **Agent IA** : messages/jour, taux d'outils exécutés, taux de confirmations refusées
- Objectifs vs réalisé par `coverage_zone`

### 6.2 Carte de couverture clients (P0) — le différenciateur

- **Rendu** : MapLibre GL, fond OSM, France métropolitaine par défaut
- **Clusters** : les boîtiers sont agrégés par geohash (precision adaptative au zoom : 4 en vue
  nationale → 6 en vue rue). Affichage en cercles proportionnels (rayon ∝ √box_count), couleur
  selon ratio VIP (bleu pastel `#79CFF4` → accent aricie)
- **Zones** : polygones circulaires `coverage_zones` affichées en overlay avec objectif vs réalisé
  (barre de progression dans le popup)
- **Filtres** : période d'installation, statut, type d'abonnement, firmware
- **Clic cluster** → panneau latéral listant les clients de la zone (anonymisés pour viewer,
  complets pour operator) + bouton « créer une zone cible ici »
- **GeoJSON export** pour les decks commerciaux

### 6.3 Heatmap (P0)

Deux heatmap indépendantes superposables :
1. **Heatmap densité installée** — points = boîtiers, poids = 1 (ou nb appliances)
2. **Heatmap énergie** — poids = somme `energy_data.kwh` sur la période (from/to), révèle les
   zones de forte consommation → cible commerciale privilégiée pour les offres VIP/tips

Rendu deck.gl `HeatmapLayer` (échelle pastel cohérente avec le design system), contrôles de
période et de métrique dans la barre d'outils.

### 6.4 Fiche client 360° (P0)

Une page par utilisateur :
- En-tête : email, rôle, statut, abonnement, ancienneté, dernier accès
- Timeline fusionnée (`/v1/users/:id/timeline`) : inscriptions, syncs, commandes device, actions
  agent, actions admin
- Onglet Énergie : courbe `energy_data` par appliance, comparaison au foyer moyen
- Onglet IoT : boîtiers + statut online + dernier ACK
- Notes internes (support) + boutons d'action (suspendre, transférer boîtier, upgrader VIP)

### 6.5 Monitoring santé IoT (P1)

- Carte des boîtiers **offline > 24 h** (alerte visuelle rouge)
- Taux ACK 24 h / 7 j par boîtier, latence p95 (calculée depuis `device_commands.created_at` →
  `acknowledged_at`)
- Liste des commandes `failed` avec retry
- Distribution firmware + diffusion ciblée (outil d'upgrade à venir, hors périmètre v1)

### 6.6 Analytics agent IA (P1)

- Volume de messages et d'appels d'outils par jour
- Top tools de contrôle (`turn_on_appliance`, `turn_off_appliance`), taux d'appels réussis et blocages Policy Engine. Les événements de confirmation/annulation ne sont pas encore suivis par le backend.
- Blocages Policy Engine (depuis `agent_audit_logs.status = 'blocked'`) → détecte les tentatives
  hors périmètre (signal produit précieux)

### 6.7 Exports & rapports (P1)

- Export manuel CSV de users, boxes, energy ou commands (génération immédiate, max. 20 000 lignes, URL Storage signée valable une heure). XLSX et jobs asynchrones restent à développer.
- Rapport hebdo automatique (email) : KPI + zones chaudes + alertes parc — Cron Supabase
  `admin-weekly-report`

### 6.8 Notes internes support (P2)

- Notes liées à user/box/subscription, visibles uniquement backoffice (`admin_notes`)
- Historique horodaté + auteur

### 6.9 Gestion licences & provisioning batch (P2)

- Création de lots de boîtiers (upload CSV `uid_hardware;user_email;lat;lng`)
- Activation/révocation de licences avec motif obligatoire

---

## 7. Sécurité & conformité

| Règle | Implémentation |
|---|---|
| Comptes admin = `users.role='admin'` **et** `admin_level` renseigné | garde middleware `admin-api` |
| 2FA obligatoire pour operator/super_admin | Supabase Auth + TOTP (ou IAP Cloudflare en surcouche) |
| Toute écriture audité | trigger SQL sur les tables mutables → `admin_actions` |
| Service role uniquement dans Edge Functions | jamais au front |
| RGPD : droit à l'effacement | script `admin-gdpr-erase` : anonymise user + purge analytics_events/chat_embeddings/sync_logs (conformité, audit conservé) |
| Rate limit + IP allowlist | Edge Function middleware ; allowlist IP bureau si VPN dispo |
| Pas de control device direct depuis le backoffice | aucun accès MQTT ; les actions passent par `device_commands` comme l'app |

---

## 8. Exigences non fonctionnelles

- **Performance** : TTI < 2,5 s ; KPI chargés < 500 ms (vues matérialisées) ; carte < 1,5 s
  (clusters pré-agrégés côté SQL, pas de payload brut > 5 Mo)
- **Pagination systématique** sur toute liste
- **Realtime** : abonnement Supabase Realtime sur `device_commands` et `energy_data` pour les
  compteurs live (badge « en direct »)
- **Design** : reprendre le design system aricie (seed `#4A6572`, DM Sans, Material 3-like,
  accents `rgb(121,207,244)`), dark mode inclus
- **i18n** : interface FR d'abord, structure i18n prête
- **Accessibilité** : contraste AA, navigation clavier sur les tableaux

---

## 9. Roadmap

| Phase | Contenu | Durée est. |
|---|---|---|
| **P0 — Fondations** | Migration géo + RBAC, Edge Function `admin-api` (KPI, users, boxes), login + Overview + Users + Boxes | 3 sem. |
| **P0 — Carto** | Carte couverture clusters + heatmap densité/énergie + CRUD zones | 2 sem. |
| **P1 — Ops** | Monitoring IoT, analytics agent, exports, fiche 360° complète | 2 sem. |
| **P1 — Rapports** | Rapport hebdo cron + Realtime compteurs | 1 sem. |
| **P2 — Support & scale** | Notes internes, provisioning batch, GDPR erase, RBAC viewer pour le commercial | 2 sem. |

**Critère de sortie P0** : l'équipe peut répondre sur une page — « combien de clients à Lyon ?
combien de kWh ? lesquels sont VIP ? où installer le prochain boîtier ? » — sans SQL.

---

## 10. Décisions à valider avec le client

1. **App web** : décision prise — frontend statique React + TypeScript + Vite dans `admin/`, à déployer sur Cloudflare Pages. Le navigateur appelle l'Edge Function `admin-api` avec la clé anon et un JWT Supabase ; aucune clé `service_role` ne doit être incluse dans le bundle. Le branchement complet de l'authentification et la configuration du projet Pages restent des prérequis à la mise en production.
2. **Pricing VIP** : valeur du MRR (config pour le calcul MRR/LTV) ? je n'ai pas encore mais go ahead  je te suis via le contexte de l'app
3. **Géolocalisation** : saisie manuelle à l'installation (installateur saisit lat/lng), ou
   dérivation depuis une adresse, ou géoloc approximative (ville) pour la confidentialité ?
   → impacte `geo_precision` pas de geo manuelle on récupère via la session user approximative ou rel depuis l'app mobile
4. **Anonymisation** : les viewers (commerciaux) voient-ils les emails clients ou des alias ? non masquing email partiel comme le DDM de MSSQL
5. **Données historiques** : backfill géo des boîtiers déjà installés (combien au 26/10/2026) ? kdal il faut récupérer depuis la connexion IP approximative ou dans les cookies les IP users provided par leur FAI ou un truc du genre pour fill la geo
