/**
 * Thème MUI du backoffice aricie — mode clair **et** sombre.
 *
 * Construit sur les tokens de `aricieTokens.ts` (eux-mêmes alignés sur
 * `lib/theme/app_theme.dart` de l'app mobile).
 *
 * Architecture : thème à variables CSS (`cssVariables: true`). Chaque
 * `colorSchemes.{light,dark}` génère une série de variables
 * `--mui-palette-*`, résolues par MUI selon la classe posée sur `<html>`
 * (`colorSchemeSelector: 'class'` → `.light` / `.dark`).
 *
 * Conséquence pour les composants : utiliser `theme.palette.*` ou `sx`
 * suffit à être correct dans les deux modes — aucun test
 * `theme.palette.mode === 'dark'` n'est nécessaire.
 *
 * Contrainte de l'API MUI v9 : `colorSchemes.{mode}` n'accepte que
 * `palette` (+ `opacity`/`overlays`), **pas** `components`. Les différences
 * de mode passent donc par :
 *   1. les **slots de palette par composant** (`Tooltip.bg`,
 *      `TableCell.border`…) que MUI transforme en variables CSS ;
 *   2. les helpers `useAricieShadows()` / `useAricieAccent()` pour ce qui
 *      ne peut pas être une variable CSS (les chaînes `boxShadow`).
 */

import { createTheme, useTheme  } from '@mui/material/styles';
import type { Theme } from '@mui/material/styles';
import {
  accents,
  darkColors,
  fonts,
  lightColors,
  radius,
  semantic,
  shadows,
} from './aricieTokens';

/* ------------------------------------------------------------------ */
/* Palette par mode                                                    */
/* ------------------------------------------------------------------ */

const lightPalette = {
  primary: {
    main: lightColors.interactive, // #1A3A4A
    light: lightColors.seed, // #4A6572 (seed documenté)
    dark: '#12282F',
    contrastText: lightColors.textInverse,
  },
  secondary: {
    main: accents.accent, // #79CFF4 — accent documenté
    light: '#A6E0F8',
    dark: '#4FA8CC',
    contrastText: '#12282F',
  },
  background: {
    default: lightColors.bgApp, // #C8D9E0
    paper: lightColors.bgPrimary, // #FFFFFF
  },
  text: {
    primary: lightColors.textPrimary,
    secondary: lightColors.textSecondary,
    disabled: lightColors.textMuted,
  },
  divider: lightColors.borderSubtle,
  success: { main: semantic.success, light: semantic.successLight, dark: '#3E7D55' },
  warning: { main: semantic.warning, light: '#FFE08A', dark: semantic.warningDeep },
  error: { main: semantic.error, light: '#F592A3', dark: '#C43A52' },
  info: { main: semantic.info, light: '#A6E0F8', dark: semantic.infoDeep },
  action: {
    hover: 'rgba(26, 58, 74, 0.04)',
    selected: 'rgba(26, 58, 74, 0.08)',
    focus: 'rgba(26, 58, 74, 0.12)',
  },
  // Slots par composant → variables CSS --mui-palette-Tooltip-bg, etc.
  Tooltip: { bg: lightColors.interactive },
  TableCell: { border: lightColors.borderSubtle },
} as const;

const darkPalette = {
  primary: {
    main: darkColors.interactive, // #4A7A8A
    light: '#6A9AAA',
    dark: '#35596A',
    contrastText: '#FFFFFF',
  },
  secondary: {
    main: accents.accent,
    light: '#A6E0F8',
    dark: '#4FA8CC',
    contrastText: '#12282F',
  },
  background: {
    default: darkColors.bgApp, // #1A2530
    paper: darkColors.bgPrimary, // #2A3540
  },
  text: {
    primary: darkColors.textPrimary,
    secondary: darkColors.textSecondary,
    disabled: darkColors.textMuted,
  },
  divider: darkColors.borderSubtle,
  success: { main: semantic.successLight, light: '#C4DCB8', dark: semantic.success },
  warning: { main: semantic.warning, light: '#FFE08A', dark: semantic.warningDeep },
  error: { main: '#F0728A', light: '#F592A3', dark: semantic.error },
  info: { main: accents.accent, light: '#A6E0F8', dark: '#4FA8CC' },
  action: {
    hover: 'rgba(232, 237, 240, 0.06)',
    selected: 'rgba(232, 237, 240, 0.10)',
    focus: 'rgba(232, 237, 240, 0.14)',
  },
  Tooltip: { bg: '#E8EDF0' },
  TableCell: { border: darkColors.borderSubtle },
} as const;

