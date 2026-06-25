# Aricie Agent RAG — Contrôle à distance & conso temps réel

**Date** : 2026-06-25
**Statut** : Design approuvé
**Auteur** : Claude (brainstorming)

## Contexte

Le chatbot Flutter d'Aricie est déjà un agent (Edge Function `agent-orchestrator`
avec Azure OpenAI + tool calling + DeepSeek fallback). Il supporte déjà
l'allumage/extinction d'appareils, la lecture de conso via `energy_data`
(agrégat quotidien), et un RAG vectoriel scopé par utilisateur.

L'objectif de cette itération :

1. **Connaissance conso en temps réel** : l'agent doit pouvoir répondre
   "combien consomme mon climatiseur en ce moment" avec une valeur fraîche
   (kWh instantané + W si télémétrie dispo).
2. **Conso agrégée multi-appareils** : "quelle est ma conso totale cette
   semaine" doit retourner le total + le détail par appareil en un seul tool.
3. **Contrôle à distance fiable** : confirmation obligatoire pour les actions
   à risque (chauffe-eau, climatiseur, four, cuisinière).
4. **Cloisonnement strict** : un user ne voit et ne contrôle QUE ses propres
   appareils, liés à son ID Supabase. Aucune fuite possible, defense in depth.
5. **Tool gating par subscription** : free = lecture seule, premium = contrôle.
6. **RAG sur résumés conso** : l'agent peut répondre conversationnellement
   sur la conso passée sans tool call (embeddings générés par cron).

## Stack & contraintes

- **App** : Flutter (Dart 3, strict), `lib/services/agent_service.dart`
- **Backend** : Supabase (PostgreSQL + Auth + Edge Functions + Realtime)
- **LLM** : Azure OpenAI (principal) + DeepSeek (fallback, `LLM_FALLBACK_ENABLED=true`)
- **Vector store** : pgvector (`chat_embeddings`, dim 1536)
- **Worker** : Node.js MQTT5 (`workers/mqtt5-worker/index.js`) → Flespi
- **Edge Functions** : Deno, `supabase/functions/agent-orchestrator/`

Le fichier `supabase/functions/agent-orchestrator/azure_openai.ts` est
**conservé intact** même s'il n'est plus utilisé directement (la logique LLM
vit maintenant dans `llm.ts`). Il sert de référence et de fallback de fait.

## Architecture cible

```
[MQTT5 Worker Flespi]
    │ telemetry (kWh, W)
    ↓
[Supabase : realtime_power (NEW)]  ← Supabase Realtime broadcast activé
    │
    ├── postgres_changes ─→ [Flutter realtime_power_service.dart]
    │                           └── widget live conso
    │
    └── (via Edge Function quand demandé)
        ↑
[Flutter chatbot_screen]
    │ user prompt
    ↓
[Edge Function agent-orchestrator]
    ├── auth.ts        JWT → authUser.id
    ├── RAG            chat_embeddings (résumés conso + docs user)
    ├── LLM (Azure | DeepSeek) avec tools[]
    ├── tools[]        filtrés par subscription.type
    ├── policy.ts      resolve(user_id) + criticality + rate_limit + sub gate
    ├── actions.ts     enqueue device_commands OU read DB
    └── audit.ts       agent_audit_logs
    │
    ↑ SSE stream (token, tool_pending, tool_result, done, error)
[Flutter chatbot_screen]
    │ modale confirmation si criticality=high
[User : Confirmer/Annuler]
```

## Décisions architecturales

