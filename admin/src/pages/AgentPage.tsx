import React from 'react';
import {
  Alert,
  Box,
  Card,
  CircularProgress,
  Chip,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '../store/useAppStore';
import { getAgentAnalytics } from '../api/operations';

export const AgentPage: React.FC = () => {
  const { language } = useAppStore();
  const query = useQuery({
    queryKey: ['admin-api', 'agent', 'analytics'],
    queryFn: () => getAgentAnalytics(),
  });
  const analytics = query.data;
  const messageCount = analytics?.messages_by_day.reduce((sum, point) => sum + point.value, 0) ?? 0;
  const toolCallCount = analytics?.tools.reduce((sum, tool) => sum + tool.calls_count, 0) ?? 0;
  const blockedCount = analytics?.policy_blocked ?? 0;
  const pendingCount = analytics?.pending_tool_actions_observed ?? 0;
  const successRate = toolCallCount
    ? analytics!.tools.reduce((sum, tool) => sum + tool.success_rate * tool.calls_count, 0) / toolCallCount
    : 0;

  const funnelSteps = [
    { label: language === 'fr' ? 'Messages enregistrés (30 j)' : 'Recorded messages (30d)', count: messageCount, percent: 100, color: '#4B7BFF' },
    { label: language === 'fr' ? 'Appels d’outils observés' : 'Observed tool calls', count: toolCallCount, percent: messageCount ? Math.min(100, (toolCallCount / messageCount) * 100) : 0, color: '#7ba0ff' },
    { label: language === 'fr' ? 'Actions en attente observées' : 'Observed pending actions', count: pendingCount, percent: toolCallCount ? Math.min(100, (pendingCount / toolCallCount) * 100) : 0, color: '#ffab00' },
    { label: language === 'fr' ? 'Taux de succès observé' : 'Observed success rate', count: `${(successRate * 100).toFixed(1)}%`, percent: successRate * 100, color: '#52c41a' },
  ];

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box>
        <Typography variant="h1" sx={{ fontSize: { xs: '1.6rem', md: '2.2rem' }, fontWeight: 700, color: '#ffffff', letterSpacing: '-0.02em' }}>
          {language === 'fr' ? 'Analytics Agent IA & Moteur de Politiques' : 'AI Agent Analytics & Policy Engine'}
        </Typography>
        <Typography sx={{ color: '#8e94a3', fontSize: '0.88rem', mt: 0.5 }}>
          {language === 'fr' ? 'Mesures agrégées par admin-api sur les 30 derniers jours.' : 'Aggregates returned by admin-api for the last 30 days.'}
        </Typography>
      </Box>

      {query.isLoading && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 5 }}><CircularProgress /></Box>}
      {query.error && <Alert severity="error" action={<Chip label={language === 'fr' ? 'Réessayer' : 'Retry'} clickable onClick={() => void query.refetch()} />}>
        {query.error instanceof Error ? query.error.message : 'API error'}
      </Alert>}
      {analytics && !analytics.confirmation_events_tracked && <Alert severity="info">
        {language === 'fr'
          ? 'Les confirmations et annulations ne sont pas suivies par la base ; aucune conversion n’est déduite pour ces étapes.'
          : 'The database does not track confirmation/cancellation events; no conversion is inferred for those stages.'}
      </Alert>}

      {analytics && <>
        <Card sx={{ backgroundColor: '#1c1e22', borderRadius: 0, border: '1px solid rgba(255,255,255,0.05)', p: 3 }}>
          <Typography sx={{ fontWeight: 700, fontSize: '0.95rem', color: '#ffffff', mb: 2 }}>
            {language === 'fr' ? 'Indicateurs observés' : 'Observed indicators'}
          </Typography>
          <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)', lg: 'repeat(4, 1fr)' }, gap: 2 }}>
            {funnelSteps.map((step) => (
              <Box key={step.label} sx={{ backgroundColor: '#14161a', p: 2, display: 'flex', flexDirection: 'column', gap: 1 }}>
                <Typography sx={{ fontSize: '0.75rem', color: '#8e94a3', fontWeight: 600 }}>{step.label}</Typography>
                <Typography sx={{ fontSize: '1.4rem', fontWeight: 700, color: step.color }}>{typeof step.count === 'number' ? step.count.toLocaleString() : step.count}</Typography>
                <LinearProgress variant="determinate" value={Math.max(0, Math.min(100, step.percent))} sx={{ height: 6, borderRadius: 0, backgroundColor: 'rgba(255,255,255,0.05)', '& .MuiLinearProgress-bar': { backgroundColor: step.color } }} />
              </Box>
            ))}
          </Box>
          <Typography sx={{ fontSize: '0.75rem', color: '#8e94a3', mt: 2 }}>
            {language === 'fr' ? `Blocages de politique : ${blockedCount.toLocaleString()}` : `Policy blocks: ${blockedCount.toLocaleString()}`}
          </Typography>
        </Card>

        <Card sx={{ backgroundColor: '#1c1e22', borderRadius: 0, border: '1px solid rgba(255,255,255,0.05)', overflow: 'hidden' }}>
          <Box sx={{ p: 2.5, borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
            <Typography sx={{ fontWeight: 700, fontSize: '0.95rem', color: '#ffffff' }}>
              {language === 'fr' ? 'Outils invoqués par l’agent' : 'Agent invoked tools'}
            </Typography>
          </Box>
          <TableContainer>
            <Table>
              <TableHead sx={{ backgroundColor: '#14161a' }}><TableRow>
                <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Outil' : 'Tool'}</TableCell>
                <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Appels' : 'Calls'}</TableCell>
                <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'En attente' : 'Pending'}</TableCell>
                <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Succès' : 'Success'}</TableCell>
                <TableCell align="right" sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Blocages' : 'Policy blocks'}</TableCell>
              </TableRow></TableHead>
              <TableBody>
                {analytics.tools.map((tool) => <TableRow key={tool.tool_name} hover>
                  <TableCell><Typography sx={{ fontWeight: 700, fontSize: '0.88rem', color: '#ffffff', fontFamily: 'monospace' }}>{tool.tool_name}()</Typography></TableCell>
                  <TableCell sx={{ color: '#e0e4ec' }}>{tool.calls_count.toLocaleString()}</TableCell>
                  <TableCell sx={{ color: '#ffab00' }}>{(tool.confirmation_rate * 100).toFixed(1)}%</TableCell>
                  <TableCell sx={{ color: '#c5ff26' }}>{(tool.success_rate * 100).toFixed(1)}%</TableCell>
                  <TableCell align="right"><Chip label={tool.blocked_by_policy.toLocaleString()} size="small" sx={{ borderRadius: 0, fontWeight: 700, backgroundColor: tool.blocked_by_policy ? 'rgba(255,120,117,0.15)' : 'rgba(255,255,255,0.05)', color: tool.blocked_by_policy ? '#ff7875' : '#8e94a3' }} /></TableCell>
                </TableRow>)}
                {!analytics.tools.length && <TableRow><TableCell colSpan={5} align="center" sx={{ color: '#8e94a3', py: 4 }}>{language === 'fr' ? 'Aucun appel d’outil sur cette période.' : 'No tool calls in this period.'}</TableCell></TableRow>}
              </TableBody>
            </Table>
          </TableContainer>
        </Card>
      </>}
    </Box>
  );
};
