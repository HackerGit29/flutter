import React, { useState } from 'react';
import {
  Avatar,
  Badge,
  Box,
  Divider,
  IconButton,
  InputBase,
  Menu,
  MenuItem,
  Tooltip,
  Typography,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import MenuRoundedIcon from '@mui/icons-material/MenuRounded';
import SearchRoundedIcon from '@mui/icons-material/SearchRounded';
import NotificationsOutlinedIcon from '@mui/icons-material/NotificationsOutlined';
import TranslateRoundedIcon from '@mui/icons-material/TranslateRounded';
import AdminPanelSettingsRoundedIcon from '@mui/icons-material/AdminPanelSettingsRounded';
import SecurityRoundedIcon from '@mui/icons-material/SecurityRounded';
import VisibilityOffRoundedIcon from '@mui/icons-material/VisibilityOffRounded';
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined';
import LogoutRoundedIcon from '@mui/icons-material/LogoutRounded';
import PersonOutlineRoundedIcon from '@mui/icons-material/PersonOutlineRounded';
import { getSupabase } from '../../api/supabaseClient';
import { ThemeModeToggle } from './ThemeModeToggle';
import { useAppStore } from '../../store/useAppStore';
import type { AdminLevel } from '../../types/admin';
import type { Currency } from '../../types';
import { accents } from '../../theme/aricieTokens';

/** Libellé et teinte d'accent par niveau d'accès. */
const LEVELS: Record<AdminLevel, { label: string; hint: string; tone: string; icon: React.ReactNode }> = {
  viewer: {
    label: 'Lecteur',
    hint: 'Lecture seule, emails masqués (RGPD)',
    tone: accents.gold,
    icon: <VisibilityOffRoundedIcon sx={{ fontSize: 16 }} />,
  },
  operator: {
    label: 'Opérateur',
    hint: 'Écritures opérationnelles, emails visibles',
    tone: accents.accent,
    icon: <SecurityRoundedIcon sx={{ fontSize: 16 }} />,
  },
  super_admin: {
    label: 'Super admin',
    hint: 'Rôles, licences, reset et audit complet',
    tone: accents.purple,
    icon: <AdminPanelSettingsRoundedIcon sx={{ fontSize: 16 }} />,
  },
};

const CURRENCIES: { value: Currency; label: string; hint: string }[] = [
  { value: 'XAF', label: 'XAF — Franc CFA', hint: 'Devise de l’application (par défaut)' },
  { value: 'EUR', label: 'EUR — Euro', hint: 'Conversion : 1 EUR = 655,957 XAF' },
  { value: 'USD', label: 'USD — Dollar', hint: 'Conversion indicative' },
];

export const Header: React.FC = () => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  const {
    setIsMobileMenuOpen,
    searchQuery,
    setSearchQuery,
    currency,
    setCurrency,
    language,
    toggleLanguage,
    session,
  } = useAppStore();

  const [profileAnchor, setProfileAnchor] = useState<null | HTMLElement>(null);
  const [currencyAnchor, setCurrencyAnchor] = useState<null | HTMLElement>(null);
  const [notificationsAnchor, setNotificationsAnchor] = useState<null | HTMLElement>(null);

  const level = session?.level ?? null;
  const levelMeta = level ? LEVELS[level] : null;

  return (
    <Box
      component="header"
      sx={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 2,
        px: { xs: 2, sm: 3, md: 4 },
        py: { xs: 1.5, md: 1.75 },
        backgroundColor: 'background.paper',
        borderBottom: '1px solid',
        borderColor: 'divider',
        position: 'sticky',
        top: 0,
        zIndex: (t) => t.zIndex.appBar,
      }}
    >
      {/* Recherche globale */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, flex: 1, maxWidth: 420 }}>
        {isMobile && (
          <IconButton
            aria-label="Ouvrir le menu"
            onClick={() => setIsMobileMenuOpen(true)}
            sx={{ width: 42, height: 42, color: 'text.primary', backgroundColor: 'action.hover' }}
          >
            <MenuRoundedIcon />
          </IconButton>
        )}

        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            gap: 1,
            px: 1.75,
            py: 0.75,
            width: '100%',
            borderRadius: 2,
            backgroundColor: 'action.hover',
            border: '1px solid',
            borderColor: 'divider',
            transition: 'border-color 0.2s ease, box-shadow 0.2s ease',
            '&:focus-within': {
              borderColor: 'primary.main',
              boxShadow: (t) => `0 0 0 3px ${t.palette.action.focus}`,
            },
          }}
        >
          <SearchRoundedIcon sx={{ color: 'text.secondary', fontSize: 19 }} />
          <InputBase
            placeholder="Rechercher un client, un boîtier, un email…"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            inputProps={{ 'aria-label': 'Recherche globale' }}
            sx={{ fontSize: '0.8125rem', color: 'text.primary', width: '100%' }}
          />
        </Box>
      </Box>

      {/* Actions */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: { xs: 0.5, sm: 1 } }}>
        {/* Niveau d'accès — vient du backend, non modifiable ici */}
        {levelMeta && (
          <Tooltip title={`${levelMeta.label} — ${levelMeta.hint}`}>
            <Box
              sx={{
                display: { xs: 'none', sm: 'flex' },
                alignItems: 'center',
                gap: 0.75,
                px: 1.5,
                py: 0.6,
                borderRadius: 9999,
                color: levelMeta.tone,
                backgroundColor: (t) => `${levelMeta.tone}22`,
                border: '1px solid',
                borderColor: (t) => `${levelMeta.tone}55`,
              }}
            >
              {levelMeta.icon}
              <Typography sx={{ fontSize: '0.75rem', fontWeight: 700, color: 'inherit' }}>
                {levelMeta.label}
              </Typography>
            </Box>
          </Tooltip>
        )}

        {/* Devise */}
        <Tooltip title={`Devise d'affichage : ${currency}`}>
          <IconButton
            aria-label="Changer de devise"
            onClick={(e) => setCurrencyAnchor(e.currentTarget)}
            sx={{
              width: 42,
              height: 42,
              display: { xs: 'none', sm: 'inline-flex' },
              color: 'text.primary',
              backgroundColor: 'action.hover',
            }}
          >
            <PaymentsOutlinedIcon sx={{ fontSize: 19 }} />
          </IconButton>
        </Tooltip>

        <Menu
          anchorEl={currencyAnchor}
          open={Boolean(currencyAnchor)}
          onClose={() => setCurrencyAnchor(null)}
          slotProps={{ paper: { sx: { width: 270, p: 0.5 } } }}
        >
          {CURRENCIES.map((c) => (
            <MenuItem
              key={c.value}
              selected={c.value === currency}
              onClick={() => {
                setCurrency(c.value);
                setCurrencyAnchor(null);
              }}
            >
              <Box sx={{ display: 'flex', flexDirection: 'column' }}>
                <Typography sx={{ fontSize: '0.8125rem', fontWeight: 600 }}>{c.label}</Typography>
                <Typography sx={{ fontSize: '0.6875rem', color: 'text.secondary' }}>{c.hint}</Typography>
              </Box>
            </MenuItem>
          ))}
        </Menu>

        {/* Langue */}
        <Tooltip title={language === 'fr' ? 'Passer en anglais' : 'Revenir au français'}>
          <IconButton
            aria-label="Changer de langue"
            onClick={toggleLanguage}
            sx={{ width: 42, height: 42, color: 'text.primary', backgroundColor: 'action.hover' }}
          >
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.4 }}>
              <TranslateRoundedIcon sx={{ fontSize: 17 }} />
              <Typography sx={{ fontSize: '0.6875rem', fontWeight: 700 }}>
                {language.toUpperCase()}
              </Typography>
            </Box>
          </IconButton>
        </Tooltip>

        {/* Theme clair / sombre / systeme */}
        <ThemeModeToggle />

        {/* Alertes */}
        <Tooltip title="Alertes du parc">
          <IconButton
            aria-label="Alertes"
            onClick={(e) => setNotificationsAnchor(e.currentTarget)}
            sx={{ width: 42, height: 42, color: 'text.primary', backgroundColor: 'action.hover' }}
          >
            <Badge
              variant="dot"
              sx={{ '& .MuiBadge-badge': { backgroundColor: 'error.main' } }}
            >
              <NotificationsOutlinedIcon sx={{ fontSize: 19 }} />
            </Badge>
          </IconButton>
        </Tooltip>

        <Menu
          anchorEl={notificationsAnchor}
          open={Boolean(notificationsAnchor)}
          onClose={() => setNotificationsAnchor(null)}
          slotProps={{ paper: { sx: { width: 320, p: 1 } } }}
        >
          <Typography sx={{ px: 1.5, py: 1, fontSize: '0.8125rem', fontWeight: 700 }}>
            Alertes du parc
          </Typography>
          <Typography sx={{ px: 1.5, pb: 1.5, fontSize: '0.75rem', color: 'text.secondary' }}>
            Les alertes temps réel (boîtiers hors ligne, échecs d'acquittement) arrivent avec
            l'abonnement Supabase Realtime sur <code>device_commands</code>.
          </Typography>
        </Menu>

        {/* Profil */}
        <Tooltip title={session?.email ?? 'Non connecté'}>
          <IconButton
            aria-label="Compte administrateur"
            onClick={(e) => setProfileAnchor(e.currentTarget)}
            sx={{ p: 0, ml: 0.5, borderRadius: 9999 }}
          >
            <Avatar
              src={undefined}
              sx={{
                width: 38,
                height: 38,
                backgroundColor: 'primary.main',
                color: 'primary.contrastText',
                border: '2px solid',
                borderColor: 'divider',
              }}
            >
              {(session?.email?.[0] ?? '?').toUpperCase()}
            </Avatar>
          </IconButton>
        </Tooltip>

        <Menu
          anchorEl={profileAnchor}
          open={Boolean(profileAnchor)}
          onClose={() => setProfileAnchor(null)}
          slotProps={{ paper: { sx: { width: 260, p: 1 } } }}
        >
          <Box sx={{ px: 1.5, py: 1 }}>
            <Typography sx={{ fontSize: '0.8125rem', fontWeight: 700 }}>
              {session?.email ?? 'Non connecté'}
            </Typography>
            <Typography sx={{ fontSize: '0.6875rem', color: 'text.secondary' }}>
              {levelMeta ? levelMeta.label : 'Session absente'}
            </Typography>
          </Box>

          <Divider sx={{ my: 1 }} />

          <MenuItem onClick={() => setProfileAnchor(null)}>
            <PersonOutlineRoundedIcon sx={{ fontSize: 17, mr: 1.25, color: 'text.secondary' }} />
            Mon compte
          </MenuItem>
          <MenuItem
            onClick={() => {
              setProfileAnchor(null);
              void getSupabase().auth.signOut();
            }}
            sx={{ color: 'error.main' }}
          >
            <LogoutRoundedIcon sx={{ fontSize: 17, mr: 1.25 }} />
            Déconnexion
          </MenuItem>
        </Menu>
      </Box>
    </Box>
  );
};

export default Header;
