// Edge Function admin-api — routeur
// Ref: docs/cahier-des-charges-admin-dashboard.md §5
//
// Déploiement : supabase functions deploy admin-api
// Auth : JWT Supabase + rôle admin vérifié dans chaque handler (requireAdmin).
// Le user_id vient toujours du JWT, jamais du body (principe du projet).
//
// Routes :
//   GET   /v1/kpi/summary
//   GET   /v1/kpi/timeseries
//   GET   /v1/users
//   GET   /v1/users/:id
//   GET   /v1/users/:id/timeline
//   PATCH /v1/users/:id/status
//   PATCH /v1/users/:id/role
//   GET   /v1/boxes
//   GET   /v1/boxes/:id
//   POST  /v1/boxes
//   PATCH /v1/boxes/:id
//   POST  /v1/boxes/:id/assign
//   POST  /v1/boxes/:id/reset
//   POST  /v1/boxes/:id/force-sync

import { corsHeaders, HttpError, jsonError } from "./http.ts";
import { requireAdmin, type AdminLevel } from "./auth.ts";
import { handleKpiSummary, handleKpiTimeseries } from "./kpi.ts";
import {
  handleGetUser,
  handleListUsers,
  handleUpdateUserRole,
  handleUpdateUserStatus,
  handleUserTimeline,
} from "./users.ts";
import {
  handleAssignBox,
  handleCreateBox,
  handleForceSync,
  handleGetBox,
  handleListBoxes,
  handleResetBox,
  handleUpdateBox,
} from "./boxes.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    // Chemin après /admin-api : /v1/...
    const parts = url.pathname.replace(/^.*?\/admin-api/, "").split("?")[0]
      .split("/").filter(Boolean);
    // parts = ["v1", "kpi", "summary"] ou ["v1", "users", ":id", ...]
    if (parts[0] !== "v1") {
      return jsonError("not_found", "Route inconnue (préfixe /v1 attendu)", 404);
    }
    const [resource, id, sub] = parts.slice(1);
    const method = req.method;

    // ---- KPI (viewer+) ----
    if (resource === "kpi" && id === "summary" && method === "GET") {
      await requireAdmin(req, "viewer");
      return await handleKpiSummary(url);
    }
    if (resource === "kpi" && id === "timeseries" && method === "GET") {
      await requireAdmin(req, "viewer");
      return await handleKpiTimeseries(url);
    }

    // ---- Users ----
    if (resource === "users") {
      if (!id && method === "GET") {
        const ctx = await requireAdmin(req, "viewer");
        return await handleListUsers(url, ctx);
      }
      if (id && !sub && method === "GET") {
        const ctx = await requireAdmin(req, "viewer");
        return await handleGetUser(id, ctx);
      }
      if (id && sub === "timeline" && method === "GET") {
        const ctx = await requireAdmin(req, "viewer");
        return await handleUserTimeline(id, ctx, url.searchParams.get("limit"));
      }
      if (id && sub === "status" && method === "PATCH") {
        const ctx = await requireAdmin(req, "operator");
        return await handleUpdateUserStatus(id, await readBody(req), ctx);
      }
      if (id && sub === "role" && method === "PATCH") {
        const ctx = await requireAdmin(req, "super_admin");
        return await handleUpdateUserRole(id, await readBody(req), ctx);
      }
    }

    // ---- Boxes ----
    if (resource === "boxes") {
      if (!id && method === "GET") {
        const ctx = await requireAdmin(req, "viewer");
        return await handleListBoxes(url, ctx);
      }
      if (id && !sub && method === "GET") {
        const ctx = await requireAdmin(req, "viewer");
        return await handleGetBox(id, ctx);
      }
      if (!id && method === "POST") {
        const ctx = await requireAdmin(req, "operator");
        return await handleCreateBox(await readBody(req), ctx);
      }
      if (id && !sub && method === "PATCH") {
        const ctx = await requireAdmin(req, "operator");
        return await handleUpdateBox(id, await readBody(req), ctx);
      }
      if (id && sub === "assign" && method === "POST") {
        const ctx = await requireAdmin(req, "operator");
        return await handleAssignBox(id, await readBody(req), ctx);
      }
      if (id && sub === "reset" && method === "POST") {
        const ctx = await requireAdmin(req, "super_admin");
        return await handleResetBox(id, ctx);
      }
      if (id && sub === "force-sync" && method === "POST") {
        const ctx = await requireAdmin(req, "operator");
        return await handleForceSync(id, ctx);
      }
    }

    return jsonError(
      "not_found",
      `Route inconnue: ${method} /v1/${resource ?? ""}${id ? `/${id}` : ""}${sub ? `/${sub}` : ""}`,
      404,
    );
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonError(error.code, error.message, error.status);
    }
    console.error("admin-api unhandled error:", error);
    return jsonError("internal_error", "Erreur interne", 500);
  }
});

async function readBody(req: Request): Promise<unknown> {
  try {
    return await req.json();
  } catch {
    return null;
  }
}
