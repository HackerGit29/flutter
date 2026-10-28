import React from 'react';
import { Box, Typography } from '@mui/material';

interface PageHeaderProps {
  /** Titre de la page — rendu en DM Serif Display. */
  title: string;
  /** Sous-titre explicatif, une ligne. */
  subtitle?: string;
  /** Actions alignées à droite (boutons, filtres, sélecteurs). */
  actions?: React.ReactNode;
}

/**
 * En-tête de page du backoffice.
 *
 * Centralise la structure titre / sous-titre / actions pour que les 9 pages
 * partagent exactement la même hiérarchie et les mêmes espacements, et pour
 * qu'aucune ne réintroduise une couleur en dur.
 */
export const PageHeader: React.FC<PageHeaderProps> = ({ title, subtitle, actions }) => (
  <Box
    sx={{
      display: 'flex',
      flexDirection: { xs: 'column', sm: 'row' },
      alignItems: { xs: 'flex-start', sm: 'center' },
      justifyContent: 'space-between',
      gap: 2,
    }}
  >
    <Box sx={{ minWidth: 0 }}>
      <Typography variant="h2" component="h1" sx={{ color: 'text.primary' }}>
        {title}
      </Typography>
      {subtitle && (
        <Typography sx={{ color: 'text.secondary', fontSize: '0.875rem', mt: 0.5 }}>{subtitle}</Typography>
      )}
    </Box>

    {actions && (
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, flexWrap: 'wrap' }}>{actions}</Box>
    )}
  </Box>
);

export default PageHeader;
