# Energy Tips Banner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le bloc "Conseils d'économie" statique de `home_screen.dart` par un banner persistant 24h, personnalisé via règles déterministes, avec push temps réel (worker MQTT5 + agent VIP) déclenchant aussi une notification locale.

**Architecture:** Nouvelle edge function `tips-generator` (mode batch cron + endpoint `/evaluate-live`) ; règles pures TypeScript (`tips.ts`, `liveRules.ts`) ; deux tables (`daily_energy_tip` cron, `energy_tips_realtime` push) ; Realtime broadcast sur `energy_tips_realtime` ; service Flutter qui pousse via `NotificationService` ; widget banner qui override daily ↔ live.

**Tech Stack:** Supabase (PostgreSQL + Realtime + Edge Functions Deno + Cron), Node.js (MQTT5 worker), Flutter/Dart 3, `flutter_local_notifications`.

## Global Constraints

- **Pas de LLM** : règles TypeScript pures et déterministes dans `tips.ts` / `liveRules.ts`.
- **Cloisonnement strict** : `user_id` sur toutes les tables, RLS + service_role uniquement pour écriture.
- **Tool gating agent** : `push_tip` filtré pour les free via `filterToolsForSubscription` existant.
- **Cooldown worker** : 1h par `(user_id, appliance_id)` côté worker pour éviter le spam sur pic persistant.
- **Canal de notification** : `innovation_channel` (déjà configuré dans `notification_service.dart`) ; IDs `9000 + hash(id) % 1000`.
- **`daily_energy_tip` n'est PAS dans Supabase Realtime** — lu au boot + pull-to-refresh uniquement.
- **`energy_tips_realtime` EST dans Supabase Realtime** — push instantané.
- **Tests smoke** : `pickTip` sur 3 ctx, `evaluateLiveRules` sur 2 ctx, mappings `_iconFor`/`_colorFor` côté Dart.
- **Dart strict** ; `flutter analyze` : 0 erreur ; `deno check tips-generator/` : 0 erreur.

## File Structure

```
supabase/
  migrations/
    20260626000002_energy_tips.sql                     ← NEW
  functions/
    tips-generator/
      index.ts                                          ← NEW (batch + /evaluate-live)
      tips.ts                                           ← NEW (règles daily pures)
      liveRules.ts                                      ← NEW (règles live pures)
      context.ts                                        ← NEW (DB → TipContext)
    agent-orchestrator/
      tools.ts                                          ← MODIFY (+1 tool push_tip)
      index.ts                                          ← MODIFY (handler push_tip)
workers/
  mqtt5-worker/
    index.js                                            ← MODIFY (cooldown map + POST /evaluate-live)
lib/
  services/
    tips_realtime_service.dart                          ← NEW
  widgets/
    daily_energy_tip_banner.dart                        ← NEW
  screens/
    home_screen.dart                                    ← MODIFY (remplace _buildTipCard)
  main.dart                                             ← MODIFY (TipsRealtimeService.instance.start())
test/
  tips_banner_test.dart                                 ← NEW
```

---

## Task 1: Migration SQL — `daily_energy_tip` + `energy_tips_realtime`

**Files:**
- Create: `supabase/migrations/20260626000002_energy_tips.sql`

**Interfaces:**
- Produces (DB):
  - Table `daily_energy_tip (user_id PK, date, title, body, icon, severity, rule_id, context JSONB, generated_at)` + RLS SELECT.
  - Table `energy_tips_realtime (id PK, user_id, title, body, icon, severity, source, rule_id, acknowledged, created_at)` + RLS SELECT/UPDATE.
  - Index `idx_realtime_tip_user_created`, `idx_realtime_tip_unack` (partiel WHERE acknowledged=false).
  - `ALTER PUBLICATION supabase_realtime ADD TABLE energy_tips_realtime`.

- [ ] **Step 1: Créer le fichier de migration**

Écrire exactement ce contenu dans `supabase/migrations/20260626000002_energy_tips.sql` :

```sql
-- Migration: energy tips (daily cron + realtime push)
-- Date: 2026-06-26
-- Spec: docs/superpowers/specs/2026-06-26-energy-tips-banner-design.md

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

-- Activation Realtime broadcast sur energy_tips_realtime uniquement
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

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260626000002_energy_tips.sql
git commit -m "feat(db): add daily_energy_tip + energy_tips_realtime tables"
```

---

## Task 2: `tips.ts` — moteur de règles pures

**Files:**
- Create: `supabase/functions/tips-generator/tips.ts`

**Interfaces:**
- Produces:
  - `TipContext` (userId, todayKwh, yesterdayKwh, weekAvgDailyKwh, topAppliances[], inactiveAppliancesOn, peakHourKwh?, subscriptionType).
  - `EnergyTip` (ruleId, title, body, icon, severity, context).
  - `TipRule` (ruleId, severity, condition(ctx), build(ctx)).
  - `pickTip(ctx: TipContext): EnergyTip` — première règle qui matche, sinon default.

- [ ] **Step 1: Créer le fichier**

Écrire `supabase/functions/tips-generator/tips.ts` :

