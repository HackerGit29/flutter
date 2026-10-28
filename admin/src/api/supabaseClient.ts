import { createClient, type SupabaseClient } from '@supabase/supabase-js';

/**
 * Client Supabase du backoffice.
 *
 * Utilisé **uniquement** pour l'authentification (email/mot de passe, refresh
 * de session, TOTP) et éventuellement les abonnements Realtime.
 *
 * Aucune lecture de données métier ne passe par ici : tout est servi par
 * l'Edge Function `admin-api`, qui applique le contrôle de rôle côté serveur
 * (`service_role`). La clé utilisée ici est la clé **anon publique** ; la clé
 * `service_role` ne doit jamais atteindre le navigateur.
 *
 * Si les variables manquent, on échoue au démarrage avec un message
 * explicite plutôt que de laisser l'app tenter des appels vers `undefined`.
 */

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

/** Debug: true si la configuration est incomplète. */
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

function buildClient(): SupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(
      'Configuration Supabase manquante : renseignez VITE_SUPABASE_URL et VITE_SUPABASE_ANON_KEY ' +
        '(fichier .env.local en développement, variables de build sur Cloudflare Pages).',
    );
  }

  return createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      flowType: 'pkce',
    },
  });
}

/**
 * Instance unique.
 *
 * Créée paresseusement : tant que la configuration est absente, l'application
 * peut afficher un écran d'erreur explicite au lieu de planter à l'import.
 */
let client: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient {
  if (!client) client = buildClient();
  return client;
}

/** Base URL de l'Edge Function `admin-api`. */
export const ADMIN_API_BASE = supabaseUrl ? `${supabaseUrl}/functions/v1/admin-api` : '';

/** Clé anon, nécessaire dans le header `apikey` de chaque appel à l'Edge Function. */
export const ANON_KEY = supabaseAnonKey ?? '';
