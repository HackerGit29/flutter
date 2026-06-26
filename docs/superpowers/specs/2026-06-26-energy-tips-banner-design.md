# Banner de conseils d'économie d'énergie — Design

**Date** : 2026-06-26
**Statut** : Design approuvé
**Auteur** : Claude (brainstorming)
**Spec source** : discussion 2026-06-26 (utilisateur)

## Contexte

L'app Aricie affiche déjà un bloc "Conseils d'économie" sur le dashboard
(`lib/screens/home_screen.dart:328-339`), mais le contenu est **statique** :
un seul texte codé en dur, identique pour tous les users, jamais rafraîchi.
Les données de conso (`energy_data`, `realtime_power`), les appliances
utilisateur, et l'agent conversationnel existent déjà, mais ne sont pas
exploités pour générer un conseil ciblé.

L'objectif : un **banner persistant 24h** qui affiche un **conseil
personnalisé** basé sur l'usage réel de l'utilisateur, **rafraîchi chaque
jour**, et qui peut aussi être **poussé en temps réel** par :

1. La détection automatique d'un **pic de conso anormal** (worker MQTT5).
2. L'**agent conversationnel VIP** pendant un chat.

Chaque push temps réel déclenche aussi une **notification locale** via le
service existant (`notification_service.dart`).

## Stack & contraintes

- **Backend** : Supabase (PostgreSQL + Edge Functions Deno + Realtime + Cron).
- **Edge Functions Deno** : 1 nouvelle fonction `tips-generator`.
- **Worker MQTT5** : étendu pour appeler `tips-generator` après chaque upsert.
- **Agent** : nouvel outil `push_tip` dans `agent-orchestrator`.
- **Flutter** : 1 widget + 1 service.
- **Notifications** : `lib/services/notification_service.dart` réutilisé tel quel.
- **Pas de LLM** : règles déterministes TypeScript (pas de coût, déterministes, testables).
- **Cloisonnement** : tout est scopé par `user_id` (RLS + `requesterId` côté edge).

## Décisions architecturales

| # | Décision | Rationale |
|---|---|---|
| 1 | Nouvelle edge function `tips-generator` dédiée (pas d'abus d'`agent-orchestrator`) | Séparation batch (cron) vs conversation (streaming SSE) |
| 2 | Règles déterministes TypeScript (`tips.ts`), pas LLM | Pas de coût, déterministes, testables, ~15 règles couvrent 95% des cas |
| 3 | Deux tables : `daily_energy_tip` (cron, 1/jour) + `energy_tips_realtime` (push live, plusieurs/jour) | Sépare la persistance 24h du flux spontané |
| 4 | `daily_energy_tip` n'est PAS dans Supabase Realtime | Le cron est quotidien ; le pull-to-refresh suffit |
| 5 | `energy_tips_realtime` EST dans Supabase Realtime | Push instantané sans polling |
| 6 | Cooldown 1h par `(user_id, appliance_id)` côté worker | Évite le spam sur un pic persistant |
| 7 | Tool agent `push_tip` gated par subscription (VIP) | Pas de spam push pour les free |
| 8 | Live spike push côté worker **NON** gated (toujours actif) | Sécurité/utilité : un pic anormal doit alerter même les free |
| 9 | Service Flutter réutilise `NotificationService` (canal `innovation_channel`) | Une seule config de canal, pas de duplication |
| 10 | `NotificationService.showNotification` appelé depuis Flutter, pas depuis l'edge | Les notifications locales sont un mécanisme **appareil**, pas serveur |

## Architecture cible

```
[Supabase Cron @ 06:00 UTC]
    │
    ↓ invoke
[Edge Function tips-generator — mode batch]
    ├── pour chaque user actif :
    │   ├── buildTipContext (DB read : energy_data, realtime_power, appliances)
    │   ├── pickTip(ctx) ─→ tips.ts (règles pures)
    │   └── UPSERT daily_energy_tip (user_id, date, title, body, icon, severity, rule_id, context)
    ↓
[Supabase daily_energy_tip]
    └── RLS user_id

[MQTT5 Worker — après chaque upsert realtime_power]
    │
    ↓ POST /evaluate-live
[Edge Function tips-generator — mode live]
    ├── buildTipContext
    ├── evaluateLiveRules(ctx, applianceId) ─→ liveRules.ts
    ├── si match : INSERT energy_tips_realtime
    └── return { pushed: bool }
    ↓
[Supabase energy_tips_realtime]  ← Supabase Realtime broadcast activé
    ├── broadcast ─→ [Flutter TipsRealtimeService]
    │                   ├── widget DailyEnergyTipBanner update (LIVE badge)
    │                   └── NotificationService.showNotification (local push)
    │
    └── RLS user_id

[Flutter chatbot — VIP user]
    │ user demande conseil
    ↓
[Edge Function agent-orchestrator]
    ├── tool push_tip (gated VIP)
    └── INSERT energy_tips_realtime source='agent'
        ↓ Realtime broadcast
        [Flutter TipsRealtimeService] → banner + notification
```

