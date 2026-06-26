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