/* ------------------------------------------------------------------ */
/* Ombres globales                                                     */
/* ------------------------------------------------------------------ */

/**
 * MUI génère `--mui-shadows-0..24` à partir de ce tableau. On l'aligne sur
 * la charte (ombres bleutées, douces) tout en gardant une progression
 * monotone pour les composants qui utilisent `elevation`.
 *
 * Les cas qui exigent une ombre réellement différente en mode sombre
 * passent par `useAricieShadows()`.
 */
const elevation = [
  'none',
  ...Array.from({ length: 24 }, (_, i) => {
    const level = i + 1;
    const blur = 2 + level * 2;
    const y = Math.max(1, Math.round(level * 0.75));
    const alpha = Math.min(0.22, 0.05 + level * 0.008);
    return `0 ${y}px ${blur}px rgba(26, 58, 74, ${alpha.toFixed(3)})`;
  }),
] as string[] as Theme['shadows'];

/* ------------------------------------------------------------------ */
/* Typographie                                                         */
/* ------------------------------------------------------------------ */

/**
 * DM Serif Display porte les très grands titres (comme `displayLarge` en
 * Flutter) ; DM Sans porte tout le reste.
 */
const typography = {
  fontFamily: fonts.sans,
  h1: { fontFamily: fonts.serif, fontSize: '2.125rem', fontWeight: 400, letterSpacing: '-0.01em', lineHeight: 1.15 },
  h2: { fontFamily: fonts.serif, fontSize: '1.75rem', fontWeight: 400, letterSpacing: '-0.01em', lineHeight: 1.2 },
  h3: { fontSize: '1.375rem', fontWeight: 700, lineHeight: 1.3 },
  h4: { fontSize: '1.0625rem', fontWeight: 700, lineHeight: 1.3 },
  h5: { fontSize: '0.9375rem', fontWeight: 600, lineHeight: 1.4 },
  h6: { fontSize: '0.8125rem', fontWeight: 600, lineHeight: 1.4 },
  body1: { fontSize: '0.875rem', fontWeight: 400, lineHeight: 1.5 },
  body2: { fontSize: '0.75rem', fontWeight: 400, lineHeight: 1.5 },
  caption: { fontSize: '0.625rem', fontWeight: 400, lineHeight: 1.4 },
  button: { fontSize: '0.8125rem', fontWeight: 600, textTransform: 'none' as const },
  overline: { fontSize: '0.625rem', fontWeight: 600, letterSpacing: '0.06em' },
};

/* ------------------------------------------------------------------ */
/* Thème                                                               */
/* ------------------------------------------------------------------ */