## Schéma DB

### Nouvelle migration `supabase/migrations/20260626000002_energy_tips.sql`

```sql
-- 1. daily_energy_tip : 1 ligne par user par jour, UPSERT sur user_id
CREATE TABLE IF NOT EXISTS daily_energy_tip (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  icon TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info','warning','critical')),
  rule_id TEXT NOT NULL,
  context JSONB NOT NULL DEFAULT '{}',
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_daily_tip_date ON daily_energy_tip(date DESC);

ALTER TABLE daily_energy_tip ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS daily_tip_user_select ON daily_energy_tip;
CREATE POLICY daily_tip_user_select
  ON daily_energy_tip FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

-- Pas d'INSERT/UPDATE policy : seul tips-generator (service_role) écrit.

-- 2. energy_tips_realtime : pushes spontanés (live spike + agent)
CREATE TABLE IF NOT EXISTS energy_tips_realtime (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  icon TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info','warning','critical')),
  source TEXT NOT NULL CHECK (source IN ('live_spike','agent')),
  rule_id TEXT,
  acknowledged BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_realtime_tip_user_created
  ON energy_tips_realtime(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_realtime_tip_unack
  ON energy_tips_realtime(user_id, created_at DESC)
  WHERE acknowledged = false;

ALTER TABLE energy_tips_realtime ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS realtime_tip_user_select ON energy_tips_realtime;
CREATE POLICY realtime_tip_user_select
  ON energy_tips_realtime FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS realtime_tip_user_update ON energy_tips_realtime;
CREATE POLICY realtime_tip_user_update
  ON energy_tips_realtime FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Activation Realtime broadcast
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'energy_tips_realtime'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE energy_tips_realtime;
  END IF;
END $$;
```

## Edge Function `tips-generator`

### `tips.ts` — moteur de règles (pur, testable)

```ts
export type TipSeverity = 'info' | 'warning' | 'critical';
export type TipIcon = 'lightbulb' | 'bolt' | 'water' | 'thermo' | 'warning';

export interface TipContext {
  userId: string;
  todayKwh: number;
  yesterdayKwh: number;
  weekAvgDailyKwh: number;
  topAppliances: Array<{
    id: string;
    name: string;
    kwh: number;
    share: number;
    isOn: boolean;
    liveWatts?: number | null;
    typicalWatts?: number | null;
  }>;
  inactiveAppliancesOn: string[];
  peakHourKwh?: { hour: number; kwh: number };
  subscriptionType: 'free' | 'vip';
}

export interface EnergyTip {
  ruleId: string;
  title: string;
  body: string;
  icon: TipIcon;
  severity: TipSeverity;
  context: Record<string, unknown>;
}

export type TipRule = {
  ruleId: string;
  severity: TipSeverity;
  condition: (ctx: TipContext) => boolean;
  build: (ctx: TipContext) => Omit<EnergyTip, 'ruleId' | 'severity' | 'context'>;
};

const tips: readonly TipRule[] = [
  // 9 règles concrètes + 1 fallback (voir plan d'implémentation pour le code complet)
];

export function pickTip(ctx: TipContext): EnergyTip { /* première règle qui matche, sinon default */ }
```

### `liveRules.ts` — règles live (push instantané)

```ts
export function evaluateLiveRules(ctx: TipContext, applianceId: string): {
  ruleId: string; title: string; body: string; icon: any; severity: any;
} | null {
  // Règle 1 : live > 2× typique ET > 500 W
  // Règle 2 : is_on=true, kwh jour < 0.05, live > 50 W
  // Sinon null
}
```

### `context.ts` — agrégation DB → TipContext

```ts
export async function buildTipContext(supabase: any, userId: string): Promise<TipContext>
```

Lit en parallèle : `energy_data` jour/hier/7j, `appliances` (is_on), `realtime_power`
(live), `subscriptions` (type).

### `index.ts` — entry point (batch + live)

```ts
Deno.serve(async (req) => {
  // POST /evaluate-live → évalue un applianceId et insère si spike
  // Sinon (GET ou cron POST) → batch sur tous les users actifs
});
```

## Worker MQTT5 — Modifications

