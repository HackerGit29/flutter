/**
 * Tokens du design system aricie — source de vérité partagée.
 *
 * Miroir exact de `lib/theme/app_theme.dart` (app mobile) pour que le
 * backoffice et l'app client parlent la même langue visuelle, complété par
 * les deux valeurs imposées par le cahier des charges §8 :
 *   - seed  `#4A6572`
 *   - accent `rgb(121, 207, 244)` = `#79CFF4` (schémas système, cartes)
 *
 * Règle : ne jamais écrire un hex directement dans un composant.
 * Toujours passer par le thème MUI (`theme.palette.*`, `theme.alpha.*`)
 * ou, pour les accents pastels, par `theme.aricie.*`.
 */

/* ------------------------------------------------------------------ */
/* Couleurs de base                                                    */
/* ------------------------------------------------------------------ */

/**
 * Palette de surfaces et de texte.
 *
 * Le backoffice n'a qu'un seul mode : blanc. Pas de variante sombre, donc
 * aucun fond bleu nuit — la charte repose sur un fond blanc et un accent vert
 * d'eau unique.
 */
export const lightColors = {
  /** Fond applicatif — blanc pur : le backoffice est épuré, sans aplat bleuté. */
  bgApp: '#FFFFFF',
  /** Surface principale (cartes, feuilles). */
  bgPrimary: '#FFFFFF',
  /** Surface secondaire (zones encadrées, lignes de tableau alternées). */
  bgSecondary: '#F3F8F9',
  /** Surface tertiaire (champs, puces, boutons d'icône neutres). */
  bgTertiary: '#E9F2F4',

  textPrimary: '#14262E',
  textSecondary: '#4C6270',
  textMuted: '#7E939D',
  textInverse: '#FFFFFF',

  /** Vert d'eau — couleur d'action unique (boutons pleins, nav active, accents). */
  interactive: '#4A7A8A',
  /** Même vert d'eau : une seule teinte d'accentuation dans tout le backoffice. */
  seed: '#4A7A8A',

  borderSubtle: 'rgba(74, 122, 138, 0.16)',
  shadowCard: 'rgba(20, 58, 72, 0.10)',
} as const;

/* ------------------------------------------------------------------ */
/* Accents pastels                                                     */
/* ------------------------------------------------------------------ */

/** Accents pastels de la charte — utilisés pour les catégories et badges. */
export const accents = {
  teal: '#4A7A8A',
  pink: '#F0B8C8',
  purple: '#C8A8D8',
  sage: '#A8C8A8',
  coral: '#E8C0A8',
  blue: '#A8C8E0',
  mint: '#B8E0D0',
  gold: '#F5C842',
  /** Pastille d'alerte. */
  dot: '#E8506A',
  /** Accent documenté — schémas système, tracés de carte, halos. */
  accent: '#79CFF4',
} as const;

/** Couleurs sémantiques. */
export const semantic = {
  success: '#4E9A6A',
  successLight: '#A8C8A8',
  warning: '#F5C842',
  warningDeep: '#C99A2E',
  error: '#E8506A',
  info: '#79CFF4',
  infoDeep: '#1A3A4A',
} as const;

/* ------------------------------------------------------------------ */
/* Rayons (AppRadius)                                                  */
/* ------------------------------------------------------------------ */

export const radius = {
  xs: 6,
  sm: 10,
  md: 14,
  lg: 20,
  xl: 24,
  xxl: 32,
  full: 9999,
} as const;

/* ------------------------------------------------------------------ */
/* Espacements (AppSpacing)                                            */
/* ------------------------------------------------------------------ */

export const spacing = {
  s1: 4,
  s2: 8,
  s3: 12,
  s4: 16,
  s5: 20,
  s6: 24,
  s7: 28,
  s8: 32,
  s10: 40,
  s12: 48,
  s16: 64,
} as const;

/* ------------------------------------------------------------------ */
/* Ombres (AppShadows)                                                 */
/* ------------------------------------------------------------------ */

const shadowRgb = '26, 58, 74';

export const shadows = {
  xs: `0 1px 3px rgba(${shadowRgb}, 0.06)`,
  sm: `0 2px 8px rgba(${shadowRgb}, 0.08)`,
  md: `0 4px 16px rgba(${shadowRgb}, 0.10)`,
  lg: `0 8px 32px rgba(${shadowRgb}, 0.12)`,
  float: `0 16px 48px rgba(${shadowRgb}, 0.16)`,
} as const;

/* ------------------------------------------------------------------ */
/* Typographie                                                         */
/* ------------------------------------------------------------------ */

/** DM Sans porte tout le texte ; DM Serif Display les grands titres. */
export const fonts = {
  sans: '"DM Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  serif: '"DM Serif Display", Georgia, "Times New Roman", serif',
  mono: '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace',
} as const;

/* ------------------------------------------------------------------ */
/* Formats (FR par défaut)                                             */
/* ------------------------------------------------------------------ */

export const formats = {
  locale: 'fr-FR',
  /** 1 EUR = 655,957 XAF (parité fixe BEAC). */
  xafPerEur: 655.957,
} as const;
