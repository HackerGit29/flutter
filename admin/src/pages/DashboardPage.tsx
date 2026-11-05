import React from 'react';
import { Alert, Box, Card, CircularProgress, Typography } from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { getKpiSummary } from '../api/operations';
import { useAppStore } from '../store/useAppStore';

/**
 * Formate un compteur sans jamais planter : un champ absent ou `null`
 * (contrat non respecté, agrégat indisponible) s'affiche « — » au lieu de
 * faire tomber tout le tableau de bord sur `undefined.toLocaleString()`.
 */
const formatCount = (value: number | null | undefined): string =>
  typeof value === 'number' && Number.isFinite(value) ? value.toLocaleString('fr-FR') : '—';

export const DashboardPage: React.FC = () => {
  const language = useAppStore((state) => state.language);
  const formatCurrency = useAppStore((state) => state.formatCurrency);
  const period = useAppStore((state) => state.period);
  const query = useQuery({
    queryKey: ['admin-api', 'kpi', 'summary', period],
    queryFn: () => getKpiSummary(period),
  });
  const summary = query.data;
  const metrics = summary ? [
    { label: language === 'fr' ? 'Utilisateurs' : 'Users', value: formatCount(summary.total_users) },
    { label: language === 'fr' ? 'Boîtiers en ligne' : 'Online boxes', value: `${formatCount(summary.online_boxes)} / ${formatCount(summary.total_boxes)}` },
    { label: language === 'fr' ? 'MRR VIP' : 'VIP MRR', value: formatCurrency(summary.mrr_vip) },
    { label: language === 'fr' ? 'Énergie sur 30 jours' : 'Energy (30 days)', value: `${formatCount(summary.total_kwh_30d)} kWh` },
    { label: language === 'fr' ? 'Utilisateurs actifs (30 j)' : 'Active users (30d)', value: formatCount(summary.active_users_30d) },
    { label: language === 'fr' ? 'Nouveaux utilisateurs' : 'New users', value: formatCount(summary.new_users) },
    { label: language === 'fr' ? 'Messages agent (30 j)' : 'Agent messages (30d)', value: formatCount(summary.agent_messages_30d) },
    { label: language === 'fr' ? 'Commandes acquittées' : 'Device success rate', value: typeof summary.device_success_rate === 'number' ? `${(summary.device_success_rate * 100).toFixed(1)}%` : '—' },
  ] : [];

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: { xs: 2.5, md: 3.5 } }}>
      {query.isLoading && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 5 }}><CircularProgress /></Box>}
      {query.error && <Alert severity="error" action={<Typography component="button" onClick={() => void query.refetch()} sx={{ color: 'inherit', cursor: 'pointer' }}>{language === 'fr' ? 'Réessayer' : 'Retry'}</Typography>}>{query.error instanceof Error ? query.error.message : 'Erreur API'}</Alert>}
      {summary && <>
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)', lg: 'repeat(4, 1fr)' }, gap: 2 }}>
          {metrics.map((metric) => <Card key={metric.label} sx={{ backgroundColor: 'background.paper', border: '1px solid', borderColor: 'divider', p: 2.2 }}>
            <Typography sx={{ fontSize: '0.78rem', color: 'text.secondary', fontWeight: 600 }}>{metric.label}</Typography>
            <Typography sx={{ fontSize: '1.6rem', fontWeight: 700, color: 'primary.main', mt: 1 }}>{metric.value}</Typography>
          </Card>)}
        </Box>
        <Typography sx={{ color: 'text.secondary', fontSize: '0.8rem' }}>
          {language === 'fr' ? `Période : ${period}. Métriques calculées par admin-api.` : `Period: ${period}. Metrics calculated by admin-api.`}
        </Typography>
      </>}
    </Box>
  );
};
