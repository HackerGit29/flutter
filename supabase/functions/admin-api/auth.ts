// Edge Function admin-api — authentification + RBAC
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.1 / §7
//
// Deux garde-fous successifs :
//   1. Vérification du JWT Supabase (getUser via client anon scopeé sur le token)
//   2. Lecture du rôle + admin_level dans public.users (client service_role,
//      uniquement après le step 1 — le user_id vient toujours du JWT,
//      jamais du body : principe de sécurité du projet)
//
// Niveaux : viewer (lecture) < operator (écritures ops) < super_admin
// Rétro-compat : un compte role='admin' sans admin_level renseigné est
// traité en 'super_admin' (les admins historiques créés avant la migration
// 20261026000002 ne sont pas bloqués).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { HttpError } from "./http.ts";

export type AdminLevel = "viewer" | "operator" | "super_admin";

const LEVEL_RANK: Record<AdminLevel, number> = {
  viewer: 0,
  operator: 1,
  super_admin: 2,
};

export type AdminContext = {
  adminId: string;
  email: string;
  level: AdminLevel;
};

/** Client anon scopé sur le JWT de la requête (utilisé pour auth.getUser). */
export function createUserClient(req: Request) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  return createClient(supabaseUrl, anonKey, {
    global: {
      headers: { Authorization: req.headers.get("Authorization") ?? "" },
    },
  });
}

/** Client service_role — réservé aux Edge Functions après vérif admin. */
export function createAdminClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  return createClient(supabaseUrl, serviceRoleKey);
}

/**
 * Authentifie l'appelant et vérifie qu'il est admin au niveau requis.
 * Lance HttpError(401/403) sinon.
 */
export async function requireAdmin(
  req: Request,
  minLevel: AdminLevel,
): Promise<AdminContext> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new HttpError("unauthorized", "Token d'authentification manquant", 401);
  }

  const userClient = createUserClient(req);
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) {
    throw new HttpError("unauthorized", "Token invalide ou expiré", 401);
  }

  // Lecture du profil admin via service_role (le user_id vient du JWT vérifié)
  const admin = createAdminClient();
  const { data: profile, error: profileError } = await admin
    .from("users")
    .select("role, status, admin_level, email")
    .eq("id", user.id)
    .single();

  if (profileError || !profile) {
    throw new HttpError("forbidden", "Profil introuvable", 403);
  }
  if (profile.role !== "admin") {
    throw new HttpError("forbidden", "Accès réservé aux administrateurs", 403);
  }
  if (profile.status !== "active") {
    throw new HttpError("forbidden", "Compte administrateur suspendu", 403);
  }

  // Rétro-compat : admin sans admin_level = super_admin (admin historique)
  const level = (profile.admin_level ?? "super_admin") as AdminLevel;
  if (!(level in LEVEL_RANK)) {
    throw new HttpError("forbidden", "Niveau admin invalide", 403);
  }

  if (LEVEL_RANK[level] < LEVEL_RANK[minLevel]) {
    throw new HttpError(
      "forbidden",
      `Niveau insuffisant : ${minLevel} requis (vous : ${level})`,
      403,
    );
  }

  return { adminId: user.id, email: profile.email ?? "", level };
}
