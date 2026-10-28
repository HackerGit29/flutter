import React from 'react';
import { Box, Card, CardContent, Typography } from '@mui/material';

interface SectionCardProps {
  /** Titre de la section. */
  title?: string;
  /** Précision affichée sous le titre. */
  subtitle?: string;
  /** Élément aligné à droite du titre (chip, bouton, toggle). */
  action?: React.ReactNode;
  /** Icône affichée devant le titre. */
  icon?: React.ReactNode;
  /** Retire le rembourrage interne — utile pour un tableau qui touche les bords. */
  disablePadding?: boolean;
  children: React.ReactNode;
  sx?: object;
}

/**
 * Carte de section.
 *
 * Remplace les `Card` + `sx` recopiés dans chaque page. Les couleurs
 * viennent toutes du thème : aucune valeur en dur, donc rendu correct en
 * clair comme en sombre sans branchement conditionnel.
 */
export const SectionCard: React.FC<SectionCardProps> = ({
  title,
  subtitle,
  action,
  icon,
  disablePadding = false,
  children,
  sx,
}) => (
  <Card sx={{ display: 'flex', flexDirection: 'column', height: '100%', ...sx }}>
    {title && (
      <Box
        sx={{
          display: 'flex',
          alignItems: 'flex-start',
          justifyContent: 'space-between',
          gap: 1.5,
          px: 2.5,
          pt: 2.5,
          pb: disablePadding ? 2 : 1,
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.25, minWidth: 0 }}>
          {icon && <Box sx={{ display: 'flex', color: 'primary.main' }}>{icon}</Box>}
          <Box sx={{ minWidth: 0 }}>
            <Typography variant="h4" component="h2" sx={{ color: 'text.primary' }}>
              {title}
            </Typography>
            {subtitle && (
              <Typography sx={{ color: 'text.secondary', fontSize: '0.75rem', mt: 0.25 }}>
                {subtitle}
              </Typography>
            )}
          </Box>
        </Box>
        {action && <Box sx={{ flexShrink: 0 }}>{action}</Box>}
      </Box>
    )}

    {disablePadding ? (
      <Box sx={{ flex: 1, minHeight: 0 }}>{children}</Box>
    ) : (
      <CardContent sx={{ flex: 1, minHeight: 0, pt: title ? 1 : 2.5 }}>{children}</CardContent>
    )}
  </Card>
);

export default SectionCard;
