import React, { useState } from 'react';
import { Box, IconButton, Menu, MenuItem, Tooltip, Typography, useColorScheme } from '@mui/material';
import LightModeRoundedIcon from '@mui/icons-material/LightModeRounded';
import DarkModeRoundedIcon from '@mui/icons-material/DarkModeRounded';
import SettingsBrightnessRoundedIcon from '@mui/icons-material/SettingsBrightnessRounded';
import CheckRoundedIcon from '@mui/icons-material/CheckRounded';

/**
 * Sélecteur de mode d'affichage : Clair / Sombre / Système.
 *
 * S'appuie sur `useColorScheme()` de MUI, qui applique la classe `.light` ou
 * `.dark` sur `<html>` (voir `colorSchemeSelector: 'class'` dans le thème)
 * et **persiste le choix** dans `localStorage`.
 *
 * Aucun état local n'est nécessaire : MUI est la source de vérité, ce qui
 * évite toute divergence avec le thème réellement appliqué.
 */
type Mode = 'light' | 'dark' | 'system';

const MODES: { value: Mode; label: string; hint: string; icon: React.ReactElement }[] = [
  {
    value: 'light',
    label: 'Clair',
    hint: 'Fond clair, surfaces blanches',
    icon: <LightModeRoundedIcon sx={{ fontSize: 18 }} />,
  },
  {
    value: 'dark',
    label: 'Sombre',
    hint: 'Fond ardoise, contraste réduit',
    icon: <DarkModeRoundedIcon sx={{ fontSize: 18 }} />,
  },
  {
    value: 'system',
    label: 'Système',
    hint: "Suit le réglage de l'OS",
    icon: <SettingsBrightnessRoundedIcon sx={{ fontSize: 18 }} />,
  },
];

export const ThemeModeToggle: React.FC = () => {
  const { mode, setMode } = useColorScheme();
  const [anchor, setAnchor] = useState<null | HTMLElement>(null);

  // `mode` peut être `undefined` au tout premier rendu (avant hydratation).
  const current: Mode = (mode as Mode) ?? 'system';
  const currentMeta = MODES.find((m) => m.value === current) ?? MODES[2];

  return (
    <>
      <Tooltip title={`Thème : ${currentMeta.label}`}>
        <IconButton
          aria-label="Changer de thème"
          onClick={(e) => setAnchor(e.currentTarget)}
          sx={{
            width: 42,
            height: 42,
            color: 'text.primary',
            backgroundColor: 'action.hover',
            '&:hover': { backgroundColor: 'action.selected' },
          }}
        >
          {currentMeta.icon}
        </IconButton>
      </Tooltip>

      <Menu
        anchorEl={anchor}
        open={Boolean(anchor)}
        onClose={() => setAnchor(null)}
        slotProps={{ paper: { sx: { width: 250, p: 0.5 } } }}
      >
        <Typography
          sx={{
            px: 2,
            py: 1,
            fontSize: '0.6875rem',
            fontWeight: 700,
            letterSpacing: '0.04em',
            textTransform: 'uppercase',
            color: 'text.secondary',
          }}
        >
          Thème d'affichage
        </Typography>

        {MODES.map((m) => (
          <MenuItem
            key={m.value}
            selected={m.value === current}
            onClick={() => {
              setMode(m.value);
              setAnchor(null);
            }}
          >
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, width: '100%' }}>
              <Box sx={{ color: 'text.secondary', display: 'flex' }}>{m.icon}</Box>
              <Box sx={{ display: 'flex', flexDirection: 'column', flex: 1 }}>
                <Typography sx={{ fontSize: '0.8125rem', fontWeight: 600 }}>{m.label}</Typography>
                <Typography sx={{ fontSize: '0.6875rem', color: 'text.secondary' }}>{m.hint}</Typography>
              </Box>
              {m.value === current && <CheckRoundedIcon sx={{ fontSize: 16, color: 'primary.main' }} />}
            </Box>
          </MenuItem>
        ))}
      </Menu>
    </>
  );
};

export default ThemeModeToggle;