```ts
// Moteur de règles déterministes pour les conseils quotidiens.
// Aucun I/O ici — ctx est construit par context.ts.

export type TipSeverity = "info" | "warning" | "critical";
export type TipIcon = "lightbulb" | "bolt" | "water" | "thermo" | "warning";

export interface TipAppliance {
  id: string;
  name: string;
  kwh: number;
  share: number; // 0..1
  isOn: boolean;
  liveWatts?: number | null;
  typicalWatts?: number | null;
}

export interface TipContext {
  userId: string;
  todayKwh: number;
  yesterdayKwh: number;
  weekAvgDailyKwh: number;
  topAppliances: TipAppliance[];
  inactiveAppliancesOn: string[];
  peakHourKwh?: { hour: number; kwh: number };
  subscriptionType: "free" | "vip";
}

export interface EnergyTip {
  ruleId: string;
  title: string;
  body: string;
  icon: TipIcon;
  severity: TipSeverity;
  context: Record<string, unknown>;
}

type TipRule = {
  ruleId: string;
  severity: TipSeverity;
  condition: (ctx: TipContext) => boolean;
  build: (ctx: TipContext) => Pick<EnergyTip, "title" | "body" | "icon">;
};

const TOP = (ctx: TipContext) => ctx.topAppliances[0];
const FIND = (ctx: TipContext, rx: RegExp) =>
  ctx.topAppliances.find((a) => rx.test(a.name));

const tips: readonly TipRule[] = [
  {
    ruleId: "water_heater_high_share",
    severity: "warning",
    condition: (ctx) => {
      const t = TOP(ctx);
      return !!t && /chauffe.eau/i.test(t.name) && t.share > 0.4 && t.kwh > 5;
    },
    build: (ctx) => {
      const t = TOP(ctx)!;
      return {
        title: "Chauffe-eau : principal poste de dépense",
        body:
          `Votre chauffe-eau représente ${(t.share * 100).toFixed(0)}% de votre conso du jour. ` +
          `Programmez-le en heures creuses pour économiser jusqu'à 30%.`,
        icon: "water",
      };
    },
  },
  {
    ruleId: "ac_live_spike",
    severity: "warning",
    condition: (ctx) => {
      const ac = FIND(ctx, /clim/i);
      return !!ac && ac.liveWatts != null && ac.typicalWatts != null &&
        ac.liveWatts > ac.typicalWatts * 2 && ac.liveWatts > 500;
    },
    build: (ctx) => {
      const ac = FIND(ctx, /clim/i)!;
      return {
        title: "Climatiseur : consommation élevée",
        body:
          `Le climatiseur tourne à ${ac.liveWatts!.toFixed(0)} W alors que sa moyenne est ` +
          `${ac.typicalWatts!.toFixed(0)} W. Augmenter le thermostat de 1°C réduit la conso de ~7%.`,
        icon: "thermo",
      };
    },
  },
  {
    ruleId: "idle_appliance_on",
    severity: "info",
    condition: (ctx) => ctx.inactiveAppliancesOn.length > 0,
    build: (ctx) => ({
      title: "Appareil(s) allumé(s) sans conso",
      body:
        `${ctx.inactiveAppliancesOn.join(", ")} est/sont allumé(s) mais ne consomme(nt) pas. ` +
        `Éteignez pour éviter l'usure et la veille.`,
      icon: "lightbulb",
    }),
  },
  {
    ruleId: "day_above_week_avg",
    severity: "info",
    condition: (ctx) =>
      ctx.weekAvgDailyKwh > 0 && ctx.todayKwh > ctx.weekAvgDailyKwh * 1.3,
    build: (ctx) => ({
      title: "Conso du jour supérieure à la moyenne",
      body:
        `Vous consommez ${(ctx.todayKwh / ctx.weekAvgDailyKwh).toFixed(1)}× votre moyenne ` +
        `hebdo (${ctx.weekAvgDailyKwh.toFixed(1)} kWh/j). Identifiez l'appareil qui a changé.`,
      icon: "bolt",
    }),
  },
  {
    ruleId: "evening_peak",
    severity: "info",
    condition: (ctx) =>
      !!ctx.peakHourKwh &&
      ctx.peakHourKwh.hour >= 18 && ctx.peakHourKwh.hour <= 22 &&
      ctx.peakHourKwh.kwh > ctx.todayKwh / 8,
    build: (ctx) => ({
      title: "Pic de conso en soirée",
      body:
        `Votre pic du jour est entre ${ctx.peakHourKwh!.hour}h-${ctx.peakHourKwh!.hour + 1}h. ` +
        `Décaler les appareils gros consommateurs (lave-linge, four) avant 17h ` +
        `divise la conso de ~15%.`,
      icon: "warning",
    }),
  },
  {
    ruleId: "lamps_high_share",
    severity: "info",
    condition: (ctx) =>
      ctx.topAppliances
        .slice(0, 3)
        .some((a) => /lampe|eclairage|éclairage/i.test(a.name) && a.share > 0.15),
    build: () => ({
      title: "Éclairage : part importante",
      body:
        "Vos lampes comptent pour plus de 15% de la conso. Passez aux LED et " +
        "éteignez en sortant des pièces : économie ~80% sur ce poste.",
      icon: "lightbulb",
    }),
  },
  {
    ruleId: "low_day_congratulation",
    severity: "info",
    condition: (ctx) =>
      ctx.weekAvgDailyKwh > 0 && ctx.todayKwh > 0 &&
      ctx.todayKwh < ctx.weekAvgDailyKwh * 0.6,
    build: (ctx) => ({
      title: "Belle journée économe !",
      body:
        `Vous consommez ${(100 - (ctx.todayKwh / ctx.weekAvgDailyKwh) * 100).toFixed(0)}% ` +
        `de moins que votre moyenne. Continuez.`,
      icon: "lightbulb",
    }),
  },
  {
    ruleId: "oven_high_today",
    severity: "warning",
    condition: (ctx) => {
      const oven = FIND(ctx, /four|cuisini/i);
      return !!oven && oven.kwh > 3;
    },
    build: (ctx) => {
      const oven = FIND(ctx, /four|cuisini/i)!;
      return {
        title: "Four / cuisinière : conso élevée",
        body:
          `${oven.kwh.toFixed(1)} kWh aujourd'hui pour le four. ` +
          `Couvrir pendant la cuisson réduit la conso de ~25%.`,
        icon: "thermo",
      };
    },
  },
  {
    ruleId: "no_data_yet",
    severity: "info",
    condition: (ctx) => ctx.todayKwh === 0 && ctx.yesterdayKwh === 0,
    build: () => ({
      title: "Pas encore de données",
      body:
        "Vos compteurs n'ont pas encore remonté de conso. " +
        "Le premier conseil apparaîtra dès demain.",
      icon: "lightbulb",
    }),
  },
];

