// Edge Function admin-api — utilitaires HTTP (CORS, JSON, pagination)
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.1

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
};

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Format d'erreur du cahier des charges : { error: { code, message } }
export function jsonError(
  code: string,
  message: string,
  status = 400,
): Response {
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export type Pagination = {
  page: number;
  pageSize: number;
  from: number; // offset SQL
  to: number; // offset + pageSize - 1
};

// ?page=1&page_size=50 (page_size plafonné à 200)
export function parsePagination(url: URL): Pagination {
  const page = Math.max(
    1,
    parseInt(url.searchParams.get("page") ?? "1", 10) || 1,
  );
  const rawSize = parseInt(url.searchParams.get("page_size") ?? "50", 10) || 50;
  const pageSize = Math.min(200, Math.max(1, rawSize));
  const from = (page - 1) * pageSize;
  return { page, pageSize, from, to: from + pageSize - 1 };
}

export function paginated<T>(
  data: T[],
  total: number,
  p: Pagination,
): { data: T[]; page: number; page_size: number; total: number } {
  return { data, page: p.page, page_size: p.pageSize, total };
}

export class HttpError extends Error {
  constructor(
    public code: string,
    message: string,
    public status = 400,
  ) {
    super(message);
  }
}

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    .test(value);
}