| # | Décision | Rationale |
|---|---|---|
| 1 | Nouvelle table `realtime_power` (UPSERT par appliance) | Conso fraîche, last-write-wins, scope `user_id`, RLS |
| 2 | Activation Supabase Realtime sur `realtime_power` | Live UI sans polling, broadcast per-user |
| 3 | RPC `sum_total_consumption(requester_id, period)` SECURITY DEFINER | Agrégation SQL atomique, pas de fuite possible (le code ne peut pas skip le `WHERE a.user_id = requester_id`) |
| 4 | 2 nouveaux tools ciblés (vs 1 unifié ou extension des existants) | LLM choisit mieux avec des outils explicites et courts |
| 5 | Tool gating par subscription.type (free → lecture seule) | Defense in depth, subscription downgrade reflété à chaque appel |
| 6 | Criticalité hardcodée dans `policy.ts` | Pas de migration, simple, suffit pour le scope actuel |
| 7 | Confirmation modale Flutter pour criticality=high | UX claire, sécurité forte, pas de "oui" accidentel |
| 8 | Cron Edge Function quotidien (00:05 UTC) pour résumés conso | Pas d'extension pg_net, latence J+1 acceptable |
| 9 | `azure_openai.ts` conservé mais non utilisé | Référence + fallback de fait si quelqu'un réimporte |
| 10 | Defense in depth : resolve + RPC + RLS + audit + rate_limit + tool_gate | Aucune couche unique n'est load-bearing |

## Schéma DB

### Nouvelle migration `supabase/migrations/20260626000001_realtime_power_and_rpc.sql`

```sql
-- 1. realtime_power : dernière valeur de puissance par appliance
CREATE TABLE realtime_power (
  appliance_id UUID PRIMARY KEY REFERENCES appliances(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  box_id UUID NOT NULL,
  power_kwh NUMERIC(12,6) NOT NULL,
  instant_power_w NUMERIC(10,2),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE realtime_power ENABLE ROW LEVEL SECURITY;

CREATE POLICY "realtime_power_user_select"
  ON realtime_power FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

CREATE INDEX idx_realtime_power_user ON realtime_power(user_id);
CREATE INDEX idx_realtime_power_updated ON realtime_power(updated_at DESC);

-- Activation Supabase Realtime broadcast
ALTER PUBLICATION supabase_realtime ADD TABLE realtime_power;

-- 2. RPC : conso agrégée + détail par appareil (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION sum_total_consumption(
  requester_id UUID,
  period TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  start_date DATE;
  result JSONB;
BEGIN
  start_date := CASE period
    WHEN 'day'   THEN CURRENT_DATE
    WHEN 'week'  THEN DATE_TRUNC('week', CURRENT_DATE)::DATE
    WHEN 'month' THEN DATE_TRUNC('month', CURRENT_DATE)::DATE
    WHEN 'year'  THEN DATE_TRUNC('year', CURRENT_DATE)::DATE
    ELSE CURRENT_DATE
  END;

  SELECT JSONB_BUILD_OBJECT(
    'period', period,
    'total_kwh', COALESCE(SUM(ed.total_day), 0),
    'by_appliance', COALESCE(JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'appliance_id', ed.appliance_id,
        'name', a.name,
        'kwh', ed.total_day
      ) ORDER BY ed.total_day DESC
    ), '[]'::JSONB)
  ) INTO result
  FROM appliances a
  LEFT JOIN energy_data ed
    ON ed.appliance_id = a.id
    AND ed.date >= start_date
  WHERE a.user_id = requester_id;

  RETURN result;
END;
$$;
```

## Edge Function — Modifications

### `tools.ts` — 2 nouveaux tools

```ts
{
  type: "function",
  function: {
    name: "get_total_consumption",
    description:
      "Récupère la consommation totale de l'utilisateur (tous ses appareils agrégés) pour une période donnée. Retourne total + détail par appareil.",
    parameters: {
      type: "object",
      properties: {
        period: { type: "enum", enum: ["day","week","month","year"] },
      },
      required: ["period"],
      additionalProperties: false,
    },
  },
},
{
  type: "function",
  function: {
    name: "get_live_consumption",
    description:
      "Récupère la consommation instantanée (kWh + W si dispo) pour un appareil ou tous les appareils de l'utilisateur.",
    parameters: {
      type: "object",
      properties: {
        appliance_name: { type: "string" },
      },
      required: [],
      additionalProperties: false,
    },
  },
},
```