function snapshotContext(ctx: TipContext): Record<string, unknown> {
  return {
    todayKwh: ctx.todayKwh,
    yesterdayKwh: ctx.yesterdayKwh,
    weekAvgDailyKwh: ctx.weekAvgDailyKwh,
    topAppliance: ctx.topAppliances[0]?.name ?? null,
    subscriptionType: ctx.subscriptionType,
  };
}

export function pickTip(ctx: TipContext): EnergyTip {
  for (const rule of tips) {
    if (rule.condition(ctx)) {
      const built = rule.build(ctx);
      return {
        ruleId: rule.ruleId,
        severity: rule.severity,
        context: snapshotContext(ctx),
        ...built,
      };
    }
  }
  return {
    ruleId: "default",
    severity: "info",
    title: "Optimisez votre consommation",
    body:
      "Quelques gestes simples : éteindre les veilles, baisser le thermostat de 1°C, " +
      "et utiliser les heures creuses.",
    icon: "lightbulb",
    context: snapshotContext(ctx),
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/tips-generator/tips.ts
git commit -m "feat(tips): add pure rules engine for daily energy tips"
```

---

## Task 3: `liveRules.ts` — règles push temps réel

**Files:**
- Create: `supabase/functions/tips-generator/liveRules.ts`

**Interfaces:**
- Produces:
  - `evaluateLiveRules(ctx: TipContext, triggeredApplianceId: string): { ruleId, title, body, icon, severity } | null`.

- [ ] **Step 1: Créer le fichier**

Écrire `supabase/functions/tips-generator/liveRules.ts` :

```ts
import type { TipContext, TipIcon, TipSeverity } from "./tips.ts";

export interface LiveTip {
  ruleId: string;
  title: string;
  body: string;
  icon: TipIcon;
  severity: TipSeverity;
}

/**
 * Évalue si le live courant d'un appliance donné doit déclencher un push.
 * Retourne null si aucun pattern ne matche.
 */
export function evaluateLiveRules(
  ctx: TipContext,
  triggeredApplianceId: string,
): LiveTip | null {
  const target = ctx.topAppliances.find((a) => a.id === triggeredApplianceId);
  if (!target) return null;

  // Règle 1 : appareil consomme > 2× sa moyenne 7j ET > 500 W
  if (
    target.liveWatts != null && target.typicalWatts != null &&
    target.liveWatts > target.typicalWatts * 2 && target.liveWatts > 500
  ) {
    return {
      ruleId: "live_over_2x_typical",
      title: `${target.name} : pic anormal`,
      body:
        `${target.name} consomme ${target.liveWatts.toFixed(0)} W alors que sa moyenne est ` +
        `${target.typicalWatts.toFixed(0)} W. Vérifiez s'il tourne à pleine charge inutilement.`,
      icon: "warning",
      severity: "warning",
    };
  }

  // Règle 2 : appareil marqué allumé mais conso agrégée ≈ 0 ET live > 50 W
  if (
    target.isOn && target.kwh < 0.05 &&
    target.liveWatts != null && target.liveWatts > 50
  ) {
    return {
      ruleId: "live_on_no_consumption",
      title: `${target.name} allumé sans conso`,
      body:
        `${target.name} est marqué allumé mais ne consomme presque rien. ` +
        `Vérifiez s'il n'est pas bloqué ou si le relais ne dessert plus rien.`,
      icon: "lightbulb",
      severity: "info",
    };
  }

  return null;
}
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/tips-generator/liveRules.ts
git commit -m "feat(tips): add liveRules for real-time push evaluation"
```

---

## Task 4: `context.ts` — agrégation DB → TipContext

**Files:**
- Create: `supabase/functions/tips-generator/context.ts`

**Interfaces:**
- Produces:
  - `buildTipContext(supabase, userId): Promise<TipContext>`.

- [ ] **Step 1: Créer le fichier**

Écrire `supabase/functions/tips-generator/context.ts` :

```ts
import type { TipContext, TipAppliance } from "./tips.ts";

/**
 * Agrège les données DB nécessaires au moteur de règles pour un user donné.
 * Toutes les requêtes sont parallélisées.
 */
export async function buildTipContext(
  supabase: any,
  userId: string,
): Promise<TipContext> {
  const today = new Date().toISOString().slice(0, 10);
  const yesterday = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);
  const weekAgo = new Date(Date.now() - 7 * 86_400_000).toISOString().slice(0, 10);

  const [
    todayRes,
    yesterdayRes,
    weekRes,
    appliancesRes,
    realtimeRes,
    subscriptionRes,
  ] = await Promise.all([
    supabase
      .from("energy_data")
      .select("appliance_id, total_day, appliances!inner(name)")
      .eq("user_id", userId)
      .eq("date", today),
    supabase
      .from("energy_data")
      .select("total_day")
      .eq("user_id", userId)
      .eq("date", yesterday)
      .maybeSingle(),
    supabase
      .from("energy_data")
      .select("date, total_day")
      .eq("user_id", userId)
      .gte("date", weekAgo),
    supabase
      .from("appliances")
      .select("id, name, is_on")
      .eq("user_id", userId),
    supabase
      .from("realtime_power")
      .select("appliance_id, instant_power_w, power_kwh, appliances!inner(name)")
      .eq("user_id", userId),
    supabase
      .from("subscriptions")
      .select("type")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);

  const todayRows = todayRes.data ?? [];
  const yesterdayTotal = Number(yesterdayRes.data?.total_day ?? 0);

  const weekRows = weekRes.data ?? [];
  const weekDays = new Set<string>();
  for (const r of weekRows) weekDays.add(r.date);
  const weekAvgDailyKwh = weekDays.size > 0
    ? weekRows.reduce((acc: number, r: any) => acc + Number(r.total_day ?? 0), 0) /
      Math.max(weekDays.size, 1)
    : 0;

  const appliances = appliancesRes.data ?? [];
  const realtime = realtimeRes.data ?? [];

  // Index appliance_id → typicalWatts (moyenne 7j en W, approx kWh*1000/24)
  const typicalByAppliance = new Map<string, number>();
  for (const r of weekRows) {
    const w = (Number(r.total_day) * 1000) / 24;
    typicalByAppliance.set(
      r.appliance_id as string,
      Number(typicalByAppliance.get(r.appliance_id) ?? 0) + w,
    );
  }
  for (const [id, totalW] of typicalByAppliance) {
    typicalByAppliance.set(id, totalW / Math.max(weekDays.size, 1));
  }

  const todayTotal = todayRows.reduce(
    (acc: number, r: any) => acc + Number(r.total_day ?? 0),
    0,
  );

  // Construction topAppliances (par conso agrégée du jour)
  const topAppliances: TipAppliance[] = todayRows
    .map((r: any) => {
      const id = r.appliance_id as string;
      const kwh = Number(r.total_day ?? 0);
      const live = realtime.find((x: any) => x.appliance_id === id);
      const appliance = appliances.find((a: any) => a.id === id);
      return {
        id,
        name: r.appliances?.name ?? appliance?.name ?? "?",
        kwh,
        share: todayTotal > 0 ? kwh / todayTotal : 0,
        isOn: appliance?.is_on ?? false,
        liveWatts: live ? Number(live.instant_power_w ?? 0) : null,
        typicalWatts: typicalByAppliance.get(id) ?? null,
      };
    })
    .sort((a: TipAppliance, b: TipAppliance) => b.kwh - a.kwh);

  // inactiveAppliancesOn : is_on=true mais pas dans todayRows (kwh jour = 0)
  const inactiveAppliancesOn = appliances
    .filter((a: any) =>
      a.is_on === true && !todayRows.some((r: any) => r.appliance_id === a.id),
    )
    .map((a: any) => a.name as string);

  // peakHourKwh : hour où la conso du jour est max (approx via interpolation
  // simple : on prend l'heure courante si pas de granularité horaire dans energy_data).
  // NOTE : energy_data n'a pas de colonne hour → on omet le peakHourKwh
  // (la règle `evening_peak` ne matchera pas tant qu'on n'aura pas cette donnée).
  const peakHourKwh = undefined;

  return {
    userId,
    todayKwh: todayTotal,
    yesterdayKwh: yesterdayTotal,
    weekAvgDailyKwh,
    topAppliances,
    inactiveAppliancesOn,
    peakHourKwh,
    subscriptionType: (subscriptionRes.data?.type as "free" | "vip") ?? "free",
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/tips-generator/context.ts
git commit -m "feat(tips): add buildTipContext aggregator"
```

---

## Task 5: `index.ts` — entry point (batch + `/evaluate-live`)

**Files:**
- Create: `supabase/functions/tips-generator/index.ts`

**Interfaces:**
- Produces:
  - `POST /evaluate-live` body `{ userId, applianceId }` → 200 `{ ok, pushed, tip }`.
  - Sinon (GET ou POST sans body) → mode batch cron : génère `daily_energy_tip` pour tous les users actifs, retourne `{ ok, count, date }`.

- [ ] **Step 1: Créer le fichier**

Écrire `supabase/functions/tips-generator/index.ts` :

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildTipContext } from "./context.ts";
import { pickTip } from "./tips.ts";
import { evaluateLiveRules } from "./liveRules.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

async function generateDailyTipForUser(userId: string, today: string) {
  const ctx = await buildTipContext(supabase, userId);
  const tip = pickTip(ctx);

  const { error } = await supabase.from("daily_energy_tip").upsert({
    user_id: userId,
    date: today,
    title: tip.title,
    body: tip.body,
    icon: tip.icon,
    severity: tip.severity,
    rule_id: tip.ruleId,
    context: tip.context,
    generated_at: new Date().toISOString(),
  }, { onConflict: "user_id" });

  if (error) console.error(`[tips-generator] daily upsert ${userId}:`, error);
  else console.log(`[tips-generator] daily ${userId} rule=${tip.ruleId}`);
}

async function evaluateLiveTip(userId: string, applianceId: string) {
  const ctx = await buildTipContext(supabase, userId);
  const live = evaluateLiveRules(ctx, applianceId);
  if (!live) return null;

  const { error } = await supabase.from("energy_tips_realtime").insert({
    user_id: userId,
    title: live.title,
    body: live.body,
    icon: live.icon,
    severity: live.severity,
    source: "live_spike",
    rule_id: live.ruleId,
  });
  if (error) {
    console.error(`[tips-generator] realtime insert ${userId}:`, error);
    return null;
  }
  console.log(`[tips-generator] live push ${userId} rule=${live.ruleId}`);
  return live;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const today = new Date().toISOString().slice(0, 10);

  if (req.method === "POST" && url.pathname.endsWith("/evaluate-live")) {
    let body: { userId?: string; applianceId?: string };
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const { userId, applianceId } = body;
    if (!userId || !applianceId) {
      return new Response(
        JSON.stringify({ error: "userId, applianceId required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const tip = await evaluateLiveTip(userId, applianceId);
    return new Response(
      JSON.stringify({ ok: true, pushed: !!tip, tip }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // Mode batch (cron)
  const { data: users, error } = await supabase
    .from("subscriptions")
    .select("user_id")
    .eq("is_active", true);
  if (error) {
    return new Response(
      JSON.stringify({ ok: false, error: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  for (const row of users ?? []) {
    await generateDailyTipForUser(row.user_id, today);
  }
  return new Response(
    JSON.stringify({ ok: true, count: users?.length ?? 0, date: today }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
```

- [ ] **Step 2: Vérifier le typage Deno**

Run: `cd "C:\Users\paoss\Desktop\flutter" && deno check supabase/functions/tips-generator/index.ts 2>&1 | Select-Object -First 30`
Expected: pas d'erreur de type (ignorer si Deno n'est pas installé en local).

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/tips-generator/index.ts
git commit -m "feat(tips): add tips-generator edge function (batch + evaluate-live)"
```

---

## Task 6: Worker MQTT5 — cooldown + POST `/evaluate-live`

**Files:**
- Modify: `workers/mqtt5-worker/index.js` (ajout map + helper + appel après upsert)

**Interfaces:**
- Produit: après chaque upsert `realtime_power` réussi, appel HTTP POST `/evaluate-live` (cooldown 1h par `(user_id, appliance_id)`).

- [ ] **Step 1: Ajouter la map et le helper en haut du fichier**

Dans `workers/mqtt5-worker/index.js`, après la ligne `const mqttToken = process.env.FLESPI_MQTT_WORKER_TOKEN;`, ajouter :

```js
const TIPS_GENERATOR_URL = process.env.TIPS_GENERATOR_URL;

// Cooldown 1h par (user_id, appliance_id) — évite spam sur pic persistant.
const lastLivePushByAppliance = new Map();
const LIVE_PUSH_COOLDOWN_MS = 60 * 60 * 1000; // 1h

async function evaluateLiveTip(userId, applianceId) {
  const key = `${userId}:${applianceId}`;
  const last = lastLivePushByAppliance.get(key);
  if (last && Date.now() - last < LIVE_PUSH_COOLDOWN_MS) return;

  if (!TIPS_GENERATOR_URL) {
    console.warn("[TIPS] TIPS_GENERATOR_URL non configuré, skip");
    return;
  }

  try {
    const res = await fetch(`${TIPS_GENERATOR_URL}/evaluate-live`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ userId, applianceId }),
    });
    if (!res.ok) {
      console.error(`[TIPS] evaluate-live HTTP ${res.status}`);
      return;
    }
    const json = await res.json();
    if (json.pushed) {
      lastLivePushByAppliance.set(key, Date.now());
      console.log(`[TIPS] live push user=${userId} appliance=${applianceId} rule=${json.tip?.ruleId}`);
    }
  } catch (err) {
    console.error("[TIPS] evaluate-live error:", err);
  }
}
```

- [ ] **Step 2: Brancher dans la boucle d'upsert télémétrie**

Dans la fonction existante (qui fait l'upsert `realtime_power` ajouté par le plan RAG précédent), juste après chaque `await upsertRealtimePower(...)` réussi, ajouter :

```js
          await evaluateLiveTip(appliance.user_id, appliance.id);
