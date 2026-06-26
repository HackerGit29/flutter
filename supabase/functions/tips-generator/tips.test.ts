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
      { id: "a1", name: "Lampe", kwh: 1, share: 0.1, isOn: true, liveWatts: 50, typicalWatts: 60 },
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