### `index.ts` — Tool gating par subscription

Avant `callLLMWithFallback`, lire `subscription.type`. Si `free`, filtrer
`ARICIE_TOOLS` pour ne garder que les tools de lecture (`get_*`). Vérifié à
chaque appel, pas mis en cache (le downgrade prend effet immédiatement).

### `policy.ts` — Criticalité

```ts
export const CRITICAL_APPLIANCES = [
  "chauffe-eau", "chauffe eau", "climatiseur", "clim",
  "four", "cuisinière", "cuisiniere",
];

export function evaluateCriticality(applianceName: string): "high" | "low" {
  const lower = applianceName.toLowerCase();
  return CRITICAL_APPLIANCES.some(c => lower.includes(c)) ? "high" : "low";
}
```

### `handleToolCall` (index.ts) — Confirmation destructive

Pour `turn_on_appliance` / `turn_off_appliance` :

1. `resolveApplianceByName` → résolu
2. `evaluateCriticality(resolved.appliance_name)` → "high"
3. Si high ET que `confirmed === false` (champ du tool_call original) :
   - `writeSse(tool_pending, { ..., requires_confirmation: true, criticality: "high" })`
   - `writeSse(tool_result, { success: false, requires_confirmation: true })`
   - Retourner `{ success: false, requires_confirmation: true }`
   - **AUCUNE** insertion dans `device_commands`
4. Si high ET `confirmed === true` → procéder normalement
5. Si low → procéder normalement (pas de modale)

Le LLM doit donc re-déclencher le tool_call avec `confirmed: true` après
confirmation utilisateur. Le SYSTEM_PROMPT sera mis à jour pour expliquer ce
flux.

### `actions.ts` — Nouvelles fonctions

```ts
export async function getLiveConsumption(params: {
  supabase: any;
  requesterId: string;
  applianceName?: string;
}) {
  let query = params.supabase
    .from("realtime_power")
    .select("appliance_id, power_kwh, instant_power_w, updated_at, appliances!inner(name)")
    .eq("user_id", params.requesterId);

  if (params.applianceName) {
    const resolved = await resolveApplianceByName({
      supabase: params.supabase,
      requesterId: params.requesterId,
      applianceName: params.applianceName,
    });
    if (!resolved) return null;
    query = query.eq("appliance_id", resolved.appliance_id);
  }

  const { data, error } = await query;
  if (error) throw error;
  return data ?? [];
}

export async function getTotalConsumption(params: {
  supabase: any;
  requesterId: string;
  period: "day" | "week" | "month" | "year";
}) {
  const { data, error } = await params.supabase.rpc("sum_total_consumption", {
    requester_id: params.requesterId,
    period: params.period,
  });
  if (error) throw error;
  return data;
}
```

### Nouvelle Edge Function `consumption-summarizer`

- Déclenchée par Supabase Cron (`0 5 * * *`)
- Pour chaque user actif : agrège `energy_data` de la veille, génère un résumé
  textuel, calcule l'embedding via Azure OpenAI, upsert dans `chat_embeddings`
  avec `metadata->>'source_type' = 'consumption_summary'`, `source_id = '<YYYY-MM-DD>'`
- Scope : `owner_id = user_id` (RLS fait le reste)
- Si échec Azure → fallback DeepSeek embeddings si dispo, sinon skip silencieux

### `rag.ts` — Helper résumés conso

```ts
export async function searchConsumptionSummaries(params: {
  supabase: any;
  requesterId: string;
  query: string;
  matchCount?: number;
}) {
  // Identique à searchUserRag mais filtré sur metadata->>'source_type'
  // Note : pgvector match_user_embeddings filtre déjà par owner_id
  // On duplique la logique ici en filtrant côté JS sur le résultat
  const results = await searchUserRag(params);
  return results.filter(r => r.metadata?.source_type === "consumption_summary");
}
```

`searchUserRag` reste appelé comme avant mais le résultat est concaténé avec
`searchConsumptionSummaries` pour le prompt LLM.