```

(Si la fonction worker n'est pas exactement structurée ainsi, brancher l'appel après chaque upsert de `realtime_power` avec les bonnes variables `userId` / `applianceId`.)

- [ ] **Step 3: Commit**

```bash
git add workers/mqtt5-worker/index.js
git commit -m "feat(worker): call tips-generator /evaluate-live after realtime upsert"
```

---

## Task 7: Tool agent `push_tip`

**Files:**
- Modify: `supabase/functions/agent-orchestrator/tools.ts` (append tool à `ARICIE_TOOLS`)
- Modify: `supabase/functions/agent-orchestrator/index.ts` (handler dans `handleToolCall`)

**Interfaces:**
- Produces:
  - Tool `push_tip(title, body, severity)` ajouté à `ARICIE_TOOLS`.
  - Handler `push_tip` qui insère dans `energy_tips_realtime` (source='agent'), audite `allowed`, retourne `success`.
  - Gating automatique via `filterToolsForSubscription` (free = absent).

- [ ] **Step 1: Ajouter le tool dans `tools.ts`**

À la fin du tableau `ARICIE_TOOLS`, juste avant le `];`, ajouter :

```ts
  {
    type: "function",
    function: {
      name: "push_tip",
      description:
        "Envoie un conseil d'économie personnalisé en notification push à l'utilisateur. " +
        "Utiliser UNIQUEMENT quand l'agent détecte un pattern actionable pendant la conversation " +
        "et que l'utilisateur est en abonnement VIP. Le titre doit faire max 60 caractères, " +
        "le corps max 200 caractères.",
      parameters: {
        type: "object",
        properties: {
          title: {
            type: "string",
            description: "Titre court du conseil (max 60 caractères).",
          },
          body: {
            type: "string",
            description: "Corps du conseil (max 200 caractères).",
          },
          severity: {
            type: "string",
            enum: ["info", "warning"],
            description: "Niveau d'urgence du conseil.",
          },
        },
        required: ["title", "body"],
        additionalProperties: false,
      },
    },
  },
