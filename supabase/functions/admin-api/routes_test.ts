import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { csvCell, toCsv } from "./csv.ts";
import {
  isValidExportStatus,
  validateCsvExportInput,
  validateExportDateRange,
} from "./operations.ts";
import { normalizeZoneInput } from "./zone_validation.ts";

Deno.test("toCsv escapes quotes and wraps values containing delimiters or newlines", () => {
  assertEquals(
    toCsv(["name", "note"], [{ name: "Lyon; Est", note: 'a "quote"\nnext' }]),
    'name;note\r\n"Lyon; Est";"a ""quote""\nnext"',
  );
});

Deno.test("csvCell prevents formula execution in untrusted text", () => {
  assertEquals(csvCell("=1+1"), "'=1+1");
  assertEquals(csvCell("-3.5"), "'-3.5");
  assertEquals(csvCell(3.5), "3.5");
});

Deno.test("CSV export status filters are restricted to each dataset's status domain", () => {
  assertEquals(isValidExportStatus("users", "active"), true);
  assertEquals(isValidExportStatus("boxes", "blocked"), true);
  assertEquals(isValidExportStatus("commands", "timeout"), true);
  assertEquals(isValidExportStatus("users", "timeout"), false);
  assertEquals(isValidExportStatus("energy", "active"), false);
});

Deno.test("CSV export request rejects unsupported formats, datasets, and filters", () => {
  assertThrows(() => validateCsvExportInput({ dataset: "nope" }));
  assertThrows(() =>
    validateCsvExportInput({ dataset: "users", format: "xlsx" })
  );
  assertThrows(() =>
    validateCsvExportInput({
      dataset: "users",
      filters: { arbitrary_column: "x" },
    })
  );
  assertThrows(() =>
    validateCsvExportInput({ dataset: "users", filters: { status: "timeout" } })
  );
  assertThrows(() =>
    validateCsvExportInput({
      dataset: "users",
      filters: { box_id: "123e4567-e89b-12d3-a456-426614174000" },
    })
  );
  assertThrows(() =>
    validateCsvExportInput({
      dataset: "energy",
      filters: { from: "2026-01-01" },
    })
  );
  assertThrows(() =>
    validateCsvExportInput({
      dataset: "energy",
      filters: { from: "2025-01-01", to: "2026-01-03" },
    })
  );
  validateCsvExportInput({
    dataset: "energy",
    format: "csv",
    filters: {
      user_id: "123e4567-e89b-12d3-a456-426614174000",
      from: "2026-01-01",
      to: "2026-01-31",
    },
  });
});

Deno.test("energy export requires a date window no longer than 366 days", () => {
  assertThrows(() => validateExportDateRange("energy", null, null));
  assertThrows(() =>
    validateExportDateRange("energy", "2025-01-01", "2026-01-03")
  );
  assertThrows(() =>
    validateExportDateRange("users", "2025-02-01", "2025-01-01")
  );
  validateExportDateRange("energy", "2026-01-01", "2026-01-31");
  validateExportDateRange("users", null, null);
  validateCsvExportInput({
    dataset: "users",
    filters: {
      from: "2026-01-15T12:30:00+02:00",
      to: "2026-01-16T12:30:00Z",
    },
  });
  assertThrows(() =>
    validateCsvExportInput({
      dataset: "users",
      filters: { from: "2026-02-30" },
    })
  );
});

Deno.test("normalizeZoneInput accepts valid fields and applies defaults", () => {
  assertEquals(
    normalizeZoneInput({
      name: "Lyon Est",
      center_lat: 45.75,
      center_lng: 4.85,
      radius_km: 15,
    }),
    {
      name: "Lyon Est",
      center_lat: 45.75,
      center_lng: 4.85,
      radius_km: 15,
      target_clients: 0,
      is_active: true,
    },
  );
});

Deno.test("normalizeZoneInput rejects coordinates outside valid ranges", () => {
  assertThrows(() =>
    normalizeZoneInput({
      name: "Invalid",
      center_lat: 91,
      center_lng: 0,
      radius_km: 1,
    })
  );
});

Deno.test("normalizeZoneInput rejects unknown patch fields and empty patches", () => {
  assertThrows(() => normalizeZoneInput({}, true));
  assertThrows(() => normalizeZoneInput({ id: "not-allowed" }, true));
});
