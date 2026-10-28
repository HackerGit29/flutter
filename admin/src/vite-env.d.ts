/// <reference types="vite/client" />

/**
 * Variables injectées par le build.
 *
 * `__APP_VERSION__` est remplacé statiquement par Vite (cf. `vite.config.ts`,
 * qui lit la version canonique dans `pubspec.yaml`).
 */
declare const __APP_VERSION__: string;

/** Variables d'environnement exposées au front (préfixe `VITE_` obligatoire). */
interface ImportMetaEnv {
  /** URL du projet Supabase, ex. `https://xxxx.supabase.co`. */
  readonly VITE_SUPABASE_URL: string;
  /** Clé publique anon — jamais la clé service_role. */
  readonly VITE_SUPABASE_ANON_KEY: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