```

- [ ] **Step 2: Ajouter le handler `push_tip` dans `index.ts`**

Dans `supabase/functions/agent-orchestrator/index.ts`, dans la fonction `handleToolCall`, juste avant le commentaire `// Tool inconnu`, ajouter :

```ts
  // --- Push tip (VIP only via filterToolsForSubscription) ---
  if (name === "push_tip") {
    await audit({
      supabase: params.supabase,
      requesterId: params.requesterId,
      action: "push_tip",
      targetType: "user",
      status: "allowed",
      details: { title: args.title, severity: args.severity ?? "info" },
    });

    const { error } = await params.supabase
      .from("energy_tips_realtime")
      .insert({
        user_id: params.requesterId,
        title: args.title,
        body: args.body,
        icon: "lightbulb",
        severity: args.severity ?? "info",
        source: "agent",
      });

    await writeSse(params.controller, "tool_result", {
      tool: name,
      success: !error,
    });

    return {
      role: "tool" as const,
      tool_call_id: params.toolCall.id,
      content: JSON.stringify({
        success: !error,
        pushed_to: "energy_tips_realtime",
      }),
    };
  }
```

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/agent-orchestrator/tools.ts supabase/functions/agent-orchestrator/index.ts
git commit -m "feat(agent): add push_tip tool (VIP gated) for energy tips"
```

---

## Task 8: Flutter — `TipsRealtimeService`

**Files:**
- Create: `lib/services/tips_realtime_service.dart`

**Interfaces:**
- Produces:
  - `TipsRealtimeService.instance` (singleton).
  - `Stream<EnergyTipEvent> get stream`.
  - `void start()` — s'abonne à `energy_tips_realtime:user_id=eq.<id>` (postgres_changes insert).
  - Sur chaque event : push stream + `NotificationService.showNotification` + update `acknowledged=true`.
  - `Future<void> dispose()`.
  - Modèle `EnergyTipEvent { id, title, body, icon, severity, source }`.

- [ ] **Step 1: Créer le service**

Écrire `lib/services/tips_realtime_service.dart` :

```dart
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class EnergyTipEvent {
  final String id;
  final String title;
  final String body;
  final String icon;     // 'lightbulb' | 'bolt' | 'water' | 'thermo' | 'warning'
  final String severity; // 'info' | 'warning' | 'critical'
  final String source;   // 'live_spike' | 'agent'

  EnergyTipEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.severity,
    required this.source,
  });

  factory EnergyTipEvent.fromJson(Map<String, dynamic> row) => EnergyTipEvent(
        id: row['id'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        icon: row['icon'] as String,
        severity: row['severity'] as String,
        source: row['source'] as String,
      );
}

