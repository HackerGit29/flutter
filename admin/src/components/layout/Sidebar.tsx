import React from 'react';
import { Box, IconButton, Tooltip, Typography, useMediaQuery, useTheme } from '@mui/material';
import { useLocation, useNavigate } from 'react-router-dom';
import BoltRoundedIcon from '@mui/icons-material/BoltRounded';
import { BOTTOM_NAV_ITEMS, NAV_ITEMS, type NavItem } from '../../config/navigation';
import { useAppStore } from '../../store/useAppStore';
import { hasLevel } from '../../types/admin';

/** Barre latérale compacte (icônes seules) — masquée sur mobile. */
export const Sidebar: React.FC = () => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const navigate = useNavigate();
  const location = useLocation();
  const level = useAppStore((s) => s.session?.level ?? null);

  if (isMobile) return null;

  // Le niveau de session vient du backend : inutile d'afficher une entrée
  // que les routes refuseront de servir.
  const visible = (items: NavItem[]) => items.filter((item) => hasLevel(level, item.minLevel));

  const renderItem = (item: NavItem) => {
    const isActive = location.pathname === item.path;
    return (
      <Tooltip key={item.path} title={`${item.label} — ${item.hint}`} placement="right" arrow>
        <IconButton
          aria-label={item.label}
          aria-current={isActive ? 'page' : undefined}
          onClick={() => navigate(item.path)}
          sx={{
            width: 44,
            height: 44,
            color: isActive ? 'primary.contrastText' : 'text.secondary',
            backgroundColor: isActive ? 'primary.main' : 'action.hover',
            '&:hover': {
              backgroundColor: isActive ? 'primary.dark' : 'action.selected',
              color: isActive ? 'primary.contrastText' : 'text.primary',
              transform: 'translateY(-1px)',
            },
          }}
        >
          {item.icon}
        </IconButton>
      </Tooltip>
    );
  };

  return (
    <Box
      component="nav"
      aria-label="Navigation principale"
      sx={{
        width: 84,
        minWidth: 84,
        height: '100vh',
        position: 'sticky',
        top: 0,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'space-between',
        py: 2.5,
        px: 1.5,
        backgroundColor: 'background.paper',
        borderRight: '1px solid',
        borderColor: 'divider',
        zIndex: (t) => t.zIndex.appBar,
      }}
    >
      <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, width: '100%' }}>
        <Box
          onClick={() => navigate('/')}
          role="button"
          tabIndex={0}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') navigate('/');
          }}
          aria-label="Aricie — accueil du backoffice"
          sx={{
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            mb: 1,
            transition: 'transform 0.2s ease',
            '&:hover': { transform: 'scale(1.08)' },
          }}
        >
          <BoltRoundedIcon sx={{ fontSize: 34, color: 'primary.main' }} />
        </Box>

        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.2, alignItems: 'center' }}>
          {visible(NAV_ITEMS).map(renderItem)}
        </Box>
      </Box>

      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, alignItems: 'center' }}>
        {visible(BOTTOM_NAV_ITEMS).map(renderItem)}

        <Tooltip title={`Aricie Backoffice v${__APP_VERSION__}`} placement="right" arrow>
          <Typography sx={{ fontSize: '0.5625rem', color: 'text.disabled', mt: 1 }}>
            {__APP_VERSION__}
          </Typography>
        </Tooltip>
      </Box>
    </Box>
  );
};

export default Sidebar;
