import React from 'react';
import { Alert, Box, Card, CircularProgress, Typography } from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { getKpiSummary } from '../api/operations';
import { useAppStore } from '../store/useAppStore';

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
    { label: language === 'fr' ? 'Utilisateurs' : 'Users', value: summary.total_users.toLocaleString() },
    { label: language === 'fr' ? 'Boîtiers en ligne' : 'Online boxes', value: `${summary.online_boxes.toLocaleString()} / ${summary.total_boxes.toLocaleString()}` },
    { label: language === 'fr' ? 'MRR VIP' : 'VIP MRR', value: formatCurrency(summary.mrr_vip) },
    { label: language === 'fr' ? 'Énergie sur 30 jours' : 'Energy (30 days)', value: `${summary.total_kwh_30d.toLocaleString()} kWh` },
    { label: language === 'fr' ? 'Utilisateurs actifs (30 j)' : 'Active users (30d)', value: summary.active_users_30d.toLocaleString() },
    { label: language === 'fr' ? 'Nouveaux utilisateurs' : 'New users', value: summary.new_users.toLocaleString() },
    { label: language === 'fr' ? 'Messages agent (30 j)' : 'Agent messages (30d)', value: summary.agent_messages_30d.toLocaleString() },
    { label: language === 'fr' ? 'Commandes acquittées' : 'Device success rate', value: `${(summary.device_success_rate * 100).toFixed(1)}%` },
  ] : [];

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: { xs: 2.5, md: 3.5 } }}>
      <Typography variant="h1" sx={{ fontSize: { xs: '1.75rem', sm: '2.1rem', md: '2.4rem' }, fontWeight: 700, letterSpacing: '-0.03em', color: '#ffffff' }}>
        {language === 'fr' ? 'Tableau de bord' : 'Dashboard'}
      </Typography>
      {query.isLoading && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 5 }}><CircularProgress /></Box>}
      {query.error && <Alert severity="error" action={<Typography component="button" onClick={() => void query.refetch()} sx={{ color: 'inherit', cursor: 'pointer' }}>{language === 'fr' ? 'Réessayer' : 'Retry'}</Typography>}>{query.error instanceof Error ? query.error.message : 'Erreur API'}</Alert>}
      {summary && <>
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)', lg: 'repeat(4, 1fr)' }, gap: 2 }}>
          {metrics.map((metric) => <Card key={metric.label} sx={{ backgroundColor: '#1c1e22', borderRadius: 0, border: '1px solid rgba(255,255,255,0.05)', p: 2.2 }}>
            <Typography sx={{ fontSize: '0.78rem', color: '#8e94a3', fontWeight: 600 }}>{metric.label}</Typography>
            <Typography sx={{ fontSize: '1.6rem', fontWeight: 700, color: '#4B7BFF', mt: 1 }}>{metric.value}</Typography>
          </Card>)}
        </Box>
        <Typography sx={{ color: '#8e94a3', fontSize: '0.8rem' }}>
          {language === 'fr' ? `Période : ${period}. Métriques calculées par admin-api.` : `Period: ${period}. Metrics calculated by admin-api.`}
        </Typography>
      </>}
    </Box>
  );
};