export const muiTheme = createTheme({
  // Les options de variables CSS sont imbriquées ici : MUI les retire du
  // niveau racine de `ThemeOptions` et attend cet objet.
  // `'class'` pose `.light` / `.dark` sur <html>, ce qui laisse la main au
  // `setMode()` de `useColorScheme` (et non au seul `prefers-color-scheme`).
  cssVariables: { colorSchemeSelector: 'class' },
  defaultColorScheme: 'light',
  colorSchemes: {
    light: { palette: lightPalette },
    dark: { palette: darkPalette },
  },

  shadows: elevation,
  typography,
  shape: { borderRadius: radius.md },

  components: {
    MuiCssBaseline: {
      styleOverrides: {
        ':root': { colorScheme: 'light dark' },
        html: { WebkitFontSmoothing: 'antialiased', MozOsxFontSmoothing: 'grayscale' },
        body: {
          backgroundColor: 'var(--mui-palette-background-default)',
          color: 'var(--mui-palette-text-primary)',
          minHeight: '100vh',
          overflowX: 'hidden',
        },
        '::selection': {
          backgroundColor: 'var(--mui-palette-primary-main)',
          color: 'var(--mui-palette-primary-contrastText)',
        },
        // Barre de défilement discrète, cohérente dans les deux modes.
        '*': { scrollbarWidth: 'thin' },
        '*::-webkit-scrollbar': { width: 8, height: 8 },
        '*::-webkit-scrollbar-track': { backgroundColor: 'transparent' },
        '*::-webkit-scrollbar-thumb': {
          backgroundColor: 'var(--mui-palette-divider)',
          borderRadius: radius.full,
        },
        '*::-webkit-scrollbar-thumb:hover': {
          backgroundColor: 'var(--mui-palette-text-disabled)',
        },
      },
    },

    /* --- Surfaces --- */
    MuiPaper: {
      defaultProps: { elevation: 0 },
      styleOverrides: {
        root: {
          backgroundImage: 'none',
          borderRadius: radius.md,
          border: '1px solid var(--mui-palette-divider)',
        },
      },
    },
    MuiCard: {
      defaultProps: { elevation: 0 },
      styleOverrides: {
        root: {
          borderRadius: radius.md,
          border: '1px solid var(--mui-palette-divider)',
          backgroundImage: 'none',
        },
      },
    },
    MuiCardContent: {
      styleOverrides: { root: { padding: 20, '&:last-child': { paddingBottom: 20 } } },
    },
    MuiCardHeader: {
      styleOverrides: {
        root: { padding: '20px 20px 0' },
        title: { fontSize: '0.9375rem', fontWeight: 700 },
      },
    },

    /* --- Actions --- */
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: {
        root: {
          borderRadius: radius.full,
          fontWeight: 600,
          padding: '8px 20px',
          textTransform: 'none',
          boxShadow: 'none',
          '&:hover': { boxShadow: 'none' },
          // ButtonClasses n'expose pas de slot par couleur : on cible la
          // classe générée par MUI pour teinter le survol du bouton plein.
          '&.MuiButton-containedPrimary:hover': { backgroundColor: 'var(--mui-palette-primary-dark)' },
        },
        sizeSmall: { padding: '5px 14px', fontSize: '0.75rem' },
        sizeLarge: { padding: '11px 26px', fontSize: '0.875rem' },
      },
    },
    MuiIconButton: {
      styleOverrides: {
        root: {
          borderRadius: radius.sm,
          transition: 'background-color 0.2s ease, color 0.2s ease, transform 0.2s ease',
        },
        sizeSmall: { borderRadius: radius.xs },
      },
    },
    MuiToggleButton: {
      styleOverrides: {
        root: {
          borderRadius: radius.full,
          textTransform: 'none',
          fontWeight: 600,
          fontSize: '0.8125rem',
          color: 'var(--mui-palette-text-secondary)',
          border: '1px solid var(--mui-palette-divider)',
          padding: '6px 16px',
          '&.Mui-selected': {
            backgroundColor: 'var(--mui-palette-primary-main)',
            color: 'var(--mui-palette-primary-contrastText)',
            '&:hover': { backgroundColor: 'var(--mui-palette-primary-dark)' },
          },
        },
      },
    },
    MuiToggleButtonGroup: {
      styleOverrides: {
        root: {
          gap: 4,
          '& .MuiToggleButtonGroup-grouped': { margin: 0, border: '1px solid var(--mui-palette-divider)' },
        },
      },
    },

    /* --- Champs & sélecteurs --- */
    MuiOutlinedInput: {
      styleOverrides: {
        root: {
          borderRadius: radius.md,
          '& .MuiOutlinedInput-notchedOutline': { borderColor: 'var(--mui-palette-divider)' },
          '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: 'var(--mui-palette-text-disabled)' },
          '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
            borderColor: 'var(--mui-palette-primary-main)',
            borderWidth: 1.5,
          },
        },
        input: { fontSize: '0.875rem' },
      },
    },
    MuiInputLabel: { styleOverrides: { root: { fontSize: '0.875rem' } } },
    MuiTextField: { defaultProps: { size: 'small' } },
    MuiSelect: { defaultProps: { size: 'small' } },
    MuiSwitch: {
      styleOverrides: {
        root: { padding: 8 },
        thumb: { boxShadow: 'none' },
        track: { borderRadius: radius.full, opacity: 0.3 },
      },
    },
    MuiCheckbox: {
      defaultProps: { size: 'small' },
      styleOverrides: { root: { borderRadius: radius.xs } },
    },
    MuiRadio: { defaultProps: { size: 'small' } },

    /* --- Étiquettes --- */
    MuiChip: {
      styleOverrides: {
        root: { borderRadius: radius.full, fontWeight: 600, fontSize: '0.6875rem' },
        sizeSmall: { height: 22, fontSize: '0.625rem' },
        label: { paddingLeft: 10, paddingRight: 10 },
      },
    },
    MuiAvatar: {
      styleOverrides: { root: { borderRadius: radius.full, fontWeight: 700, fontSize: '0.8125rem' } },
    },
    MuiBadge: {
      styleOverrides: { badge: { borderRadius: radius.full, fontSize: '0.625rem', fontWeight: 700 } },
    },

    /* --- Superpositions --- */
    MuiDialog: {
      styleOverrides: {
        paper: { borderRadius: radius.lg, border: '1px solid var(--mui-palette-divider)', backgroundImage: 'none' },
      },
    },
    MuiDialogTitle: {
      styleOverrides: { root: { fontSize: '1.0625rem', fontWeight: 700, padding: '20px 24px 8px' } },
    },
    MuiDialogContent: { styleOverrides: { root: { padding: '8px 24px 0' } } },
    MuiDialogActions: { styleOverrides: { root: { padding: '16px 24px 20px', gap: 8 } } },
    MuiDrawer: {
      styleOverrides: {
        paper: { borderRadius: 0, borderRight: '1px solid var(--mui-palette-divider)', backgroundImage: 'none' },
      },
    },
    MuiMenu: {
      styleOverrides: {
        paper: {
          borderRadius: radius.md,
          border: '1px solid var(--mui-palette-divider)',
          backgroundImage: 'none',
          marginTop: 6,
        },
      },
    },
    MuiMenuItem: {
      styleOverrides: {
        root: { borderRadius: radius.xs, fontSize: '0.8125rem', margin: '2px 6px', padding: '8px 12px' },
      },
    },
    MuiTooltip: {
      styleOverrides: {
        tooltip: {
          backgroundColor: 'var(--mui-palette-Tooltip-bg)',
          borderRadius: radius.sm,
          fontSize: '0.6875rem',
          fontWeight: 500,
          padding: '6px 10px',
        },
      },
    },

    /* --- Navigation --- */
    MuiListItemButton: {
      styleOverrides: { root: { borderRadius: radius.sm, '&.Mui-selected': { fontWeight: 600 } } },
    },
    MuiListItemIcon: { styleOverrides: { root: { minWidth: 38 } } },
    MuiTabs: {
      styleOverrides: { root: { minHeight: 40 }, indicator: { height: 3, borderRadius: radius.full } },
    },
    MuiTab: {
      styleOverrides: {
        root: { textTransform: 'none', fontWeight: 600, fontSize: '0.8125rem', minHeight: 40, padding: '8px 16px' },
      },
    },

    /* --- Tableaux --- */
    MuiTable: { styleOverrides: { root: { borderCollapse: 'separate', borderSpacing: 0 } } },
    MuiTableHead: {
      styleOverrides: {
        root: {
          '& .MuiTableCell-root': {
            // `action-hover` est un aplat neutre garanti dans les deux modes :
            // il sert d'équivalent à AppColors.bgSecondary en tableau.
            backgroundColor: 'var(--mui-palette-action-hover)',
            color: 'var(--mui-palette-text-secondary)',
            fontWeight: 700,
            fontSize: '0.6875rem',
            letterSpacing: '0.04em',
            textTransform: 'uppercase',
            borderBottom: '1px solid var(--mui-palette-TableCell-border)',
            whiteSpace: 'nowrap',
          },
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          borderBottom: '1px solid var(--mui-palette-TableCell-border)',
          fontSize: '0.8125rem',
          padding: '12px 16px',
        },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: {
          '&:last-child .MuiTableCell-root': { borderBottom: 'none' },
          '&.MuiTableRow-hover:hover': { backgroundColor: 'var(--mui-palette-action-hover)' },
        },
      },
    },
    MuiTableContainer: { styleOverrides: { root: { backgroundImage: 'none' } } },

    /* --- Divers --- */
    MuiDivider: { styleOverrides: { root: { borderColor: 'var(--mui-palette-divider)' } } },
    MuiLinearProgress: {
      styleOverrides: {
        root: { height: 6, borderRadius: radius.full, backgroundColor: 'var(--mui-palette-divider)' },
      },
    },
    MuiAlert: { styleOverrides: { root: { borderRadius: radius.md, fontSize: '0.8125rem' } } },
    MuiAccordion: {
      defaultProps: { elevation: 0, disableGutters: true },
      styleOverrides: {
        root: {
          borderRadius: radius.md,
          border: '1px solid var(--mui-palette-divider)',
          backgroundImage: 'none',
          '&:before': { display: 'none' },
          '&.Mui-expanded': { margin: 0 },
        },
      },
    },
    MuiSkeleton: {
      styleOverrides: { root: { borderRadius: radius.xs, backgroundColor: 'var(--mui-palette-action-hover)' } },
    },
    MuiLink: { defaultProps: { underline: 'hover' }, styleOverrides: { root: { fontWeight: 600 } } },
  },
});

