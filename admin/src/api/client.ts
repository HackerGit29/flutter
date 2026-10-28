import { ADMIN_API_BASE, ANON_KEY, getSupabase } from './supabaseClient';
import type { ApiErrorBody, Paginated } from '../types/admin';

/**
 * Client HTTP de l'Edge Function `admin-api`.
 *
 * Responsabilités :
 *  - préfixer toutes les routes par `/v1` ;
 *  - joindre le JWT Supabase de la session courante (`Authorization: Bearer`)
 *    et la clé anon (`apikey`) ;
 *  - normaliser les erreurs du backend (`{ error: { code, message } }`) en
 *    `AdminApiError` typée, pour que les composants n'aient jamais à
 *    inspecter des réponses HTTP brutes ;
 *  - déconnecter l'utilisateur si le jeton est refusé (401), pour éviter une
 *    boucle d'appels voués à l'échec.
 */

export class AdminApiError extends Error {
  constructor(
    /** Code métier renvoyé par l'API (`forbidden`, `validation_error`…). */
    public readonly code: string,
    message: string,
    public readonly status: number,
  ) {
    super(message);
    this.name = 'AdminApiError';
  }

  /** Vrai si l'erreur vient d'un manque de droits (le front doit masquer l'action). */
  get isForbidden(): boolean {
    return this.status === 403;
  }

  /** Vrai si la session n'est plus valide. */
  get isUnauthorized(): boolean {
    return this.status === 401;
  }
}

type QueryValue = string | number | boolean | null | undefined;

/** Assemble une query string en ignorant les valeurs vides. */
export function toQuery(params?: Record<string, QueryValue>): string {
  if (!params) return '';
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === '') continue;
    search.set(key, String(value));
  }
  const qs = search.toString();
  return qs ? `?${qs}` : '';
}

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  /** Corps JSON. */
  body?: unknown;
  /** Paramètres de requête. */
  query?: Record<string, QueryValue>;
  /** Signal d'annulation fourni par TanStack Query. */
  signal?: AbortSignal;
}

async function currentAccessToken(): Promise<string | null> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error) return null;
  return data.session?.access_token ?? null;
}

/**
 * Appelle `admin-api` et renvoie la réponse désérialisée.
 *
 * @throws {AdminApiError} sur toute réponse non 2xx.
 */
export async function adminFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  if (!ADMIN_API_BASE) {
    throw new AdminApiError(
      'not_configured',
      'Supabase n\'est pas configuré (VITE_SUPABASE_URL manquant).',
      0,
    );
  }

  const token = await currentAccessToken();
  if (!token) {
    throw new AdminApiError('unauthorized', 'Session expirée, reconnectez-vous.', 401);
  }

  const url = `${ADMIN_API_BASE}/v1${path}${toQuery(options.query)}`;

  let response: Response;
  try {
    response = await fetch(url, {
      method: options.method ?? 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        apikey: ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
      signal: options.signal,
    });
  } catch (error) {
    // Annulation volontaire (TanStack Query) : on laisse remonter tel quel.
    if (error instanceof DOMException && error.name === 'AbortError') throw error;
    throw new AdminApiError('network_error', 'Réseau indisponible. Réessayez.', 0);
  }

  // 204 / corps vide
  if (response.status === 204) return undefined as T;

  const raw = await response.text();
  const payload = raw ? safeJson(raw) : null;

  if (!response.ok) {
    const body = payload as ApiErrorBody | null;
    const code = body?.error?.code ?? `http_${response.status}`;
    const message = body?.error?.message ?? `Erreur ${response.status}`;

    // Le jeton a été refusé : on invalide la session locale pour forcer la
    // reconnexion au lieu de laisser la page marteler l'API.
    if (response.status === 401) {
      await getSupabase().auth.signOut().catch(() => undefined);
    }

    throw new AdminApiError(code, message, response.status);
  }

  return payload as T;
}

function safeJson(raw: string): unknown {
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

/** Helper de pagination typé, pour `Paginated<T>`. */
export function adminList<T>(
  path: string,
  options: RequestOptions = {},
): Promise<Paginated<T>> {
  return adminFetch<Paginated<T>>(path, options);
}
