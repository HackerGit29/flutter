import React, { useState } from 'react';
import {
  Alert, Box, Button, Card, Chip, CircularProgress, Dialog, DialogActions,
  DialogContent, DialogTitle, IconButton, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Tooltip, Typography,
} from '@mui/material';
import EditOutlinedIcon from '@mui/icons-material/EditOutlined';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AdminApiError } from '../api/client';
import { getKpiSummary, listSubscriptions, updateSubscription } from '../api/operations';
import { maskEmail, useAppStore } from '../store/useAppStore';
import type { AdminSubscription } from '../types/admin';

export const SubscriptionsPage: React.FC = () => {
  const language = useAppStore((state) => state.language);
  const currency = useAppStore((state) => state.currency);
  const level = useAppStore((state) => state.session?.level ?? null);
  const queryClient = useQueryClient();
  const [selected, setSelected] = useState<AdminSubscription | null>(null);
  const subscriptionsQuery = useQuery({
    queryKey: ['admin-api', 'subscriptions'],
    queryFn: () => listSubscriptions({ page: 1, page_size: 100 }),
  });
  const kpiQuery = useQuery({
    queryKey: ['admin-api', 'kpi', 'summary', 'month'],
    queryFn: () => getKpiSummary('month'),
  });
  const updateMutation = useMutation({
    mutationFn: (sub: AdminSubscription) => updateSubscription(sub.id, {
      is_active: !sub.is_active,
      auto_renew: sub.auto_renew,
    }),
    onSuccess: async () => {
      setSelected(null);
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['admin-api', 'subscriptions'] }),
        queryClient.invalidateQueries({ queryKey: ['admin-api', 'kpi', 'summary'] }),
      ]);
    },
  });
  const subscriptions = subscriptionsQuery.data?.data ?? [];
  const mrrEur = kpiQuery.data?.mrr_vip ?? 0;
  const formatCurrency = (eur: number) => {
    if (currency === 'XAF') return `${new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Math.round(eur * 655.957))} XAF`;
    if (currency === 'USD') return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(eur);
    return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(eur);
  };
  const canEdit = level === 'operator' || level === 'super_admin';
  const error = subscriptionsQuery.error ?? kpiQuery.error;
  const errorMessage = error instanceof AdminApiError || error instanceof Error ? error.message : 'Erreur API';
  const empty = language === 'fr' ? 'Aucune donnée disponible.' : 'No data available.';

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box>
        <Typography variant="h1" sx={{ fontSize: { xs: '1.6rem', md: '2.2rem' }, fontWeight: 700, color: '#fff' }}>{language === 'fr' ? 'Abonnements' : 'Subscriptions'}</Typography>
        <Typography sx={{ color: '#8e94a3', fontSize: '.88rem', mt: .5 }}>{language === 'fr' ? 'Abonnements et indicateurs chargés depuis admin-api.' : 'Subscriptions and metrics loaded from admin-api.'}</Typography>
      </Box>
      {error && <Alert severity="error" action={<Button color="inherit" onClick={() => { void subscriptionsQuery.refetch(); void kpiQuery.refetch(); }}>{language === 'fr' ? 'Réessayer' : 'Retry'}</Button>}>{errorMessage}</Alert>}
      {updateMutation.error && <Alert severity="error">{updateMutation.error instanceof Error ? updateMutation.error.message : 'Erreur API'}</Alert>}
      {(subscriptionsQuery.isLoading || kpiQuery.isLoading) && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 4 }}><CircularProgress /></Box>}
      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' }, gap: 2 }}>
        <Metric label="MRR VIP" value={kpiQuery.data ? formatCurrency(mrrEur) : '—'} />
        <Metric label={language === 'fr' ? 'Abonnés VIP actifs' : 'Active VIP subscribers'} value={kpiQuery.data ? kpiQuery.data.vip_subscribers.toLocaleString() : '—'} />
        <Metric label={language === 'fr' ? 'Taux de churn' : 'Churn rate'} value={kpiQuery.data ? `${(kpiQuery.data.churn_rate * 100).toFixed(1)}%` : '—'} />
      </Box>
      <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', overflow: 'hidden' }}>
        <TableContainer><Table size="small">
          <TableHead sx={{ backgroundColor: '#14161a' }}><TableRow>
            {[language === 'fr' ? 'Client' : 'Customer', language === 'fr' ? 'Formule' : 'Plan', language === 'fr' ? 'Montant mensuel' : 'Monthly amount', language === 'fr' ? 'Statut' : 'Status', language === 'fr' ? 'Échéance' : 'End date', language === 'fr' ? 'Renouvellement auto' : 'Auto-renew', ''].map((label, index) => <TableCell key={`${label}-${index}`} sx={{ color: '#8e94a3', fontWeight: 700 }}>{label}</TableCell>)}
          </TableRow></TableHead>
          <TableBody>
            {subscriptions.map((sub) => <TableRow key={sub.id} hover>
              <TableCell sx={{ color: '#e0e4ec' }}>{maskEmail(sub.user_email ?? '', level)}</TableCell>
              <TableCell><Chip size="small" label={sub.type.toUpperCase()} /></TableCell>
              <TableCell sx={{ color: '#e0e4ec' }}>{formatCurrency(sub.monthly_amount_eur)}</TableCell>
              <TableCell><Chip size="small" color={sub.is_active ? 'success' : 'default'} label={sub.is_active ? (language === 'fr' ? 'Actif' : 'Active') : (language === 'fr' ? 'Inactif' : 'Inactive')} /></TableCell>
              <TableCell sx={{ color: '#e0e4ec' }}>{sub.end_date ? new Date(sub.end_date).toLocaleDateString() : '—'}</TableCell>
              <TableCell sx={{ color: '#e0e4ec' }}>{sub.auto_renew ? (language === 'fr' ? 'Oui' : 'Yes') : (language === 'fr' ? 'Non' : 'No')}</TableCell>
              <TableCell align="right">{canEdit && <Tooltip title={language === 'fr' ? 'Modifier le statut actif' : 'Change active status'}><span><IconButton size="small" disabled={updateMutation.isPending} onClick={() => setSelected(sub)} aria-label={language === 'fr' ? 'Modifier abonnement' : 'Edit subscription'}><EditOutlinedIcon fontSize="small" /></IconButton></span></Tooltip>}</TableCell>
            </TableRow>)}
            {!subscriptions.length && !subscriptionsQuery.isLoading && <TableRow><TableCell colSpan={7} align="center" sx={{ color: '#8e94a3', py: 4 }}>{empty}</TableCell></TableRow>}
          </TableBody>
        </Table></TableContainer>
      </Card>
      <Dialog open={Boolean(selected)} onClose={() => setSelected(null)}>
        <DialogTitle>{selected?.is_active ? (language === 'fr' ? 'Désactiver cet abonnement ?' : 'Deactivate this subscription?') : (language === 'fr' ? 'Réactiver cet abonnement ?' : 'Reactivate this subscription?')}</DialogTitle>
        <DialogContent>{maskEmail(selected?.user_email ?? '', level)}</DialogContent>
        <DialogActions><Button onClick={() => setSelected(null)}>{language === 'fr' ? 'Annuler' : 'Cancel'}</Button><Button disabled={updateMutation.isPending} onClick={() => selected && updateMutation.mutate(selected)}>{language === 'fr' ? 'Confirmer' : 'Confirm'}</Button></DialogActions>
      </Dialog>
    </Box>
  );
};

function Metric({ label, value }: { label: string; value: string }) {
  return <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', p: 2 }}><Typography sx={{ color: '#8e94a3', fontSize: '.78rem' }}>{label}</Typography><Typography sx={{ color: '#fff', fontSize: '1.5rem', fontWeight: 700, mt: 1 }}>{value}</Typography></Card>;
}