/* ------------------------------------------------------------------ */
/* Aides dépendantes du mode                                           */
/* ------------------------------------------------------------------ */

/**
 * Ombres du mode courant.
 *
 * Les ombres sont la seule valeur qui ne passe pas par une variable CSS du
 * thème : un `boxShadow` reste une chaîne littérale dans `sx`. En mode
 * sombre, les ombres bleutées de la charte claire sont invisibles — il
 * faut donc les versions opaques.
 */
export function useAricieShadows() {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  return {
    xs: isDark ? shadows.darkSm : shadows.xs,
    sm: isDark ? shadows.darkSm : shadows.sm,
    md: isDark ? shadows.darkMd : shadows.md,
    lg: isDark ? shadows.darkLg : shadows.lg,
    float: isDark ? shadows.darkLg : shadows.float,
  };
}

/** Teintes d'accent lisibles selon le mode. */
export function useAricieAccent() {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  return {
    /** Trait accent documenté — lisible dans les deux modes. */
    line: accents.accent,
    /** Fond d'un aplat d'accent. */
    fill: isDark ? 'rgba(121, 207, 244, 0.16)' : 'rgba(121, 207, 244, 0.24)',
    /** Texte posé sur un aplat d'accent. */
    on: isDark ? '#A6E0F8' : '#1A3A4A',
    /** Seed documenté, ajusté pour rester lisible. */
    seed: isDark ? '#7A95A2' : accents.teal,
  };
}

/** Palette d'accents, identique dans les deux modes (pastels de la charte). */
export { accents };

/** Point d'accroche pour les tests. */
export type AricieTheme = Theme;
export default muiTheme;