Dans `workers/mqtt5-worker/index.js`, après l'upsert `realtime_power` (déjà
prévu par le plan RAG), ajouter :

```js
// Cooldown 1h par (user_id, appliance_id) — évite le spam sur pic persistant
const lastLivePushByAppliance = new Map();

async function evaluateLiveTip(userId, applianceId) {
  const key = `${userId}:${applianceId}`;
  const last = lastLivePushByAppliance.get(key);
  if (last && Date.now() - last < 3_600_000) return; // 1h

  try {
    const res = await fetch(`${process.env.TIPS_GENERATOR_URL}/evaluate-live`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ userId, applianceId }),
    });
    if (res.ok) {
      const { pushed } = await res.json();
      if (pushed) {
        lastLivePushByAppliance.set(key, Date.now());
      }
    }
  } catch (err) {
    console.error('[TIPS] evaluate-live error:', err);
  }
}
```

Appel dans la boucle existante d'upsert, après chaque ligne `appliance`
traitée.

## Agent conversationnel — Outil `push_tip`

### Ajout dans `tools.ts`

```ts
{
  type: "function",
  function: {
    name: "push_tip",
    description: "Envoie un conseil d'économie personnalisé en notification push à l'utilisateur...",
    parameters: {
      type: "object",
      properties: {
        title: { type: "string", maxLength: 60 },
        body: { type: "string", maxLength: 200 },
        severity: { type: "string", enum: ["info", "warning"] },
      },
      required: ["title", "body"],
      additionalProperties: false,
    },
  },
}
```

### Handler dans `index.ts` (gated VIP via `filterToolsForSubscription`)

```ts
if (name === "push_tip") {
  await audit({ supabase, requesterId, action: "push_tip", status: "allowed", details: { title: args.title } });
  const { error } = await supabase.from("energy_tips_realtime").insert({
    user_id: requesterId,
    title: args.title,
    body: args.body,
    icon: "lightbulb",
    severity: args.severity ?? "info",
    source: "agent",
  });
  await writeSse(controller, "tool_result", { tool: name, success: !error });
  return { role: "tool", tool_call_id: toolCall.id, content: JSON.stringify({ success: !error }) };
}
```