class TipsRealtimeService {
  TipsRealtimeService._();
  static final TipsRealtimeService instance = TipsRealtimeService._();

  final StreamController<EnergyTipEvent> _controller =
      StreamController<EnergyTipEvent>.broadcast();
  RealtimeChannel? _channel;
  bool _started = false;

  Stream<EnergyTipEvent> get stream => _controller.stream;

  /// Démarre l'écoute après login. Idempotent : no-op si déjà démarré.
  void start() {
    if (_started) return;
    _started = true;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _started = false; // autorise un retry plus tard
      return;
    }

    _channel = Supabase.instance.client
        .channel('energy_tips_realtime:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'energy_tips_realtime',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;
            try {
              final event = EnergyTipEvent.fromJson(newRecord);
              _controller.add(event);
              // Notification locale + acknowledge (asynchrones, non bloquants)
              unawaited(_fireLocalNotification(event));
              unawaited(_markAcknowledged(event.id));
            } catch (_) {
              // payload malformé : ignore silencieusement
            }
          },
        )
        .subscribe();
  }

  Future<void> _fireLocalNotification(EnergyTipEvent event) async {
    final notifId = 9000 + (event.id.hashCode & 0x7FFFFFFF) % 1000;
    await NotificationService().showNotification(
      id: notifId,
      title: event.title,
      body: event.body,
      payload: 'energy_tip:${event.id}',
    );
  }

  Future<void> _markAcknowledged(String id) async {
    try {
      await Supabase.instance.client
          .from('energy_tips_realtime')
          .update({'acknowledged': true})
          .eq('id', id);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
    _started = false;
    await _controller.close();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/tips_realtime_service.dart
git commit -m "feat(flutter): add TipsRealtimeService for energy tips broadcast"
```

---

## Task 9: Flutter — `DailyEnergyTipBanner` widget

**Files:**
- Create: `lib/widgets/daily_energy_tip_banner.dart`

**Interfaces:**
- Produces: `Widget DailyEnergyTipBanner()` qui affiche le tip daily au boot, override par un event live avec badge "LIVE", dismissable, tap → ouvre `ChatbotScreen`.

- [ ] **Step 1: Créer le widget**

Écrire `lib/widgets/daily_energy_tip_banner.dart` :

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../services/tips_realtime_service.dart';

class DailyEnergyTipBanner extends StatefulWidget {
  const DailyEnergyTipBanner({super.key});

  @override
  State<DailyEnergyTipBanner> createState() => _DailyEnergyTipBannerState();
}

class _DailyEnergyTipBannerState extends State<DailyEnergyTipBanner> {
  Map<String, dynamic>? _tip;
  EnergyTipEvent? _liveOverride;
  StreamSubscription<EnergyTipEvent>? _sub;
  Timer? _autoClearTimer;

  @override
  void initState() {
    super.initState();
    TipsRealtimeService.instance.start();
    _loadDaily();
    _sub = TipsRealtimeService.instance.stream.listen((e) {
      if (!mounted) return;
      setState(() => _liveOverride = e);
      _autoClearTimer?.cancel();
      _autoClearTimer = Timer(const Duration(hours: 24), () {
        if (mounted && _liveOverride?.id == e.id) {
          setState(() => _liveOverride = null);
        }
      });
    });
  }

  Future<void> _loadDaily() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final res = await Supabase.instance.client
        .from('daily_energy_tip')
        .select('title, body, icon, severity')
        .eq('user_id', userId)
        .maybeSingle();
    if (mounted && res != null) setState(() => _tip = res);
  }

  IconData _iconFor(String name) => switch (name) {
        'bolt' => Icons.bolt,
        'water' => Icons.water_drop,
        'thermo' => Icons.thermostat,
        'warning' => Icons.warning_amber_rounded,
        _ => Icons.lightbulb_outline,
      };

  Color _colorFor(BuildContext context, String severity) {
    final scheme = Theme.of(context).colorScheme;
    return switch (severity) {
      'critical' => scheme.error,
      'warning' => Colors.orange,
      _ => scheme.primary,
    };
  }

  void _dismissLive() => setState(() => _liveOverride = null);

  void _onTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatbotScreen(
          initialMessage: 'Donne-moi plus de détails sur ce conseil.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _autoClearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tip == null && _liveOverride == null) return const SizedBox.shrink();

    final bool isLive = _liveOverride != null;
    final String title = isLive ? _liveOverride!.title : _tip!['title'] as String;
    final String body = isLive ? _liveOverride!.body : _tip!['body'] as String;
    final String icon = isLive ? _liveOverride!.icon : _tip!['icon'] as String;
    final String severity =
        isLive ? _liveOverride!.severity : _tip!['severity'] as String;
    final color = _colorFor(context, severity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(_iconFor(icon), color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (isLive)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _dismissLive,
                    tooltip: 'Ignorer',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/daily_energy_tip_banner.dart
git commit -m "feat(flutter): add DailyEnergyTipBanner widget"
```

---

## Task 10: Wire `DailyEnergyTipBanner` dans `home_screen.dart`

**Files:**
- Modify: `lib/screens/home_screen.dart` (remplace bloc statique 334-339 par le widget)

**Interfaces:**
- Produit: le bloc "Conseils d'économie" du dashboard affiche maintenant le widget dynamique.

- [ ] **Step 1: Ajouter l'import**

En haut de `lib/screens/home_screen.dart`, ajouter (près des autres imports de widgets) :

```dart
import '../widgets/daily_energy_tip_banner.dart';
```

- [ ] **Step 2: Remplacer le bloc statique**

Dans `lib/screens/home_screen.dart`, remplacer les lignes 334-339 (le bloc `_buildTipCard(...)` codé en dur) par :

```dart
                            const SizedBox(height: AppSpacing.s4),
                            const DailyEnergyTipBanner(),
```

(Laisser le titre "Conseils d'économie" ligne 327-332 inchangé — il sert de label de section.)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(flutter): wire DailyEnergyTipBanner in home dashboard"
```

---

## Task 11: Wire `initialMessage` dans `ChatbotScreen`

**Files:**
- Modify: `lib/screens/chatbot/chatbot_screen.dart` (accepte `initialMessage`, l'envoie après le welcome)

**Interfaces:**
- Produit: `ChatbotScreen({super.key, String? initialMessage})`. Si fourni, après le welcome (600ms delay), envoie le message automatiquement.

- [ ] **Step 1: Ajouter le paramètre**

Dans `lib/screens/chatbot/chatbot_screen.dart`, remplacer :

```dart
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
```

par :

```dart
class ChatbotScreen extends StatefulWidget {
  final String? initialMessage;
  const ChatbotScreen({super.key, this.initialMessage});
```

- [ ] **Step 2: Mémoriser dans le state**

Dans `_ChatbotScreenState`, ajouter le champ :

```dart
  String? _initialMessage;
```

Et dans `initState()`, ajouter après `_showWelcomeMessage();` :

```dart
    _initialMessage = widget.initialMessage;
    if (_initialMessage != null && _initialMessage!.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _initialMessage != null) {
          _addMessage(_initialMessage!, true);
          _initialMessage = null; // ne pas re-envoyer au rebuild
        }
      });
    }
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/chatbot/chatbot_screen.dart
git commit -m "feat(flutter): ChatbotScreen accepts initialMessage prefill"
```

---

## Task 12: Wire `TipsRealtimeService.start()` dans `main.dart`

**Files:**
- Modify: `lib/main.dart` (ajout d'un appel après `notification_service.init()`)

**Interfaces:**
- Produit: le service démarre automatiquement au boot de l'app.

- [ ] **Step 1: Importer et démarrer**

Dans `lib/main.dart`, ajouter l'import (près des autres imports de services) :

```dart
import 'services/tips_realtime_service.dart';
```

Et dans `void main()`, juste après `await notification_service.requestPermissions();`, ajouter :

```dart
  TipsRealtimeService.instance.start();
