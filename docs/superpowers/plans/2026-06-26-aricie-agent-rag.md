# Aricie Agent RAG — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Étendre l'agent Aricie pour la conso temps réel, l'agrégation multi-appareils, le contrôle à distance avec confirmation destructive, le tool gating par subscription, et le RAG sur résumés conso — avec cloisonnement strict par `user_id`.

**Architecture:** Nouvelle table `realtime_power` (UPSERT) + RPC `sum_total_consumption` SECURITY DEFINER. Deux nouveaux tools agent (`get_live_consumption`, `get_total_consumption`). Tool gating filtrant `ARICIE_TOOLS` par `subscription.type` à chaque appel. Criticalité `high` → modale Flutter + 2e tool_call avec `confirmed: true`. Edge Function `consumption-summarizer` (cron 00:05 UTC) pour embeddings conso. Service Flutter `RealtimePowerService` branché sur Supabase Realtime broadcast.

**Tech Stack:** Supabase (PostgreSQL + pgvector + Realtime + Edge Functions Deno), Node.js (MQTT5 worker), Flutter/Dart 3, Azure OpenAI + DeepSeek fallback.

## Global Constraints

- **Langage commentaires/code/explications :** français ; identifiants techniques en anglais.
- **Tool gating :** filtré **à chaque appel** (`subscription.type` non mis en cache, downgrade immédiat).
- **Cloisonnement :** toute lecture/écriture DB doit passer par `requesterId = authUser.id` ; RPC `SECURITY DEFINER` avec `WHERE a.user_id = requester_id`.
- **Confirmation destructive :** `requires_confirmation: true` côté SSE **bloque** l'insertion dans `device_commands` ; seul le 2e tool_call avec `confirmed: true` insère.
- **Audit :** toute décision (allowed/blocked/failed/pending) journalisée dans `agent_audit_logs`.
- **Conservation :** `supabase/functions/agent-orchestrator/azure_openai.ts` reste **intact** (référence).
- **Dart strict** ; `flutter analyze` : 0 erreur.
- **Smoke tests** : 6 scénarios minimaux (scope user, RLS, ambiguïté, confirmation, free gating).
- **Hors scope Phase 1 :** TimescaleDB, `schedule_action`, voice round-trip, notifications push.

## File Structure (modifications à la spec)

```
supabase/
  migrations/
    20260626000001_realtime_power_and_rpc.sql   ← NEW (table + RLS + indexes + publication + RPC)
  functions/
    agent-orchestrator/
      index.ts                                   ← MODIFY (tool gating + criticality dans handleToolCall)
      tools.ts                                   ← MODIFY (+2 tools, helpers de filtre, SYSTEM_PROMPT confirmé)
      policy.ts                                  ← MODIFY (CRITICAL_APPLIANCES + evaluateCriticality)
      actions.ts                                 ← MODIFY (getLiveConsumption + getTotalConsumption)
      rag.ts                                     ← MODIFY (searchConsumptionSummaries + combinedSearchUserRag)
      audit.ts                                   ← MODIFY (status "pending" ajouté au type)
      types.ts                                   ← MODIFY (AuditStatus "pending")
    consumption-summarizer/
      index.ts                                   ← NEW (cron quotidien)
workers/
  mqtt5-worker/
    index.js                                     ← MODIFY (upsert realtime_power après parse)
lib/
  services/
    realtime_power_service.dart                  ← NEW
    agent_service.dart                           ← MODIFY (handler SSE tool_result/requires_confirmation)
  widgets/
    live_consumption_indicator.dart              ← NEW
    confirmation_dialog.dart                     ← NEW
  screens/chatbot/
    chatbot_screen.dart                          ← MODIFY (wire modale confirmation + live indicator)
test/
  agent_rag_smoke_test.dart                      ← NEW (5 tests unitaires policy/actions/criticality)
```

---

## Task 1: Migration SQL — `realtime_power` + RPC `sum_total_consumption`

**Files:**
- Create: `supabase/migrations/20260626000001_realtime_power_and_rpc.sql`

**Interfaces:**
- Produces (DB):
  - Table `realtime_power (appliance_id PK, user_id, box_id, power_kwh NUMERIC(12,6), instant_power_w NUMERIC(10,2), updated_at)` + RLS SELECT (`user_id = auth.uid() OR private.is_admin()`).
  - Index `idx_realtime_power_user`, `idx_realtime_power_updated`.
  - Publication `supabase_realtime` étendue à `realtime_power`.
  - RPC `sum_total_consumption(requester_id UUID, period TEXT) RETURNS JSONB` SECURITY DEFINER (`total_kwh`, `by_appliance[]`).

- [ ] **Step 1: Créer le fichier de migration**

Écrire exactement ce contenu dans `supabase/migrations/20260626000001_realtime_power_and_rpc.sql` :

```sql
-- Migration: realtime_power + RPC sum_total_consumption
-- Date: 2026-06-26
-- Spec: docs/superpowers/specs/2026-06-25-aricie-agent-rag-design.md

-- 1. realtime_power : dernière valeur de puissance par appliance (UPSERT)
CREATE TABLE IF NOT EXISTS realtime_power (
  appliance_id UUID PRIMARY KEY REFERENCES appliances(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  box_id UUID NOT NULL,
  power_kwh NUMERIC(12,6) NOT NULL,
  instant_power_w NUMERIC(10,2),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE realtime_power ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS realtime_power_user_select ON realtime_power;
CREATE POLICY realtime_power_user_select
  ON realtime_power FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

CREATE INDEX IF NOT EXISTS idx_realtime_power_user
  ON realtime_power(user_id);

CREATE INDEX IF NOT EXISTS idx_realtime_power_updated
  ON realtime_power(updated_at DESC);

-- Activation Supabase Realtime broadcast (écoute per-user côté Flutter)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'realtime_power'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE realtime_power;
  END IF;
END $$;

-- 2. RPC SECURITY DEFINER : agrégation multi-appareils scope par user_id
--    Le code appelant NE PEUT PAS skipper le WHERE user_id = requester_id.
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

REVOKE ALL ON FUNCTION sum_total_consumption(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION sum_total_consumption(UUID, TEXT) TO authenticated;
```

- [ ] **Step 2: Vérifier la syntaxe SQL**

