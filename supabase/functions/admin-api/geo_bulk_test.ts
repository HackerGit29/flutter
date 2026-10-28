import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { normalizeGeoItems } from "./geo_bulk_validation.ts";
import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("normalizeGeoItems maps API coordinate names to database columns", () => {
  assertEquals(
    normalizeGeoItems({
      items: [{
        box_id: "123e4567-e89b-12d3-a456-426614174000",
        lat: 48.85,
        lng: 2.35,
        precision: "approx",
      }],
    }),
    [{
      box_id: "123e4567-e89b-12d3-a456-426614174000",
      latitude: 48.85,
      longitude: 2.35,
      geo_precision: "approx",
    }],
  );
});

Deno.test("normalizeGeoItems rejects invalid coordinates, precision, and duplicate boxes", () => {
  assertThrows(() =>
    normalizeGeoItems({
      items: [{
        box_id: "123e4567-e89b-12d3-a456-426614174000",
        lat: 91,
        lng: 0,
        precision: "approx",
      }],
    })
  );
  assertThrows(() =>
    normalizeGeoItems({
      items: [{
        box_id: "123e4567-e89b-12d3-a456-426614174000",
        lat: 0,
        lng: 0,
        precision: "approximate",
      }],
    })
  );
  const item = {
    box_id: "123e4567-e89b-12d3-a456-426614174000",
    lat: 0,
    lng: 0,
    precision: "city",
  };
  assertThrows(() => normalizeGeoItems({ items: [item, item] }));
});
