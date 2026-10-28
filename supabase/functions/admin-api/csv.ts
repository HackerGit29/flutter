const FORMULA_PREFIX = /^[\s\u0000-\u001f]*[=+@-]/;

/** Prefixes spreadsheet formulas with an apostrophe before CSV quoting. */
export function csvCell(value: unknown): string {
  if (value === null || value === undefined) return "";
  const isString = typeof value === "string";
  let text = isString ? value : JSON.stringify(value);
  if (isString && FORMULA_PREFIX.test(text)) text = `'${text}`;
  if (/[;"\r\n]/.test(text)) return `"${text.replaceAll('"', '""')}"`;
  return text;
}

export function toCsv(
  columns: string[],
  rows: Record<string, unknown>[],
): string {
  return [
    columns.map(csvCell).join(";"),
    ...rows.map((row) =>
      columns.map((column) => csvCell(row[column])).join(";")
    ),
  ].join("\r\n");
}