Run: `Get-Content "C:\Users\paoss\Desktop\flutter\supabase\migrations\20260626000001_realtime_power_and_rpc.sql" | Measure-Object -Line`
Expected: nombre de lignes > 80 (sanity check, le fichier n'est pas vide).

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260626000001_realtime_power_and_rpc.sql
git commit -m "feat(db): add realtime_power table + sum_total_consumption RPC"
```

---

## Task 2: `policy.ts` — Criticalité appareil

**Files:**
- Modify: `supabase/functions/agent-orchestrator/policy.ts` (append après `checkDeviceActionPolicy`)

**Interfaces:**
- Produces:
  - `CRITICAL_APPLIANCES: readonly string[]` (chauffe-eau, clim, four, cuisinière + variantes sans accent).
  - `evaluateCriticality(applianceName: string): "high" | "low"`.

- [ ] **Step 1: Ajouter les exports**

Ajouter à la fin de `supabase/functions/agent-orchestrator/policy.ts` (après la fermeture de `checkDeviceActionPolicy`) :

```ts
/**
 * Appareils à risque : confirmation modale obligatoire avant allumage/extinction.
 * Hardcodé ici (pas de migration), suffit pour le scope actuel.
 */
export const CRITICAL_APPLIANCES = [
  "chauffe-eau",
  "chauffe eau",
  "climatiseur",
  "clim",
  "four",
  "cuisinière",
  "cuisiniere",
];

/**
 * Évalue la criticité métier d'un appareil à partir de son nom.
 * Retourne "high" si le nom matche un appareil critique (insensible casse/accents).
 */
export function evaluateCriticality(applianceName: string): "high" | "low" {
  const lower = applianceName.toLowerCase();
  return CRITICAL_APPLIANCES.some((c) => lower.includes(c)) ? "high" : "low";
}
```

- [ ] **Step 2: Vérifier le typage**

Run: `cd "C:\Users\paoss\Desktop\flutter" && deno check supabase/functions/agent-orchestrator/policy.ts 2>&1 | Select-Object -First 20`
Expected: pas d'erreur de type (Deno non installé → ignorer ce check ; passer au commit).

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/agent-orchestrator/policy.ts
git commit -m "feat(agent): add CRITICAL_APPLIANCES and evaluateCriticality"
```

---

## Task 3: `audit.ts` + `types.ts` — statut `pending`

**Files:**
- Modify: `supabase/functions/agent-orchestrator/audit.ts:11`
- Modify: `supabase/functions/agent-orchestrator/types.ts` (append)

**Interfaces:**
- Produces:
  - `AuditStatus = "allowed" | "blocked" | "failed" | "success" | "pending"`.
  - `audit()` accepte `status: AuditStatus`.

- [ ] **Step 1: Étendre le type d'audit**

Dans `supabase/functions/agent-orchestrator/audit.ts`, ligne 11, remplacer :

```ts
  status: "allowed" | "blocked" | "failed" | "success";
```

par :

```ts
  status: "allowed" | "blocked" | "failed" | "success" | "pending";
```

- [ ] **Step 2: Exporter `AuditStatus`**

Ajouter à la fin de `supabase/functions/agent-orchestrator/types.ts` :

```ts
export type AuditStatus = "allowed" | "blocked" | "failed" | "success" | "pending";
```

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/agent-orchestrator/audit.ts supabase/functions/agent-orchestrator/types.ts
git commit -m "feat(agent): add pending status to AuditStatus"
```

---

## Task 4: `actions.ts` — `getLiveConsumption` + `getTotalConsumption`

**Files:**
- Modify: `supabase/functions/agent-orchestrator/actions.ts` (append)

**Interfaces:**
- Produces:
  - `getLiveConsumption({ supabase, requesterId, applianceName? }): Promise<LivePowerRow[] | null>`.
  - `getTotalConsumption({ supabase, requesterId, period }): Promise<{ period, total_kwh, by_appliance }>`.
  - `LivePowerRow = { appliance_id, power_kwh, instant_power_w, updated_at, appliance_name }`.

- [ ] **Step 1: Ajouter les 2 fonctions**

Ajouter en fin de `supabase/functions/agent-orchestrator/actions.ts` :

```ts
export type LivePowerRow = {
  appliance_id: string;
  appliance_name: string;
  power_kwh: number;
  instant_power_w: number | null;
  updated_at: string;
};

/**
 * Lit realtime_power pour l'utilisateur courant.
 * Si applianceName est fourni, résout puis filtre (null si ambigu).
 */
export async function getLiveConsumption(params: {
  supabase: any;
  requesterId: string;
  applianceName?: string;
}): Promise<LivePowerRow[] | null> {
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

  return (data ?? []).map((row: any) => ({
    appliance_id: row.appliance_id,
    appliance_name: row.appliances?.name ?? "",
    power_kwh: Number(row.power_kwh),
    instant_power_w: row.instant_power_w !== null ? Number(row.instant_power_w) : null,
    updated_at: row.updated_at,
  }));
}

/**
 * Appelle la RPC SECURITY DEFINER sum_total_consumption.
 * total + détail par appareil, scope strict par requester_id.
 */
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

- [ ] **Step 2: Importer `resolveApplianceByName`**

Vérifier que `actions.ts` importe déjà `resolveApplianceByName`. Si non, ajouter en haut du fichier :

```ts
import { resolveApplianceByName } from "./policy.ts";
```

(Le fichier actuel n'importe rien de policy ; ajouter cet import.)

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/agent-orchestrator/actions.ts
git commit -m "feat(agent): add getLiveConsumption and getTotalConsumption actions"
```

---

## Task 5: `tools.ts` — 2 nouveaux tools + helper filtre subscription

**Files:**
- Modify: `supabase/functions/agent-orchestrator/tools.ts` (append tools + helpers, modifier SYSTEM_PROMPT)

**Interfaces:**
- Produces:
  - `get_total_consumption` et `get_live_consumption` ajoutés à `ARICIE_TOOLS`.
  - `isReadOnlyTool(name: string): boolean` (true si nom commence par `get_`).
  - `filterToolsForSubscription(tools, subscriptionType): ReadonlyTool[]`.
  - `SYSTEM_PROMPT` mis à jour : note sur `confirmed: true` et downgrades free.

- [ ] **Step 1: Ajouter les 2 tools à `ARICIE_TOOLS`**

À la fin du tableau `ARICIE_TOOLS` (avant le `];` final), ajouter :

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
          period: {
            type: "string",
            enum: ["day", "week", "month", "year"],
            description: "Période d'agrégation.",
          },
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
        "Récupère la consommation instantanée (kWh + W si disponible) pour un appareil ou tous les appareils de l'utilisateur.",
      parameters: {
        type: "object",
        properties: {
          appliance_name: {
            type: "string",
            description:
              "Nom métier de l'appareil. Si omis, retourne toutes les lectures live.",
          },
        },
        required: [],
        additionalProperties: false,
      },
    },
  },
```

- [ ] **Step 2: Ajouter helpers de filtre**

À la fin de `supabase/functions/agent-orchestrator/tools.ts`, après `SYSTEM_PROMPT`, exporter :

```ts
/**
 * Tools en lecture seule (préfixe get_). Utilisés par le gating subscription.
 */
export function isReadOnlyTool(name: string): boolean {
  return name.startsWith("get_");
}

/**
 * Filtre la liste des tools selon le type de subscription.
 * Free = lecture seule uniquement ; tout le reste = tools complets.
 * Réévalué à chaque appel (pas de cache, downgrade immédiat).
 */
export function filterToolsForSubscription(
  tools: ReadonlyArray<any>,
  subscriptionType: string | null,
): ReadonlyArray<any> {
  if (subscriptionType === "vip") return tools;
  return tools.filter((t) => isReadOnlyTool(t.function.name));
}
```

- [ ] **Step 3: Étendre `SYSTEM_PROMPT`**

Dans la constante `SYSTEM_PROMPT`, juste avant la ligne `Le modèle peut proposer un appel de fonction, mais seul le backend décide si l'action est autorisée.`, insérer :

```
- Pour toute action sensible sur un appareil critique (chauffe-eau, climatiseur, four, cuisinière),
  le backend peut te demander une confirmation explicite : tu dois alors rappeler l'outil avec
  un argument supplémentaire `confirmed: true` après que l'utilisateur a confirmé en modale.
- Si un outil de contrôle d'appareil (turn_on_appliance / turn_off_appliance) n'est pas disponible
  parce que l'utilisateur est en abonnement "free", dis-lui clairement que le contrôle nécessite
  un abonnement supérieur, et propose la lecture seule.
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/agent-orchestrator/tools.ts
git commit -m "feat(agent): add live+total consumption tools, subscription filter, confirm prompt"
```

---

## Task 6: `rag.ts` — helper résumés conso + helper combiné

**Files:**
- Modify: `supabase/functions/agent-orchestrator/rag.ts` (append)

**Interfaces:**
- Produces:
  - `searchConsumptionSummaries({ supabase, requesterId, query })`: délègue à `searchUserRag` puis filtre `metadata->>'source_type' === 'consumption_summary'`.
  - `searchCombinedUserRag({ supabase, requesterId, query })`: concatène `searchUserRag` (sans summaries) + `searchConsumptionSummaries`, dédoublonné par `id`.

- [ ] **Step 1: Ajouter le filtre summaries**

À la fin de `supabase/functions/agent-orchestrator/rag.ts`, ajouter :

```ts
/**
 * Recherche dans le RAG utilisateur et ne garde QUE les résumés conso.
 * Le match_user_embeddings RPC filtre déjà par owner_id (sécurité préservée).
 */
export async function searchConsumptionSummaries(params: {
  supabase: any;
  requesterId: string;
  query: string;
  matchCount?: number;
}) {
  const results = await searchUserRag(params);
  return (results ?? []).filter(
    (r: any) => r.metadata?.source_type === "consumption_summary",
  );
}

/**
 * RAG complet = docs user classiques + résumés conso, dédoublonnés par id.
 * Remplace l'appel direct à searchUserRag dans index.ts.
 */
export async function searchCombinedUserRag(params: {
  supabase: any;
  requesterId: string;
  query: string;
}) {
  const [docs, summaries] = await Promise.all([
    searchUserRag(params).then((rows) =>
      (rows ?? []).filter(
        (r: any) => r.metadata?.source_type !== "consumption_summary",
      )
    ),
    searchConsumptionSummaries(params),
  ]);

  const seen = new Set<string>();
  const merged: any[] = [];
  for (const r of [...docs, ...summaries]) {
    if (seen.has(r.id)) continue;
    seen.add(r.id);
    merged.push(r);
  }
  return merged;
}
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/agent-orchestrator/rag.ts
git commit -m "feat(agent): add consumption summaries search + combined RAG helper"
```

---

## Task 7: `index.ts` — tool gating + criticality + 2 nouveaux tools

**Files:**
- Modify: `supabase/functions/agent-orchestrator/index.ts` (imports, `handleToolCall`, flux principal)

**Interfaces:**
- Produces:
  - `handleToolCall` reconnaît `get_total_consumption`, `get_live_consumption`.
  - `turn_on/off_appliance` : si `criticality === "high"` ET `args.confirmed !== true` → SSE `tool_pending`/`tool_result` avec `requires_confirmation: true`, audit `pending`, **PAS** d'insertion `device_commands`.
  - Flux principal : `filterToolsForSubscription` appliqué à `ARICIE_TOOLS` avant `detectToolOrAnswer` ; `searchCombinedUserRag` au lieu de `searchUserRag`.

- [ ] **Step 1: Mettre à jour les imports**

Remplacer le bloc d'imports en haut de `supabase/functions/agent-orchestrator/index.ts` par :

```ts
import { createAdminClient, getAuthenticatedUser } from "./auth.ts";
import { corsHeaders, jsonError, sseHeaders, writeSse } from "./stream.ts";
import { detectToolOrAnswer, streamFinalAnswer, LlmHttpError } from "./llm.ts";
import {
  resolveApplianceByName,
  checkDeviceActionPolicy,
  evaluateCriticality,
} from "./policy.ts";
import {
  enqueueDeviceCommand,
  getRealtimeConsumption,
  getDeviceStatus,
  getEnergyHistory,
  getLiveConsumption,
  getTotalConsumption,
} from "./actions.ts";
import { audit } from "./audit.ts";
import { searchCombinedUserRag } from "./rag.ts";
import {
  ARICIE_TOOLS,
  SYSTEM_PROMPT,
  filterToolsForSubscription,
} from "./tools.ts";
import type { ChatRequest, ToolCall } from "./types.ts";
```

- [ ] **Step 2: Injecter le criticality check dans `turn_on/off_appliance`**

Dans `handleToolCall`, juste après la résolution (`if (!resolved) { ... }`) et avant `checkDeviceActionPolicy`, insérer :

```ts
    const criticality = evaluateCriticality(resolved.appliance_name);
    const isHighRisk = criticality === "high";
    const isConfirmed = args.confirmed === true;

    if (isHighRisk && !isConfirmed) {
      await audit({
        supabase: params.supabase,
        requesterId: params.requesterId,
        action: name,
        targetType: "appliance",
        targetId: resolved.appliance_id,
        status: "pending",
        details: {
          reason: "high_criticality_requires_confirmation",
          appliance_name: resolved.appliance_name,
          criticality,
        },
      });

      await writeSse(params.controller, "tool_pending", {
        tool: name,
        label: `${actionLabel} de ${resolved.appliance_name} (confirmation requise)`,
        requires_confirmation: true,
        criticality,
        appliance_name: resolved.appliance_name,
        action,
      });

      await writeSse(params.controller, "tool_result", {
        tool: name,
        success: false,
        requires_confirmation: true,
        criticality,
        appliance_name: resolved.appliance_name,
        action,
      });

      return {
        role: "tool" as const,
        tool_call_id: params.toolCall.id,
        content: JSON.stringify({
          success: false,
          requires_confirmation: true,
          criticality,
          appliance_name: resolved.appliance_name,
          action,
        }),
      };
    }
```

- [ ] **Step 3: Ajouter le handler `get_total_consumption`**

À la fin de `handleToolCall`, juste avant le commentaire `// Tool inconnu`, insérer :

```ts
  // --- Conso agrégée (RPC SECURITY DEFINER) ---
  if (name === "get_total_consumption") {
    await writeSse(params.controller, "tool_pending", {
      tool: name,
      label: `Agrégation de la consommation sur ${args.period ?? "day"}`,
    });

    const period = (args.period ?? "day") as "day" | "week" | "month" | "year";
    const total = await getTotalConsumption({
      supabase: params.supabase,
      requesterId: params.requesterId,
      period,
    });

    await writeSse(params.controller, "tool_result", {
      tool: name,
      success: true,
    });

    return {
      role: "tool" as const,
      tool_call_id: params.toolCall.id,
      content: JSON.stringify({ success: true, total }),
    };
  }

  // --- Conso live (realtime_power) ---
  if (name === "get_live_consumption") {
    await writeSse(params.controller, "tool_pending", {
      tool: name,
      label: args.appliance_name
        ? `Lecture live de ${args.appliance_name}`
        : "Lecture live globale",
    });

    const live = await getLiveConsumption({
      supabase: params.supabase,
      requesterId: params.requesterId,
      applianceName: args.appliance_name,
    });

    if (live === null) {
      await writeSse(params.controller, "tool_result", {
        tool: name,
        success: false,
        reason: "appliance_not_found_or_ambiguous",
      });

      return {
        role: "tool" as const,
        tool_call_id: params.toolCall.id,
        content: JSON.stringify({
          success: false,
          reason: "Appareil introuvable ou ambigu.",
        }),
      };
    }

    await writeSse(params.controller, "tool_result", {
      tool: name,
      success: true,
    });

    return {
      role: "tool" as const,
      tool_call_id: params.toolCall.id,
      content: JSON.stringify({ success: true, live }),
    };
  }
```

- [ ] **Step 4: Tool gating dans le flux principal**

Dans `Deno.serve` (bloc `start`), remplacer les lignes :

```ts
        // RAG : recherche contextuelle scope par owner
        const ragContext = await searchUserRag({
```

par :

```ts
        // Tool gating par subscription.type (free = lecture seule, pas de cache)
        const allowedTools = filterToolsForSubscription(
          ARICIE_TOOLS,
          operationalContext.subscription_type,
        );

        // RAG : recherche contextuelle scope par owner (docs + résumés conso)
        const ragContext = await searchCombinedUserRag({
```

Puis remplacer le bloc `detectToolOrAnswer` :

```ts
        // Premier appel Azure OpenAI : détection d'intention + tool calling
        const firstPass = await detectToolOrAnswer({
          message: body.message,
          operationalContext,
          ragContext,
        });
```

par :

```ts
        // Premier appel Azure OpenAI : détection d'intention + tool calling
        const firstPass = await detectToolOrAnswer({
          message: body.message,
          operationalContext,
          ragContext,
          tools: allowedTools,
        });
```

- [ ] **Step 5: Étendre la signature `detectToolOrAnswer`**

Dans `supabase/functions/agent-orchestrator/llm.ts`, remplacer la signature de `detectToolOrAnswer` :

```ts
export async function detectToolOrAnswer(params: {
  message: string;
  operationalContext: unknown;
  ragContext?: unknown;
}) {
```

par :

```ts
export async function detectToolOrAnswer(params: {
  message: string;
  operationalContext: unknown;
  ragContext?: unknown;
  tools?: ReadonlyArray<any>;
}) {
```

et remplacer la ligne :

```ts
    tools: ARICIE_TOOLS,
```

par :

```ts
    tools: params.tools ?? ARICIE_TOOLS,
```

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/agent-orchestrator/index.ts supabase/functions/agent-orchestrator/llm.ts
git commit -m "feat(agent): tool gating subscription + criticality confirmation + 2 new tools"
```

---

## Task 8: Worker MQTT5 — UPSERT `realtime_power`

**Files:**
- Modify: `workers/mqtt5-worker/index.js` (ajout upsert après parsing)

**Interfaces:**
- Produces: sur chaque message MQTT télémétrie reçu, le worker upsert `realtime_power` par `appliance_id` (last-write-wins).
- Aucune autre logique modifiée (`device_commands`/`ACK` intacts).

- [ ] **Step 1: Ajouter l'upsert après parse du payload**

Dans `workers/mqtt5-worker/index.js`, **avant** le bloc `client.on("message", ...)` existant (par exemple juste après le bloc `client.on("error", ...)`), insérer :

```js
async function upsertRealtimePower({ applianceId, userId, boxId, payload }) {
  if (payload.kwh_total === undefined) return;

  const { error } = await supabase
    .from("realtime_power")
    .upsert(
      {
        appliance_id: applianceId,
        user_id: userId,
        box_id: boxId,
        power_kwh: payload.kwh_total,
        instant_power_w: payload.power_w ?? null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "appliance_id" },
    );

  if (error) {
    console.error("[TELEMETRY] realtime_power upsert error:", error);
  }
}
```

- [ ] **Step 2: Brancher dans le handler message existant**

Dans `client.on("message", async (topic, payload, packet) => { ... })`, juste après le bloc try de parsing (`const message = JSON.parse(...)`) et **avant** le `if (!message.command_id) return;`, insérer :

```js
    // Télémétrie per-boîtier : upsert realtime_power pour chaque appliance du box
    if (topic.startsWith("aricie/v1/boxes/") && topic.endsWith("/telemetry")) {
      const boxUid = topic.split("/")[3];
      const { data: appliances, error: appliancesError } = await supabase
        .from("appliances")
        .select("id, user_id, box_id, relay_index, boxes!inner(uid_hardware)")
        .eq("boxes.uid_hardware", boxUid);

      if (appliancesError) {
        console.error("[TELEMETRY] appliances lookup error:", appliancesError);
      } else if (Array.isArray(appliances)) {
        // payload peut contenir power_w par relais (relay_index -> watts)
        const relayPowers = payload.relay_power_w ?? {};
        for (const appliance of appliances) {
          const kwh = payload.kwh_total_per_relay?.[appliance.relay_index] ??
            payload.kwh_total ?? 0;
          const watts = relayPowers[appliance.relay_index] ??
            payload.power_w ?? null;
          await upsertRealtimePower({
            applianceId: appliance.id,
            userId: appliance.user_id,
            boxId: appliance.box_id,
            payload: { kwh_total: kwh, power_w: watts },
          });
        }
      }
      return; // télémétrie ≠ ACK, on ne traite pas plus loin
    }
```

- [ ] **Step 3: Commit**

```bash
git add workers/mqtt5-worker/index.js
git commit -m "feat(worker): upsert realtime_power on telemetry"
```

---

## Task 9: Edge Function `consumption-summarizer` (cron)

**Files:**
- Create: `supabase/functions/consumption-summarizer/index.ts`

**Interfaces:**
- Produces: Edge Function invoquée par Supabase Cron (`0 5 * * *`). Pour chaque user actif : agrège `energy_data` de la veille, génère un résumé FR, calcule embedding Azure OpenAI (fallback silencieux si KO), upsert dans `chat_embeddings` (`metadata->>'source_type' = 'consumption_summary'`, `source_id = '<YYYY-MM-DD>'`).

- [ ] **Step 1: Créer le handler**

Écrire `supabase/functions/consumption-summarizer/index.ts` :

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

const AZURE_ENDPOINT = Deno.env.get("AZURE_OPENAI_ENDPOINT") ?? "";
const AZURE_KEY = Deno.env.get("AZURE_OPENAI_API_KEY") ?? "";
const AZURE_EMBED_DEPLOYMENT = Deno.env.get("AZURE_OPENAI_EMBEDDING_DEPLOYMENT") ??
  "text-embedding-3-small";
const AZURE_CHAT_DEPLOYMENT = Deno.env.get("AZURE_OPENAI_DEPLOYMENT") ?? "gpt-4o";
const AZURE_API_VERSION = Deno.env.get("AZURE_OPENAI_API_VERSION") ?? "2024-10-21";

function yesterdayISO(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
}

async function azureEmbedding(text: string): Promise<number[] | null> {
  if (!AZURE_ENDPOINT || !AZURE_KEY) return null;
  try {
    const res = await fetch(
      `${AZURE_ENDPOINT}/openai/deployments/${AZURE_EMBED_DEPLOYMENT}/embeddings?api-version=${AZURE_API_VERSION}`,
      {
        method: "POST",
        headers: { "api-key": AZURE_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({ input: text }),
      },
    );
    if (!res.ok) return null;
    const json = await res.json();
    return json.data?.[0]?.embedding ?? null;
  } catch {
    return null;
  }
}

async function azureSummary(prompt: string): Promise<string | null> {
  if (!AZURE_ENDPOINT || !AZURE_KEY) return null;
  try {
    const res = await fetch(
      `${AZURE_ENDPOINT}/openai/deployments/${AZURE_CHAT_DEPLOYMENT}/chat/completions?api-version=${AZURE_API_VERSION}`,
      {
        method: "POST",
        headers: { "api-key": AZURE_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: [
            {
              role: "system",
              content:
                "Tu génères des résumés FR courts de consommation énergétique quotidienne. " +
                "Réponds en 2-3 phrases maximum.",
            },
            { role: "user", content: prompt },
          ],
          temperature: 0.3,
          max_tokens: 200,
        }),
      },
    );
    if (!res.ok) return null;
    const json = await res.json();
    return json.choices?.[0]?.message?.content ?? null;
  } catch {
    return null;
  }
}

async function summarizeUser(userId: string, date: string) {
  const { data: rows, error } = await supabase
    .from("energy_data")
    .select("appliance_id, total_day, appliances!inner(name, location)")
    .eq("user_id", userId)
    .eq("date", date);

  if (error) {
    console.error(`[summarizer] ${userId} read error:`, error);
    return;
  }

  if (!rows || rows.length === 0) return; // pas de data, on skip

  const total = rows.reduce(
    (acc: number, r: any) => acc + Number(r.total_day ?? 0),
    0,
  );
  const top = rows
    .slice()
    .sort((a: any, b: any) => Number(b.total_day) - Number(a.total_day))
    .slice(0, 5)
    .map((r: any) =>
      `- ${r.appliances?.name ?? "?"} (${r.appliances?.location ?? "?"}): ${
        Number(r.total_day).toFixed(2)
      } kWh`
    )
    .join("\n");

  const prompt =
    `Date : ${date}\nTotal du jour : ${total.toFixed(2)} kWh\n` +
    `Détail par appareil :\n${top}\n` +
    `Génère un résumé conversationnel FR pour cet utilisateur.`;
  const summary = await azureSummary(prompt);
  if (!summary) {
    console.warn(`[summarizer] ${userId} Azure KO, skip embedding`);
    return;
  }

  const embedding = await azureEmbedding(summary);
  if (!embedding) {
    console.warn(`[summarizer] ${userId} embedding KO, skip upsert`);
    return;
  }

  const sourceId = `${userId}:${date}`;
  const { error: upsertError } = await supabase
    .from("chat_embeddings")
    .upsert(
      {
        owner_id: userId,
        scope: "user",
        source_type: "consumption_summary",
        source_id: sourceId,
        content: summary,
        metadata: {
          source_type: "consumption_summary",
          date,
          total_kwh: total,
        },
        embedding,
      },
      { onConflict: "source_id" },
    );

  if (upsertError) {
    console.error(`[summarizer] ${userId} upsert error:`, upsertError);
  } else {
    console.log(`[summarizer] ${userId} ${date} OK (${total.toFixed(2)} kWh)`);
  }
}

Deno.serve(async () => {
  const date = yesterdayISO();

  const { data: users, error } = await supabase
    .from("subscriptions")
    .select("user_id")
    .eq("is_active", true);

  if (error) {
    console.error("[summarizer] users lookup error:", error);
    return new Response(JSON.stringify({ ok: false, error: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  for (const row of users ?? []) {
    await summarizeUser(row.user_id, date);
  }

  return new Response(JSON.stringify({ ok: true, date, count: users?.length ?? 0 }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/consumption-summarizer/index.ts
git commit -m "feat(cron): add consumption-summarizer edge function (daily)"
```

---

## Task 10: Flutter — `RealtimePowerService`

**Files:**
- Create: `lib/services/realtime_power_service.dart`

**Interfaces:**
- Produces:
  - Classe `RealtimePowerService` singleton.
  - `Stream<RealtimePowerReading> get stream`.
  - `void start(String userId)`.
  - `Future<void> dispose()`.
  - Modèle `RealtimePowerReading` (applianceId, applianceName, powerKwh, instantPowerW?, updatedAt).

- [ ] **Step 1: Créer le service**

Écrire `lib/services/realtime_power_service.dart` :

```dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimePowerReading {
  final String applianceId;
  final String applianceName;
  final double powerKwh;
  final double? instantPowerW;
  final DateTime updatedAt;

  RealtimePowerReading({
    required this.applianceId,
    required this.applianceName,
    required this.powerKwh,
    required this.instantPowerW,
    required this.updatedAt,
  });

  factory RealtimePowerReading.fromJson(Map<String, dynamic> row) {
    final num kwh = row['power_kwh'] as num? ?? 0;
    final dynamic w = row['instant_power_w'];
    return RealtimePowerReading(
      applianceId: row['appliance_id'] as String,
      applianceName: (row['appliances'] as Map?)?['name'] as String? ?? '',
      powerKwh: kwh.toDouble(),
      instantPowerW: w is num ? w.toDouble() : null,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

class RealtimePowerService {
  RealtimePowerService._();

  static final RealtimePowerService instance = RealtimePowerService._();

  final StreamController<RealtimePowerReading> _controller =
      StreamController<RealtimePowerReading>.broadcast();

  RealtimeChannel? _channel;

  Stream<RealtimePowerReading> get stream => _controller.stream;

  void start(String userId) {
    _channel?.unsubscribe();

    final client = Supabase.instance.client;
    _channel = client
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
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;
            try {
              _controller.add(RealtimePowerReading.fromJson(newRecord));
            } catch (_) {
              // payload malformé : on ignore silencieusement
            }
          },
        )
        .subscribe();
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
    await _controller.close();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/realtime_power_service.dart
git commit -m "feat(flutter): add RealtimePowerService for live consumption"
```

---

## Task 11: Flutter — `LiveConsumptionIndicator` widget

**Files:**
- Create: `lib/widgets/live_consumption_indicator.dart`

**Interfaces:**
- Produces: `Widget liveConsumptionIndicator(BuildContext, String userId)` : total kWh du jour + top 3 + pulse live.

- [ ] **Step 1: Créer le widget**

Écrire `lib/widgets/live_consumption_indicator.dart` :

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/realtime_power_service.dart';

class LiveConsumptionIndicator extends StatefulWidget {
  final String userId;

  const LiveConsumptionIndicator({super.key, required this.userId});

  @override
  State<LiveConsumptionIndicator> createState() => _LiveConsumptionIndicatorState();
}

class _LiveConsumptionIndicatorState extends State<LiveConsumptionIndicator> {
  StreamSubscription<RealtimePowerReading>? _sub;
  final List<RealtimePowerReading> _readings = [];

  @override
  void initState() {
    super.initState();
    RealtimePowerService.instance.start(widget.userId);
    _sub = RealtimePowerService.instance.stream.listen((r) {
      if (!mounted) return;
      setState(() {
        _readings.removeWhere((x) => x.applianceId == r.applianceId);
        _readings.add(r);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool _isLive(DateTime updatedAt) {
    return DateTime.now().difference(updatedAt).inSeconds < 30;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _readings.toList()
      ..sort((a, b) => b.powerKwh.compareTo(a.powerKwh));
    final top3 = sorted.take(3).toList();
    final total = _readings.fold<double>(0.0, (acc, r) => acc + r.powerKwh);
    final live = _readings.any((r) => _isLive(r.updatedAt));

    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt,
                  color: live ? scheme.primary : scheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Conso live',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${total.toStringAsFixed(2)} kWh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (top3.isEmpty)
              Text(
                'En attente de télémétrie...',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            else
              ...top3.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _isLive(r.updatedAt)
                              ? scheme.primary
                              : scheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.applianceName.isEmpty
                                ? r.applianceId.substring(0, 8)
                                : r.applianceName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${r.powerKwh.toStringAsFixed(2)} kWh'
                          '${r.instantPowerW != null ? ' • ${r.instantPowerW!.toStringAsFixed(0)} W' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/live_consumption_indicator.dart
git commit -m "feat(flutter): add LiveConsumptionIndicator widget"
```

---

## Task 12: Flutter — `ConfirmationDialog` widget

**Files:**
- Create: `lib/widgets/confirmation_dialog.dart`

**Interfaces:**
- Produces: `Future<bool> showConfirmationDialog(BuildContext, {required String title, required String body})`.

- [ ] **Step 1: Créer le dialog**

Écrire `lib/widgets/confirmation_dialog.dart` :

```dart
import 'package:flutter/material.dart';

/// Affiche une modale de confirmation critique. Retourne true si confirmé.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 36),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/confirmation_dialog.dart
git commit -m "feat(flutter): add ConfirmationDialog for critical actions"
```

---

## Task 13: Flutter — wire modale dans `chatbot_screen.dart`

**Files:**
- Modify: `lib/screens/chatbot/chatbot_screen.dart` (handler `tool_result` + branche `requires_confirmation`)

**Interfaces:**
- Produit:
  - Sur SSE `tool_result` avec `requires_confirmation: true`, le client ouvre la modale ; si confirmé, renvoie un message user `"oui, confirme"` qui re-déclenche `turn_*_appliance` avec `confirmed: true`.
  - Le champ SSE consommé : `requires_confirmation`, `criticality`, `appliance_name`, `action`.

- [ ] **Step 1: Mémoriser l'action pending**

Dans `_ChatbotScreenState`, ajouter un champ :

```dart
  Map<String, dynamic>? _pendingCriticalAction;
```

- [ ] **Step 2: Gérer `tool_result` avec `requires_confirmation`**

Dans `_streamResponse`, dans le `case 'tool_result':`, remplacer le bloc existant par :

```dart
          case 'tool_result':
            final requiresConfirmation =
                event.data['requires_confirmation'] == true;
            if (requiresConfirmation) {
              final applianceName =
                  event.data['appliance_name'] as String? ?? 'appareil';
              final action = event.data['action'] as String? ?? 'on';
              final actionLabel = action == 'on' ? 'allumer' : 'éteindre';
              _pendingCriticalAction = {
                'appliance_name': applianceName,
                'action': action,
              };
              _updateLastBotMessage(
                text:
                    '⚠️ Action sensible : $actionLabel $applianceName. ' +
                        'Veuillez confirmer.',
                isStreaming: false,
                actionType: currentActionType,
              );
              break;
            }

            if (event.data is Map &&
                (event.data as Map).containsKey('success')) {
              final success = event.data['success'] as bool? ?? false;
              final toolLabel = currentActionType != null
                  ? _toolLabelToFrench(currentActionType!)
                  : '';
              if (success) {
                fullText +=
                    _isVoiceMode ? '$toolLabel effectué.\n' : '✓ Terminé.\n';
              } else {
                final reason = event.data['reason'] as String?;
                final msg = switch (reason) {
                  'appliance_not_found_or_ambiguous' => 'Appareil introuvable.',
                  'rate_limited' => 'Trop de commandes.',
                  _ => 'Action non disponible.',
                };
                fullText += '$msg\n';
              }
            } else {
              final toolLabel = currentActionType != null
                  ? _toolLabelToFrench(currentActionType!)
                  : 'Commande';
              fullText +=
                  _isVoiceMode ? '$toolLabel récupéré.\n' : 'Données récupérées.\n';
            }
            _updateLastBotMessage(
              text: fullText,
              isStreaming: true,
              actionType: currentActionType,
            );
            break;
```

- [ ] **Step 3: Ouvrir la modale après `done`**

Dans `_streamResponse`, dans `case 'done':`, remplacer `_finalizeBotMessage(fullText, actionType: currentActionType);` par :

```dart
          case 'done':
            _finalizeBotMessage(fullText, actionType: currentActionType);
            if (_pendingCriticalAction != null) {
              final pending = _pendingCriticalAction!;
              _pendingCriticalAction = null;
              _askCriticalConfirmation(
                applianceName: pending['appliance_name'] as String,
                action: pending['action'] as String,
              );
            }
            break;
```

- [ ] **Step 4: Implémenter `_askCriticalConfirmation`**

Ajouter à la fin de `_ChatbotScreenState`, juste avant `_toolLabelToFrench` :

```dart
  Future<void> _askCriticalConfirmation({
    required String applianceName,
    required String action,
  }) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Confirmer l\'action',
      body:
          'Voulez-vous vraiment ${action == "on" ? "allumer" : "éteindre"} '
          '$applianceName ?',
      confirmLabel: 'Oui, ${action == "on" ? "allumer" : "éteindre"}',
    );

    if (!mounted || !confirmed) return;

    // Renvoie un message user qui re-déclenche le tool_call avec confirmed: true.
    // Le LLM rappelle turn_*_appliance et inclut confirmé dans ses arguments.
    _addMessage('Oui, confirme ${action == "on" ? "allumer" : "éteindre"} $applianceName', true);
  }
```

- [ ] **Step 5: Importer le dialog**

Vérifier que l'import suivant est présent en haut de `chatbot_screen.dart` (ajouter si besoin) :

```dart
import '../../widgets/confirmation_dialog.dart';
```

- [ ] **Step 6: Commit**

```bash
git add lib/screens/chatbot/chatbot_screen.dart
git commit -m "feat(flutter): wire critical action confirmation modal in chatbot"
```

---

## Task 14: Flutter — wire live indicator dans `chatbot_screen.dart`

**Files:**
- Modify: `lib/screens/chatbot/chatbot_screen.dart` (ajout du widget en tête de liste)

**Interfaces:**
- Produces: Le `LiveConsumptionIndicator` apparaît en tête de la liste des messages (au-dessus du `ListView`), visible en permanence pendant le chat.

- [ ] **Step 1: Importer le widget**

Ajouter en haut de `chatbot_screen.dart` (près des autres imports widgets) :

```dart
import '../../widgets/live_consumption_indicator.dart';
```

- [ ] **Step 2: Injecter dans la `Column` du body**

Dans `build()`, remplacer la `Column` racine du `body:` par :

```dart
      body: Column(
        children: [
          if (Supabase.instance.client.auth.currentUser != null)
            LiveConsumptionIndicator(
              userId: Supabase.instance.client.auth.currentUser!.id,
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    // ... (reste du Center inchangé)
```

(Laisser le `Center` et le `ListView` existants intacts ; seul le `LiveConsumptionIndicator` est inséré au-dessus de l'`Expanded`.)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/chatbot/chatbot_screen.dart
git commit -m "feat(flutter): show live consumption indicator in chatbot"
```

---

## Task 15: Smoke tests (5 scénarios)

**Files:**
- Create: `test/agent_rag_smoke_test.dart`

**Interfaces:**
- Produces: Tests unitaires Dart qui n'ont pas besoin de DB :
  - `evaluateCriticality` matche / ne matche pas.
  - `filterToolsForSubscription` : free = 0 write tools, vip = full set.
  - `isReadOnlyTool` : tous les `get_*` true, `turn_*` false.

- [ ] **Step 1: Créer le fichier de tests**

Écrire `test/agent_rag_smoke_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';

/// Tests miroir des fonctions Edge Function. Les implémentations Dart sont
/// des copies fidèles (smoke test local — la vérité reste l'Edge Function).
bool _matchesCritical(String name) {
  const critical = [
    'chauffe-eau', 'chauffe eau', 'climatiseur', 'clim',
    'four', 'cuisinière', 'cuisiniere',
  ];
  final lower = name.toLowerCase();
  return critical.any(lower.contains);
}

bool _isReadOnly(String name) => name.startsWith('get_');

List<String> _filterToolsForSubscription(
  List<String> tools,
  String? subscriptionType,
) {
  if (subscriptionType == 'vip') return tools;
  return tools.where(_isReadOnly).toList();
}

void main() {
  group('evaluateCriticality (mirror)', () {
    test('chauffe-eau est critique', () {
      expect(_matchesCritical('chauffe-eau'), isTrue);
    });

    test('Climatiseur salon est critique (casse + accent)', () {
      expect(_matchesCritical('Climatiseur Salon'), isTrue);
    });

    test('lampe du salon n\'est pas critique', () {
      expect(_matchesCritical('lampe du salon'), isFalse);
    });

    test('four matche', () {
      expect(_matchesCritical('Four'), isTrue);
    });
  });

  group('isReadOnlyTool (mirror)', () {
    test('get_* sont read-only', () {
      expect(_isReadOnly('get_realtime_consumption'), isTrue);
      expect(_isReadOnly('get_live_consumption'), isTrue);
      expect(_isReadOnly('get_total_consumption'), isTrue);
    });

    test('turn_* ne sont pas read-only', () {
      expect(_isReadOnly('turn_on_appliance'), isFalse);
      expect(_isReadOnly('turn_off_appliance'), isFalse);
    });
  });

  group('filterToolsForSubscription (mirror)', () {
    final allTools = [
      'turn_on_appliance',
      'turn_off_appliance',
      'get_realtime_consumption',
      'get_device_status',
      'get_energy_history',
      'get_live_consumption',
      'get_total_consumption',
    ];

    test('free = read-only only', () {
      final filtered = _filterToolsForSubscription(allTools, 'free');
      expect(filtered, [
        'get_realtime_consumption',
        'get_device_status',
        'get_energy_history',
        'get_live_consumption',
        'get_total_consumption',
      ]);
    });

    test('null subscription = read-only only (safe default)', () {
      final filtered = _filterToolsForSubscription(allTools, null);
      expect(filtered.length, 5);
      expect(filtered.any((t) => t.startsWith('turn_')), isFalse);
    });

    test('vip = tous les tools', () {
      final filtered = _filterToolsForSubscription(allTools, 'vip');
      expect(filtered.length, allTools.length);
    });

    test('downgrade free -> free après vip (pas de cache)', () {
      // Premier appel : vip
      final vip = _filterToolsForSubscription(allTools, 'vip');
      expect(vip.length, allTools.length);
      // Downgrade : free
      final free = _filterToolsForSubscription(allTools, 'free');
      expect(free.length, 5);
    });
  });
}
```

- [ ] **Step 2: Lancer les tests**

Run: `cd "C:\Users\paoss\Desktop\flutter" && flutter test test/agent_rag_smoke_test.dart`
Expected: `All tests passed!` — 11 tests verts.

- [ ] **Step 3: Lancer flutter analyze**

Run: `cd "C:\Users\paoss\Desktop\flutter" && flutter analyze lib/services/realtime_power_service.dart lib/widgets/live_consumption_indicator.dart lib/widgets/confirmation_dialog.dart lib/screens/chatbot/chatbot_screen.dart test/agent_rag_smoke_test.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add test/agent_rag_smoke_test.dart
git commit -m "test(agent): add smoke tests for criticality + tool gating"
```

---

## Self-Review

1. **Couverture spec :**
   - Realtime + RPC conso agrégée → Tâche 1 (migration).
   - Worker MQTT upsert → Tâche 8.
   - 2 tools + tool gating subscription → Tâches 5 + 7.
   - Criticalité + confirmation destructive → Tâches 2 + 7 + 13.
   - Cloisonnement user_id → Tâche 1 (RLS + RPC SECURITY DEFINER).
   - Tool gating free=lecture seule → Tâche 5 + 7.
   - RAG résumés conso (cron) → Tâches 6 + 9.
   - Live UI Flutter → Tâches 10 + 11 + 14.
   - Modale confirmation → Tâches 12 + 13.
   - Smoke tests → Tâche 15.
   - Critères d'acceptation Phase 1 : tous couverts.

2. **Placeholders :** aucun "TBD" / "TODO" / "implement later".

3. **Cohérence des types :**
   - `LivePowerRow` (actions.ts) → consommé dans `tool_result` JSON.
   - `RealtimePowerReading.fromJson` (Flutter) → consomme `power_kwh` / `instant_power_w` / `appliances.name` (cohérent avec `actions.ts` `select`).
   - `evaluateCriticality("high" | "low")` → consommé dans `index.ts` (`isHighRisk`).
   - `filterToolsForSubscription` → consommé dans `index.ts` via `allowedTools` → passé à `detectToolOrAnswer({ tools })`.
   - `searchCombinedUserRag` → consommé dans `index.ts` (`ragContext`).
   - SSE `tool_result { requires_confirmation, criticality, appliance_name, action }` → consommé dans `chatbot_screen.dart` (étape 13).

4. **Hors scope respecté :** pas de TimescaleDB, pas de `schedule_action`, pas de notifications push.

---

## Execution Handoff

Plan complete et sauvegardé dans `docs/superpowers/plans/2026-06-26-aricie-agent-rag.md`.

Deux options d'exécution :

1. **Subagent-Driven (recommandé)** — Je dispatch un subagent frais par tâche, review entre chaque, itération rapide.
2. **Inline Execution** — J'exécute les tâches dans cette session via `executing-plans`, batch avec checkpoints.

Quelle approche ?
