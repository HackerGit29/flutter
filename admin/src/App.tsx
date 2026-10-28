import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { CssBaseline } from '@mui/material';
import { ThemeProvider } from '@mui/material/styles';
import InitColorSchemeScript from '@mui/material/InitColorSchemeScript';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { muiTheme } from './theme/muiTheme';
import { Layout } from './components/layout/Layout';
import { DashboardPage } from './pages/DashboardPage';
import { CoveragePage } from './pages/CoveragePage';
import { BoxesPage } from './pages/BoxesPage';
import { UsersPage } from './pages/UsersPage';
import { SubscriptionsPage } from './pages/SubscriptionsPage';
import { AgentPage } from './pages/AgentPage';
import { SupportPage } from './pages/SupportPage';
import { AuditPage } from './pages/AuditPage';
import { SettingsPage } from './pages/SettingsPage';
import { AdminAccess } from './components/auth/AdminAccess';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,
      refetchOnWindowFocus: false
    }
  }
});

export default function App() {
  return (
    <>
      {/*
        Pose la classe `.light` / `.dark` sur <html> avant le premier rendu,
        en lisant le choix persisté. Sans ce script, la page s'affiche dans le
        mode par défaut du thème puis bascule — un flash visible.
      */}
      <InitColorSchemeScript defaultMode="system" attribute="class" />

      <QueryClientProvider client={queryClient}>
        <ThemeProvider theme={muiTheme} defaultMode="system">
          <CssBaseline />
          <AdminAccess>
          <BrowserRouter>
            <Layout>
              <Routes>
                {/* Routes du backoffice aricie */}
                <Route path="/" element={<DashboardPage />} />
                <Route path="/coverage" element={<CoveragePage />} />
                <Route path="/boxes" element={<BoxesPage />} />
                <Route path="/users" element={<UsersPage />} />
                <Route path="/subscriptions" element={<SubscriptionsPage />} />
                <Route path="/agent" element={<AgentPage />} />
                <Route path="/support" element={<SupportPage />} />
                <Route path="/audit" element={<AuditPage />} />
                <Route path="/settings" element={<SettingsPage />} />

                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </Layout>
          </BrowserRouter>
          </AdminAccess>
        </ThemeProvider>
      </QueryClientProvider>
    </>
  );
}