## Worker MQTT5 — Modifications

Dans `workers/mqtt5-worker/index.js`, à la réception d'un message telemetry :

```js
// Après parsing du payload
if (payload.kwh_total !== undefined) {
  await supabase.from('realtime_power').upsert({
    appliance_id: appliance.id,
    user_id: appliance.user_id,
    box_id: appliance.box_id,
    power_kwh: payload.kwh_total,
    instant_power_w: payload.power_w ?? null,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'appliance_id' });
}
```

Le worker garde sa logique existante pour `device_status`, `device_commands`,
et l'ACK. On ajoute juste cet upsert.

## Flutter — Ajouts

### `lib/services/realtime_power_service.dart`

Service qui :
- Crée un channel `realtime_power:user_id=eq.${userId}` à l'init
- Expose un `Stream<RealtimePowerReading>` (broadcast)
- Cleanup dans `dispose()`

```dart
class RealtimePowerService {
  StreamSubscription? _sub;
  final _controller = StreamController<RealtimePowerReading>.broadcast();

  Stream<RealtimePowerReading> get stream => _controller.stream;

  void start(String userId) {
    final channel = Supabase.instance.client
        .channel('realtime_power:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'realtime_power',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _controller.add(RealtimePowerReading.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
```

### `lib/widgets/live_consumption_indicator.dart`

Widget qui affiche :
- Total kWh du jour (somme des appliances du user)
- Top 3 appliances consommateurs
- Indicateur "live" qui pulse quand `updated_at` < 30s

### `lib/widgets/confirmation_dialog.dart`

Modale avec :
- Titre : "Confirmer l'action"
- Body : "Voulez-vous vraiment éteindre le chauffe-eau ?"
- Boutons : Annuler / Confirmer
- Renvoie `Future<bool>`

Wire dans `chatbot_screen.dart` : quand un event SSE `tool_result` arrive avec
`requires_confirmation: true`, ouvre la modale. Si confirmé, le client renvoie
un message user "oui, confirme" qui re-déclenche le tool_call avec
`confirmed: true`.

## Sécurité (cumulative, defense in depth)

| # | Couche | Mécanisme |
|---|---|---|
| 1 | Auth | JWT Supabase vérifié dans `auth.ts` → `authUser.id` |
| 2 | Tool gating | `ARICIE_TOOLS` filtré selon `subscription.type` (à chaque appel) |
| 3 | Resolve | `resolveApplianceByName` filtre par `user_id` |
| 4 | RPC | `sum_total_consumption` SECURITY DEFINER + `WHERE a.user_id = requester_id` |
| 5 | RLS | Toutes les tables : `user_id = auth.uid() OR private.is_admin()` |
| 6 | Audit | `agent_audit_logs` pour toute décision (allowed/blocked/pending) |
| 7 | Rate limit | Max 10 commandes/min/boitier (existant, conservé) |
| 8 | Confirmation | Criticalité high → modale obligatoire |

## Découpage en phases

### Phase 1 — MVP (livré en premier)

1. Migration `realtime_power` + RPC `sum_total_consumption` + Supabase Realtime
2. Worker MQTT5 : upsert dans `realtime_power`
3. `actions.ts` : `getLiveConsumption` + `getTotalConsumption`
4. `tools.ts` : 2 nouveaux tools
5. `index.ts` : tool gating subscription
6. `policy.ts` : `CRITICAL_APPLIANCES` + `evaluateCriticality`
7. `handleToolCall` : logique confirmation destructive (audit pending)
8. `rag.ts` : helper `searchConsumptionSummaries`
9. Nouvelle Edge Function `consumption-summarizer` (cron)
10. `lib/services/realtime_power_service.dart`
11. `lib/widgets/live_consumption_indicator.dart`
12. `lib/widgets/confirmation_dialog.dart`
13. Smoke tests (4 tests minimum)

### Phase 2 — UX (après validation Phase 1)