Le gating `filterToolsForSubscription` existant filtre `push_tip` pour les
free automatiquement (le préfixe n'est pas `get_`).

## Flutter — Ajouts

### `lib/services/tips_realtime_service.dart`

Singleton, `void start()`, `Stream<EnergyTipEvent>`, `dispose()`.

- S'abonne à `energy_tips_realtime:user_id=eq.<id>` (postgres_changes insert).
- Sur chaque event : push sur le stream + **notification locale via
  `NotificationService.showNotification`** (canal `innovation_channel` existant).
- Marque `acknowledged = true` après affichage.
- IDs notification : `9000 + hash(id) % 1000` pour rester dans la plage du
  service (max int32 Android).

### `lib/widgets/daily_energy_tip_banner.dart`

StatefulWidget, consomme :
- `daily_energy_tip` (au boot, via `.maybeSingle()`).
- `TipsRealtimeService.instance.stream` (override live avec badge LIVE).

Affiche :
- Icône + couleur selon `icon` et `severity`.
- Titre + body.
- Badge "LIVE" si `source` ∈ {`live_spike`, `agent`}.
- Bouton X pour dismiss le live override (revient au daily).
- Tap → ouvre `ChatbotScreen` avec message pré-rempli
  (route `Navigator.push(MaterialPageRoute(builder: (_) => const ChatbotScreen(initialMessage: 'Donne-moi plus de détails sur ce conseil')))`).

### Wire dans `home_screen.dart`

Remplacer le bloc `_buildTipCard(...)` (lignes 334-339) par :

```dart
const SizedBox(height: AppSpacing.s4),
const DailyEnergyTipBanner(),
```

### `lib/main.dart` — démarrage

Après `notification_service.init()`, ajouter :

```dart
TipsRealtimeService.instance.start();
```

(Le service vérifie lui-même la présence d'un user connecté.)

## Sécurité (cumulative, defense in depth)

| # | Couche | Mécanisme |
|---|---|---|
| 1 | RLS `daily_energy_tip` | `user_id = auth.uid() OR private.is_admin()` |
| 2 | RLS `energy_tips_realtime` | SELECT et UPDATE scopés user |
| 3 | Edge function service_role | Seule source d'écriture (cron + worker + agent insert) |
| 4 | Tool gating agent | `push_tip` filtré pour free |
| 5 | Cooldown worker | 1h par appliance/user évite spam |
| 6 | Audit | `agent_audit_logs` enregistre chaque `push_tip` agent |
| 7 | Realtime filter | Le channel Flutter filtre côté client ET RLS côté serveur |

## Fichiers modifiés / créés

### Modifiés
- `supabase/functions/agent-orchestrator/tools.ts` (+1 tool `push_tip`, maxLength via description)
- `supabase/functions/agent-orchestrator/index.ts` (handler `push_tip`)
- `workers/mqtt5-worker/index.js` (cooldown map + POST /evaluate-live)
- `lib/screens/home_screen.dart` (remplace bloc statique par `DailyEnergyTipBanner`)
- `lib/main.dart` (`TipsRealtimeService.instance.start()`)

### Créés
- `supabase/migrations/20260626000002_energy_tips.sql`
- `supabase/functions/tips-generator/index.ts`
- `supabase/functions/tips-generator/tips.ts`
- `supabase/functions/tips-generator/liveRules.ts`
- `supabase/functions/tips-generator/context.ts`
- `lib/services/tips_realtime_service.dart`
- `lib/widgets/daily_energy_tip_banner.dart`
- `test/tips_banner_test.dart` (smoke tests mappings + 1 test liveRules mock)

## Tests (Phase 1, smoke)

| Test | Vérifie |
|---|---|
| Dart : `_iconFor` mapping correct | Icônes connues → bon `IconData`, fallback default |
| Dart : `_colorFor` severity → color | info/warning/critical → bonne couleur |
| TS : `pickTip(ctx)` avec chauffe-eau >40% | Retourne règle `water_heater_high_share` |
| TS : `pickTip(ctx)` avec clim live >2× typique | Retourne règle `ac_live_spike` |
| TS : `pickTip(ctx)` contexte vide | Retourne règle `default` |
| TS : `evaluateLiveRules` appareil < seuil | Retourne `null` |
| TS : `evaluateLiveRules` appareil >2× typique | Retourne règle `live_over_2x_typical` |
| `flutter analyze` : 0 erreur | Sur les 3 fichiers Flutter ajoutés |
| `deno check tips-generator/` : 0 erreur de type | |

→ skipped: load tests sur cron (peu de users), penetration tests RLS ; add
when prod load > 1000 users ou avant lancement public.

## Critères d'acceptation

- [ ] Au boot, le banner affiche le `daily_energy_tip` du jour (s'il existe).
- [ ] Si un pic live est détecté par le worker, le banner bascule sur le tip
      live avec badge LIVE + une notification locale `innovation_channel`
      arrive sur l'appareil.
- [ ] L'agent conversationnel VIP peut appeler `push_tip` ; le tip apparaît
      dans le banner et la notification locale est déclenchée.
- [ ] Un user free : `push_tip` absent de `ARICIE_TOOLS` (gating subscription).
- [ ] Un user A ne voit jamais les tips du user B (RLS strict).
- [ ] Tap sur un tip ouvre le chatbot avec message pré-rempli.
- [ ] Cooldown 1h empêche le spam worker sur pic persistant.
- [ ] Tous les smoke tests verts, `flutter analyze` 0 erreur, `deno check` 0 erreur.

## Risques & mitigations

| Risque | Mitigation |
|---|---|
| Cron échoue (downtime Supabase) | Banner affiche le dernier tip dispo + retry manuel au pull-to-refresh |
| Worker spamme en cas de pic persistant | Cooldown 1h par `(user_id, appliance_id)` côté worker |
| L'agent abuse de `push_tip` | Tool gated VIP, audit, max_length 200 caractères sur body |
| Notification locale en double (live + daily au boot) | Live override le daily ; badge LIVE différencie ; idempotent côté affichage |
| Règles déterministes trop rigides | YAGNI Phase 1 ; structure `tips: TipRule[]` permet d'ajouter une règle en 6 lignes |
| Realtime channel pas démarré si user non logué | `start()` vérifie `currentUser != null` et no-op silencieusement |
| Canal `innovation_channel` collision IDs | IDs notification mappés sur `9000 + hash(id) % 1000` |

## Hors scope (Phase 1)

- Rotation des anciens `energy_tips_realtime` (RLS user suffit pour Phase 1).
- Tracking des taps (analytics).
- Édition admin des règles depuis l'UI (hardcodées dans `tips.ts`).
- Localisation multilingue (FR uniquement).
- Tips basés sur le RAG `chat_embeddings` (pas encore branché).
- Push notification avec channel dédié `tips_channel` (séparé de `innovation_channel`).
- Widget `DailyEnergyTipBanner` accessible depuis l'écran Statistiques (Phase 2).
