import React from 'react';
import '@testing-library/jest-dom/vitest';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { ThemeProvider } from '@mui/material';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { muiTheme } from '../theme/muiTheme';
import { useAppStore, maskEmail } from '../store/useAppStore';
import { CoveragePage } from '../pages/CoveragePage';
import { BoxesPage } from '../pages/BoxesPage';
import { UsersPage } from '../pages/UsersPage';
import { SubscriptionsPage } from '../pages/SubscriptionsPage';
import { AgentPage } from '../pages/AgentPage';
import { AuditPage } from '../pages/AuditPage';
import { listUsers, listSubscriptions, listFusedAudit } from '../api/operations';

vi.mock('../api/operations', () => ({
  getCoverage: vi.fn(),
  getHeatmap: vi.fn(),
  getIotHealth: vi.fn(),
  listBoxes: vi.fn(),
  listIotCommands: vi.fn(),
  listUsers: vi.fn(),
  listSubscriptions: vi.fn(),
  listFusedAudit: vi.fn(),
  getAgentAnalytics: vi.fn(),
  getKpiSummary: vi.fn(),
  retryIotCommand: vi.fn(),
}));

const renderWithProviders = (ui: React.ReactElement) => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 } },
  });
  return render(
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={muiTheme}><BrowserRouter>{ui}</BrowserRouter></ThemeProvider>
    </QueryClientProvider>,
  );
};

describe('Aricie Backoffice production data behavior', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useAppStore.setState({ language: 'fr', currency: 'EUR', session: { id: 'admin-id', email: 'admin@example.fr', level: 'super_admin', accessToken: 'token', expiresAt: null } });
    vi.mocked(listUsers).mockResolvedValue({ data: [], page: 1, page_size: 100, total: 0 });
    vi.mocked(listSubscriptions).mockResolvedValue({ data: [], page: 1, page_size: 100, total: 0 });
    vi.mocked(listFusedAudit).mockResolvedValue({ data: [], page: 1, page_size: 100, total: 0 });
  });

  it('masks emails for viewers and reveals them only to operators/admins', () => {
    expect(maskEmail('sophie.martin@example.fr', 'viewer')).toBe('s***n@ex***.fr');
    expect(maskEmail('sophie.martin@example.fr', 'operator')).toBe('sophie.martin@example.fr');
  });

  it('renders coverage without fictional geographic clusters when API data is empty', async () => {
    vi.mocked((await import('../api/operations')).getCoverage).mockResolvedValue({ precision: 5, clusters: [], zones: [], total_boxes: 0, unlocated_boxes: 0 });
    vi.mocked((await import('../api/operations')).getHeatmap).mockResolvedValue({ metric: 'boxes', from: '', to: '', points: [] });
    renderWithProviders(<CoveragePage />);
    expect(await screen.findByText('Aucune donnée de couverture disponible.')).toBeInTheDocument();
    expect(screen.queryByText('Île-de-France & Grand Paris')).not.toBeInTheDocument();
  });

  it('renders an empty IoT fleet instead of demo ACK rates and serial numbers', async () => {
    const operations = await import('../api/operations');
    vi.mocked(operations.getIotHealth).mockResolvedValue({ total_boxes: 0, online_boxes: 0, offline_boxes: 0, stale_boxes: 0, commands_24h: 0, ack_rate_24h: 0, latency_p50_ms: null, latency_p95_ms: null, top_errored_boxes: [], firmware_distribution: [] });
    vi.mocked(operations.listBoxes).mockResolvedValue({ data: [], page: 1, page_size: 100, total: 0 });
    vi.mocked(operations.listIotCommands).mockResolvedValue({ data: [], page: 1, page_size: 50, total: 0 });
    renderWithProviders(<BoxesPage />);
    expect(await screen.findByText('Aucun boîtier.')).toBeInTheDocument();
    expect(screen.queryByText('ARC-2026-FR-09412')).not.toBeInTheDocument();
    expect(screen.queryByText('98.4%')).not.toBeInTheDocument();
  });

  it('shows no users when admin-api returns an empty list', async () => {
    renderWithProviders(<UsersPage />);
    expect(await screen.findByText('Aucun utilisateur trouvé.')).toBeInTheDocument();
    expect(listUsers).toHaveBeenCalled();
    expect(screen.queryByText('s***n@ex***.fr')).not.toBeInTheDocument();
  });

  it('shows no subscriptions rather than made-up MRR and churn figures', async () => {
    const operations = await import('../api/operations');
    vi.mocked(operations.getKpiSummary).mockResolvedValue({ period: 'month', total_users: 0, active_users_30d: 0, new_users: 0, churn_rate: 0, vip_subscribers: 0, mrr_vip: 0, total_boxes: 0, online_boxes: 0, total_kwh_30d: 0, agent_messages_30d: 0, device_success_rate: 0 });
    renderWithProviders(<SubscriptionsPage />);
    expect(await screen.findByText('Aucune donnée disponible.')).toBeInTheDocument();
    expect(listSubscriptions).toHaveBeenCalled();
    expect(screen.queryByText('45 562,20 XAF')).not.toBeInTheDocument();
    expect(screen.queryByText('2.1%')).not.toBeInTheDocument();
  });

  it('renders agent analytics with an empty-state message', async () => {
    const operations = await import('../api/operations');
    vi.mocked(operations.getAgentAnalytics).mockResolvedValue({ messages_by_day: [], tool_calls_by_day: [], tools: [], tool_pending_confirmed: null, tool_pending_canceled: null, policy_blocked: 0, confirmation_events_tracked: false, pending_tool_actions_observed: 0 });
    renderWithProviders(<AgentPage />);
    expect(await screen.findByText('Aucun appel d’outil sur cette période.')).toBeInTheDocument();
    expect(screen.queryByText('optimize_heating_schedule()')).not.toBeInTheDocument();
  });

  it('renders audit entries returned from the real audit API and no compliance claims', async () => {
    vi.mocked(listFusedAudit).mockResolvedValue({ data: [{ id: 'log-1', source: 'admin', at: '2026-10-28T10:00:00Z', action: 'suspend_user', target_type: 'user', target_id: 'user-1', actor_id: 'admin-1', actor_email: 'admin@example.fr', status: null, details: {} }], page: 1, page_size: 100, total: 1 });
    renderWithProviders(<AuditPage />);
    expect(await screen.findByText('suspend_user')).toBeInTheDocument();
    expect(listFusedAudit).toHaveBeenCalled();
    expect(screen.queryByText('Conformité Active : SOC2 Type II & RGPD Ready')).not.toBeInTheDocument();
  });
});