- Wire la modale dans `chatbot_screen` (câblage complet du round-trip)
- Animation live dans le dashboard
- Optimistic UI post-commande
- Tests d'intégration Flutter

## Tests (Phase 1, smoke)

| Test | Vérifie |
|---|---|
| User A demande conso, reçoit SES chiffres | Scope user_id |
| User B ne peut pas voir A | RLS + RPC SECURITY DEFINER |
| "allume la lampe" avec 2 lampes | `resolveApplianceByName` retourne `null` |
| "éteins le chauffe-eau" | `tool_result.requires_confirmation=true`, **aucune** commande |
| "éteins la lampe du salon" | `tool_result.success=true`, commande insérée |
| User free demande turn_on_appliance | Tool absent de `ARICIE_TOOLS`, LLM ne peut pas l'appeler |

→ skipped: load tests, chaos tests, penetration tests; add when prod load
> 100 req/min or before public launch.

## Fichiers modifiés / créés

### Modifiés
- `supabase/functions/agent-orchestrator/index.ts` (tool gating, confirmation)
- `supabase/functions/agent-orchestrator/tools.ts` (2 tools)
- `supabase/functions/agent-orchestrator/policy.ts` (criticality)
- `supabase/functions/agent-orchestrator/actions.ts` (getLive, getTotal)
- `supabase/functions/agent-orchestrator/rag.ts` (helper summaries)
- `workers/mqtt5-worker/index.js` (upsert realtime_power)
- `lib/screens/chatbot/chatbot_screen.dart` (wire modale)

### Créés
- `supabase/migrations/20260626000001_realtime_power_and_rpc.sql`
- `supabase/functions/consumption-summarizer/index.ts`
- `supabase/functions/consumption-summarizer/deno.json`
- `lib/services/realtime_power_service.dart`
- `lib/widgets/live_consumption_indicator.dart`
- `lib/widgets/confirmation_dialog.dart`
- `test/agent_rag_smoke_test.dart` (smoke tests)

### Conservés intacts
- `supabase/functions/agent-orchestrator/azure_openai.ts` (référence + fallback de fait)

## Risques & mitigations

| Risque | Mitigation |
|---|---|
| LLM hallucine un nom d'appareil | `resolveApplianceByName` → `null` si pas de match unique |
| User force accès appareil d'un autre | RLS + scope + RPC SECURITY DEFINER + audit |
| Azure quota exceeded | DeepSeek fallback déjà actif |
| realtime_power dérive | UPSERT à chaque télémétrie (last-write-wins) |
| Résumé conso obsolète | Cron quotidien 00:05 UTC |
| Subscription downgrade | Tool gating vérifié à chaque appel, pas mis en cache |
| Modale Flutter non confirmée à temps | Tool_call reste `pending` côté audit, le user peut renvoyer "oui" plus tard |
| Worker MQTT5 perd un message | Flespi QoS 1 + upsert idempotent |

## Hors scope

- Migration vers TimescaleDB pour `realtime_power` (YAGNI, volume actuel faible)
- Tool `schedule_action` (programmer allumage/extinction à heure fixe)
- Multi-tenant / admin delegation (déjà géré par `private.is_admin()`)
- Notifications push après confirmation (Phase 2+)
- Voice command pour actions (Phase 2+)

## Critères d'acceptation Phase 1

- [ ] Un user peut demander "quelle est ma conso en ce moment" et recevoir les kWh live
- [ ] Un user peut demander "ma conso totale cette semaine" et recevoir total + détail
- [ ] Un user peut dire "éteins le chauffe-eau" et reçoit une demande de confirmation modale
- [ ] Un user free qui demande "allume la lampe" reçoit un refus explicite (LLM explique)
- [ ] Un user A ne peut voir AUCUNE donnée du user B (smoke test passe)
- [ ] Tous les événements agent sont audités dans `agent_audit_logs`
- [ ] Le cron quotidien génère des embeddings `consumption_summary` pour les users actifs
- [ ] `flutter analyze` : 0 erreur
- [ ] Smoke tests : tous verts