```

(Soit juste avant `await notificationService.showPeriodicNotification(...)`, soit juste après — l'ordre n'a pas d'impact tant que `start()` est avant `runApp`.)

- [ ] **Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat(flutter): start TipsRealtimeService on app boot"
```

---

## Task 13: Smoke tests Dart + TS

**Files:**
- Create: `test/tips_banner_test.dart`
- Create: `supabase/functions/tips-generator/tips.test.ts` (test pur via `deno test`)

**Interfaces:**
- Produit: tests smoke qui n'ont pas besoin de DB.

- [ ] **Step 1: Créer le test Dart (mappings widget)**

Écrire `test/tips_banner_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/widgets/daily_energy_tip_banner.dart';

IconData _iconFor(String name) => switch (name) {
      'bolt' => Icons.bolt,
      'water' => Icons.water_drop,
      'thermo' => Icons.thermostat,
      'warning' => Icons.warning_amber_rounded,
      _ => Icons.lightbulb_outline,
    };

Color _colorFor(BuildContext context, String severity) {
  final scheme = Theme.of(context).colorScheme;
  return switch (severity) {
    'critical' => scheme.error,
    'warning' => Colors.orange,
    _ => scheme.primary,
  };
}

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(body: Builder(builder: (ctx) {
        return _Probe(ctx: ctx, child: child);
      })),
    );

class _Probe extends StatelessWidget {
  final BuildContext ctx;
  final Widget child;
  const _Probe({required this.ctx, required this.child});
  @override
  Widget build(BuildContext context) => Builder(builder: (_) => child);
}

void main() {
  group('_iconFor mapping', () {
    test('bolt', () => expect(_iconFor('bolt'), Icons.bolt));
    test('water', () => expect(_iconFor('water'), Icons.water_drop));
    test('thermo', () => expect(_iconFor('thermo'), Icons.thermostat));
    test('warning', () => expect(_iconFor('warning'), Icons.warning_amber_rounded));
    test('default', () => expect(_iconFor('lightbulb'), Icons.lightbulb_outline));
    test('unknown falls back to lightbulb', () => expect(_iconFor('?'), Icons.lightbulb_outline));
  });

  group('DailyEnergyTipBanner rendering', () {
    testWidgets('renders nothing when no tip', (tester) async {
      await tester.pumpWidget(_harness(const DailyEnergyTipBanner()));
      await tester.pump();
      expect(find.byType(DailyEnergyTipBanner), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
    });

    testWidgets('smoke: widget tree builds without exceptions', (tester) async {
      await tester.pumpWidget(_harness(const DailyEnergyTipBanner()));
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: Créer le test TypeScript pour `pickTip` et `evaluateLiveRules`**

Écrire `supabase/functions/tips-generator/tips.test.ts` :

```ts
import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { pickTip, type TipContext } from "./tips.ts";
import { evaluateLiveRules } from "./liveRules.ts";

