import React from 'react';
import { Box, Card, FormControlLabel, Radio, RadioGroup, Typography } from '@mui/material';
import { useAppStore } from '../store/useAppStore';
import type { Currency } from '../types';

export const SettingsPage: React.FC = () => {
  const language = useAppStore((state) => state.language);
  const currency = useAppStore((state) => state.currency);
  const setCurrency = useAppStore((state) => state.setCurrency);
  const session = useAppStore((state) => state.session);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, maxWidth: 900 }}>
      <Box>
        <Typography variant="h1" sx={{ fontSize: { xs: '1.6rem', md: '2.2rem' }, fontWeight: 700, color: '#fff' }}>
          {language === 'fr' ? 'Paramètres' : 'Settings'}
        </Typography>
        <Typography sx={{ color: '#8e94a3', fontSize: '.88rem', mt: .5 }}>
          {language === 'fr' ? 'Préférences d’affichage et identité administrateur vérifiée par admin-api.' : 'Display preferences and administrator identity verified by admin-api.'}
        </Typography>
      </Box>

      <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,.05)', p: 3 }}>
        <Typography sx={{ fontWeight: 700, color: '#fff', mb: 1 }}>{language === 'fr' ? 'Compte connecté' : 'Signed-in account'}</Typography>
        <Typography sx={{ color: '#e0e4ec' }}>{session?.email ?? '—'}</Typography>
        <Typography sx={{ color: '#8e94a3', mt: .5 }}>{language === 'fr' ? 'Niveau d’accès vérifié côté serveur' : 'Access level verified by the server'}: {session?.level ?? '—'}</Typography>
      </Card>

      <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,.05)', p: 3 }}>
        <Typography sx={{ fontWeight: 700, color: '#fff', mb: 1 }}>{language === 'fr' ? 'Devise d’affichage' : 'Display currency'}</Typography>
        <Typography sx={{ color: '#8e94a3', fontSize: '.82rem', mb: 2 }}>{language === 'fr' ? 'Préférence locale uniquement ; elle ne modifie pas les données de facturation.' : 'Local preference only; it does not change billing records.'}</Typography>
        <RadioGroup row value={currency} onChange={(event) => setCurrency(event.target.value as Currency)}>
          <FormControlLabel value="XAF" control={<Radio />} label="XAF (par défaut)" />
          <FormControlLabel value="EUR" control={<Radio />} label="EUR" />
          <FormControlLabel value="USD" control={<Radio />} label="USD" />
        </RadioGroup>
      </Card>
    </Box>
  );
};
