import React from 'react';
import {
  Box,
  Divider,
  Drawer,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  useTheme,
} from '@mui/material';
import { useLocation, useNavigate } from 'react-router-dom';
import BoltRoundedIcon from '@mui/icons-material/BoltRounded';
import { Sidebar } from './Sidebar';
import { Header } from './Header';
import { BOTTOM_NAV_ITEMS, NAV_ITEMS } from '../../config/navigation';
import { useAppStore } from '../../store/useAppStore';
import { hasLevel } from '../../types/admin';

interface LayoutProps {
  children: React.ReactNode;
}

/**
 * Coquille applicative : barre latérale, en-tête et zone de contenu.
 *
 * Toutes les surfaces viennent du thème (`background.default`,
 * `background.paper`, `divider`), donc la coquille suit le mode clair/sombre
 * sans aucun branchement conditionnel.
 */
export const Layout: React.FC<LayoutProps> = ({ children }) => {
  const theme = useTheme();
  const navigate = useNavigate();
  const location = useLocation();
  const { isMobileMenuOpen, setIsMobileMenuOpen, session } = useAppStore();

  const visibleItems = [...NAV_ITEMS, ...BOTTOM_NAV_ITEMS].filter((item) =>
    hasLevel(session?.level ?? null, item.minLevel),
  );

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh', backgroundColor: 'background.default' }}>
      <Sidebar />

      <Drawer
        anchor="left"
        open={isMobileMenuOpen}
        onClose={() => setIsMobileMenuOpen(false)}
        slotProps={{ paper: { sx: { width: 280, p: 2 } } }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, px: 1.5, py: 2 }}>
          <BoltRoundedIcon sx={{ fontSize: 30, color: 'primary.main' }} />
          <Box>
            <Typography variant="h4" sx={{ letterSpacing: '-0.01em' }}>
              Aricie
            </Typography>
            <Typography sx={{ fontSize: '0.6875rem', color: 'text.secondary' }}>Backoffice</Typography>
          </Box>
        </Box>

        <Divider sx={{ mb: 1.5 }} />

        <List sx={{ px: 0.5 }} disablePadding>
          {visibleItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <ListItemButton
                key={item.path}
                selected={isActive}
                onClick={() => {
                  navigate(item.path);
                  setIsMobileMenuOpen(false);
                }}
                sx={{ mb: 0.5, py: 1 }}
              >
                <ListItemIcon sx={{ color: isActive ? 'primary.main' : 'text.secondary' }}>
                  {item.icon}
                </ListItemIcon>
                <ListItemText
                  primary={item.label}
                  secondary={item.hint}
                  slotProps={{
                    primary: { sx: { fontSize: '0.875rem', fontWeight: isActive ? 700 : 500 } },
                    secondary: { sx: { fontSize: '0.6875rem' } },
                  }}
                />
              </ListItemButton>
            );
          })}
        </List>
      </Drawer>

      <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        <Header />
        <Box
          component="main"
          sx={{
            flex: 1,
            px: { xs: 2, sm: 3, md: 4 },
            py: { xs: 2.5, md: 3.5 },
            maxWidth: 1680,
            width: '100%',
            mx: 'auto',
          }}
        >
          {children}
        </Box>
      </Box>
    </Box>
  );
};

export default Layout;
