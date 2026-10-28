import React from 'react';
import { Box, Card, Skeleton, Typography } from '@mui/material';
import TrendingUpRoundedIcon from '@mui/icons-material/TrendingUpRounded';
import TrendingDownRoundedIcon from '@mui/icons-material/TrendingDownRounded';
import TrendingFlatRoundedIcon from '@mui/icons-material/TrendingFlatRounded';
import { accents } from '../../theme/aricieTokens';

/** Palette d'accent d'une tuile — détermine la teinte de l'icône et du halo. */
export type TileTone = 'primary' | 'accent' | 'success' | 'warning' | 'error' | 'neutral';

interface StatTileProps {
  /** Intitulé de la métrique. */
  label: string;
  /** Valeur déjà formatée (devise, pourcentage, nombre). */
  value: React.ReactNode;
  /** Variation par rapport à la période précédente, en pourcentage. */
  delta?: number | null;
  /** Précision sur la période mesurée (« 30 derniers jours »). */
  timeframe?: string;
  /** Texte sous la valeur quand il n'y a pas de variation. */
  hint?: string;
  icon?: React.ReactNode;
  tone?: TileTone;
  /** Tuile mise en avant : aplat de couleur pleine. */
  highlighted?: boolean;
  loading?: boolean;
}

/** Teinte d'accent par tonalité, lisible en clair comme en sombre. */
const toneColors: Record<TileTone, string> = {
  primary: accents.accent,
  accent: accents.purple,
  success: '#4E9A6A',
  warning: accents.gold,
  error: accents.dot,
  neutral: accents.blue,
};

/**
 * Tuile d'indicateur clé.
 *
 * Version thématisée de l'ancienne `StatCard` : plus de dégradé bleu figé ni
 * de valeurs hexadécimales, tout passe par la palette et les accents de la
 * charte, donc le rendu est correct dans les deux modes.
 */
export const StatTile: React.FC<StatTileProps> = ({
  label,
  value,
  delta = null,
  timeframe,
  hint,
  icon,
  tone = 'primary',
  highlighted = false,
  loading = false,
}) => {
  const accent = toneColors[tone];
  const hasDelta = typeof delta === 'number' && Number.isFinite(delta);
  const isFlat = hasDelta && Math.abs(delta) < 0.5;

  const DeltaIcon = !hasDelta ? null : isFlat ? TrendingFlatRoundedIcon : delta > 0 ? TrendingUpRoundedIcon : TrendingDownRoundedIcon;
  const deltaColor = !hasDelta || isFlat ? 'text.secondary' : delta > 0 ? 'success.main' : 'error.main';

  return (
    <Card
      sx={{
        height: '100%',
        minHeight: 132,
        p: 2.5,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        position: 'relative',
        overflow: 'hidden',
        ...(highlighted && {
          borderColor: 'transparent',
          backgroundColor: 'primary.main',
          color: 'primary.contrastText',
        }),
      }}
    >
      {/* Halo d'accent discret, purement décoratif. */}
      <Box
        aria-hidden
        sx={{
          position: 'absolute',
          top: -40,
          right: -40,
          width: 130,
          height: 130,
          borderRadius: '50%',
          backgroundColor: accent,
          opacity: highlighted ? 0.22 : 0.1,
          filter: 'blur(6px)',
          pointerEvents: 'none',
        }}
      />

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.25, position: 'relative' }}>
        {icon && (
          <Box
            sx={{
              width: 34,
              height: 34,
              borderRadius: 2,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
              backgroundColor: highlighted ? 'rgba(255,255,255,0.18)' : 'action.hover',
              color: highlighted ? 'inherit' : accent,
            }}
          >
            {icon}
          </Box>
        )}
        <Typography
          sx={{
            fontSize: '0.8125rem',
            fontWeight: 500,
            color: highlighted ? 'inherit' : 'text.secondary',
            minWidth: 0,
          }}
        >
          {label}
        </Typography>
      </Box>

      <Box sx={{ position: 'relative' }}>
        {loading ? (
          <Skeleton variant="text" width={110} height={40} />
        ) : (
          <Typography
            sx={{
              fontSize: { xs: '1.5rem', sm: '1.75rem' },
              fontWeight: 700,
              fontVariantNumeric: 'tabular-nums',
              letterSpacing: '-0.02em',
              lineHeight: 1.15,
              color: highlighted ? 'inherit' : 'text.primary',
            }}
          >
            {value}
          </Typography>
        )}

        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.6, mt: 0.5, minHeight: 18 }}>
          {!loading && DeltaIcon && (
            <>
              <DeltaIcon
                sx={{ fontSize: 15, color: highlighted ? 'inherit' : deltaColor }}
              />
              <Typography
                sx={{
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  color: highlighted ? 'inherit' : deltaColor,
                }}
              >
                {delta! > 0 ? '+' : ''}
                {delta!.toFixed(1)} %
              </Typography>
            </>
          )}
          {(timeframe || hint) && (
            <Typography
              sx={{
                fontSize: '0.6875rem',
                color: highlighted ? 'rgba(255,255,255,0.75)' : 'text.secondary',
              }}
            >
              {timeframe ?? hint}
            </Typography>
          )}
        </Box>
      </Box>
    </Card>
  );
};

export default StatTile;
