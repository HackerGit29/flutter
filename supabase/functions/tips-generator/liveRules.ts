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