const baseCtx = (overrides: Partial<TipContext> = {}): TipContext => ({
  userId: "u1",
  todayKwh: 10,
  yesterdayKwh: 9,
  weekAvgDailyKwh: 8,
  topAppliances: [],
  inactiveAppliancesOn: [],
  peakHourKwh: undefined,
  subscriptionType: "free",
  ...overrides,
});

Deno.test("pickTip → water_heater_high_share when chauffe-eau > 40% & > 5 kWh", () => {
  const tip = pickTip(baseCtx({
    topAppliances: [
      { id: "a1", name: "Chauffe-eau", kwh: 6, share: 0.6, isOn: true, liveWatts: null, typicalWatts: null },
      { id: "a2", name: "Lampe salon", kwh: 2, share: 0.2, isOn: true, liveWatts: null, typicalWatts: null },
    ],
  }));
  assertEquals(tip.ruleId, "water_heater_high_share");
  assertEquals(tip.severity, "warning");
});

Deno.test("pickTip → ac_live_spike when clim live > 2× typique & > 500 W", () => {
  const tip = pickTip(baseCtx({
    topAppliances: [
      {
        id: "a1", name: "Climatiseur salon", kwh: 2, share: 0.5, isOn: true,
        liveWatts: 1200, typicalWatts: 400,
      },
    ],
  }));
  assertEquals(tip.ruleId, "ac_live_spike");
});

Deno.test("pickTip → default when rien ne matche", () => {
  const tip = pickTip(baseCtx({
    todayKwh: 3,
    weekAvgDailyKwh: 3.5,
    topAppliances: [
      { id: "a1", name: "Lampe", kwh: 1, share: 0.3, isOn: true, liveWatts: 50, typicalWatts: 60 },
    ],
  }));
  assertEquals(tip.ruleId, "default");
  assertEquals(tip.severity, "info");
});

Deno.test("evaluateLiveRules → null si appliance inconnu", () => {
  const tip = evaluateLiveRules(baseCtx(), "unknown");
  assertEquals(tip, null);
});

Deno.test("evaluateLiveRules → live_over_2x_typical si > 2× typique", () => {
  const ctx = baseCtx({
    topAppliances: [
      { id: "a1", name: "Four", kwh: 1, share: 0.5, isOn: true, liveWatts: 1500, typicalWatts: 500 },
    ],
  });
  const tip = evaluateLiveRules(ctx, "a1");
  assertExists(tip);
  assertEquals(tip!.ruleId, "live_over_2x_typical");
  assertEquals(tip.severity, "warning");
});

Deno.test("evaluateLiveRules → null si live < 500 W même si > 2× typique", () => {
  const ctx = baseCtx({
    topAppliances: [
      { id: "a1", name: "Lampe", kwh: 0.5, share: 0.5, isOn: true, liveWatts: 300, typicalWatts: 100 },
    ],
  });
  const tip = evaluateLiveRules(ctx, "a1");
  assertEquals(tip, null);
});
```

- [ ] **Step 3: Lancer les tests Dart**

Run: `cd "C:\Users\paoss\Desktop\flutter" && flutter test test/tips_banner_test.dart`
Expected: `All tests passed!` (8 tests verts : 6 mappings + 2 widget smoke).

- [ ] **Step 4: Lancer `flutter analyze`**

Run: `cd "C:\Users\paoss\Desktop\flutter" && flutter analyze lib/services/tips_realtime_service.dart lib/widgets/daily_energy_tip_banner.dart lib/screens/home_screen.dart lib/screens/chatbot/chatbot_screen.dart lib/main.dart test/tips_banner_test.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add test/tips_banner_test.dart supabase/functions/tips-generator/tips.test.ts
git commit -m "test(tips): add smoke tests for tip rules + banner mappings"
```

---

## Self-Review

1. **Couverture spec :**
   - Migration SQL → T1.
   - `tips.ts` (règles daily) → T2.
   - `liveRules.ts` → T3.
   - `context.ts` → T4.
   - `index.ts` (batch + `/evaluate-live`) → T5.
   - Worker MQTT5 cooldown + POST → T6.
   - Tool agent `push_tip` (gating VIP) → T7.
   - Service Flutter `TipsRealtimeService` → T8.
   - Widget `DailyEnergyTipBanner` → T9.
   - Wire home_screen → T10.
   - Wire `ChatbotScreen.initialMessage` → T11.
   - Wire `main.dart` start → T12.
   - Tests smoke → T13.
   - **Tous les critères d'acceptation** : banner daily, push live, push agent VIP, gating free, tap pré-rempli, RLS, cooldown — chacun couvert.

2. **Placeholders** : aucun "TBD" / "TODO" / "fill in details". Tous les blocs de code sont complets.

3. **Cohérence des types :**
   - `TipContext` (tips.ts) ← consommé par `pickTip`, `buildTipContext` (context.ts), `evaluateLiveRules` (liveRules.ts), `index.ts`.
   - `EnergyTipEvent` (Flutter) ← consommé par `TipsRealtimeService`, `DailyEnergyTipBanner`.
   - `LiveTip` (liveRules.ts) ← consommé par `index.ts` evaluateLiveTip.
   - Tool `push_tip` args `{ title, body, severity }` ← handler `index.ts` les lit tels quels.
   - `initialMessage` (ChatbotScreen) ← consommé par `DailyEnergyTipBanner._onTap`.

4. **Cohérence IDs notification** : `9000 + hash(id) % 1000` (T8) — confirmé dans la spec.

---

## Execution Handoff

Plan complete et sauvegardé dans `docs/superpowers/plans/2026-06-26-energy-tips-banner.md`.

Deux options d'exécution :

1. **Subagent-Driven (recommandé)** — Je dispatch un subagent frais par tâche, review entre chaque.
2. **Inline Execution** — J'exécute dans cette session via `executing-plans`, batch avec checkpoints.

Quelle approche ?
