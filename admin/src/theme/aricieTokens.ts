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

/** Palette claire (surfaces + texte), alignée sur AppColors. */
export const lightColors = {
  /** Fond applicatif — légèrement bleuté pour détacher les cartes. */
  bgApp: '#C8D9E0',
  /** Surface principale (cartes, feuilles). */
  bgPrimary: '#FFFFFF',
  /** Surface secondaire (zones encadrées, lignes de tableau alternées). */
  bgSecondary: '#F0F6F8',
  /** Surface tertiaire (champs, puces, boutons d'icône neutres). */
  bgTertiary: '#E8F2F5',

  textPrimary: '#1A2530',
  textSecondary: '#4A5A68',
  textMuted: '#8A9AAA',
  textInverse: '#FFFFFF',

  /** Couleur d'action principale (boutons pleins, nav active). */
  interactive: '#1A3A4A',
  /** Seed documenté — teinte de marque pour l'accentuation graphique. */
  seed: '#4A6572',

  borderSubtle: 'rgba(26, 58, 74, 0.08)',
  shadowCard: 'rgba(26, 58, 74, 0.08)',
} as const;

/** Palette sombre (surfaces + texte), alignée sur AppColors.dark*. */
export const darkColors = {
  bgApp: '#1A2530',
  bgPrimary: '#2A3540',
  bgSecondary: '#354050',
  bgTertiary: '#3A4555',

  textPrimary: '#E8EDF0',
  textSecondary: '#A8B5C0',
  textMuted: '#6A7A8A',
  /** Sur fond sombre, le texte posé sur l'action principale reste le noir de la palette claire. */
  textInverse: '#1A2530',

  /** Skip the dark theme's interactive teal, one step lighter for AA contrast. */
  interactive: '#4A7A8A',
  seed: '#4A6572',

  borderSubtle: 'rgba(232, 237, 240, 0.08)',
  shadowCard: 'rgba(0, 0, 0, 0.24)',
} as const;

/* ------------------------------------------------------------------ */
/* Accents pastels (identiques dans les deux modes)                    */
/* ------------------------------------------------------------------ */

/** Accents pastels de la charte — utilisés pour les catégories et badges. */
export const accents = {
  teal: '#1A3A4A',
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
  /** Ombres du mode sombre — plus opaques, les ombres claires n'y lisent pas. */
  darkSm: '0 2px 8px rgba(0, 0, 0, 0.28)',
  darkMd: '0 4px 16px rgba(0, 0, 0, 0.36)',
  darkLg: '0 8px 32px rgba(0, 0, 0, 0.44)',
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
