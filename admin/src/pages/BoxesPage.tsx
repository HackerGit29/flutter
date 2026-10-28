import React, { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  Chip,
  CircularProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAppStore, useMaskedEmail } from '../store/useAppStore';
import { AdminApiError } from '../api/client';
import { getIotHealth, listBoxes, listIotCommands, retryIotCommand } from '../api/operations';
import type { IotCommand } from '../api/operations';

const formatTimestamp = (value: string | null) => value ? new Date(value).toLocaleString() : '—';

export const BoxesPage: React.FC = () => {
  const language = useAppStore((state) => state.language);
  const level = useAppStore((state) => state.session?.level ?? null);
  const mask = useMaskedEmail();
  const queryClient = useQueryClient();
  const [status, setStatus] = useState('');
  const healthQuery = useQuery({ queryKey: ['admin-api', 'iot', 'health'], queryFn: getIotHealth });
  const boxesQuery = useQuery({ queryKey: ['admin-api', 'boxes', 'fleet'], queryFn: () => listBoxes({ page_size: 100 }) });
  const commandsQuery = useQuery({
    queryKey: ['admin-api', 'iot', 'commands', status],
    queryFn: () => listIotCommands({ page: 1, page_size: 50, status: status as never || undefined }),
  });
  const retryMutation = useMutation({
    mutationFn: retryIotCommand,
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['admin-api', 'iot', 'commands'] }),
        queryClient.invalidateQueries({ queryKey: ['admin-api', 'iot', 'health'] }),
      ]);
    },
  });

  const isLoading = healthQuery.isLoading || boxesQuery.isLoading || commandsQuery.isLoading;
  const error = healthQuery.error ?? boxesQuery.error ?? commandsQuery.error;
  const health = healthQuery.data;
  const boxes = boxesQuery.data?.data ?? [];
  const commands = commandsQuery.data?.data ?? [];
  const canRetry = level === 'operator' || level === 'super_admin';
  const retryable = (command: IotCommand) => command.status === 'failed' || command.status === 'timeout';

  const statusLabel = (value: string) => ({
    pending: language === 'fr' ? 'En attente' : 'Pending',
    processing: language === 'fr' ? 'En cours' : 'Processing',
    sent: language === 'fr' ? 'Envoyée' : 'Sent',
    acknowledged: language === 'fr' ? 'Acquittée' : 'Acknowledged',
    failed: language === 'fr' ? 'Échec' : 'Failed',
    rejected: language === 'fr' ? 'Rejetée' : 'Rejected',
    timeout: language === 'fr' ? 'Délai dépassé' : 'Timeout',
  }[value] ?? value);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box>
        <Typography variant="h1" sx={{ fontSize: { xs: '1.6rem', md: '2.2rem' }, fontWeight: 700, color: '#ffffff', letterSpacing: '-0.02em' }}>
          {language === 'fr' ? 'Parc IoT & Monitoring Boîtiers' : 'IoT Fleet & Box Monitoring'}
        </Typography>
        <Typography sx={{ color: '#8e94a3', fontSize: '0.88rem', mt: 0.5 }}>
          {language === 'fr' ? 'État du parc, commandes et acquittements réels via admin-api.' : 'Live fleet, command and acknowledgement data from admin-api.'}
        </Typography>
      </Box>

      {error && <Alert severity="error" action={<Button color="inherit" size="small" onClick={() => { void healthQuery.refetch(); void boxesQuery.refetch(); void commandsQuery.refetch(); }}>{language === 'fr' ? 'Réessayer' : 'Retry'}</Button>}>
        {error instanceof AdminApiError ? error.message : error instanceof Error ? error.message : 'API error'}
      </Alert>}
      {retryMutation.error && <Alert severity="error">{retryMutation.error instanceof Error ? retryMutation.error.message : 'Retry failed'}</Alert>}
      {retryMutation.isSuccess && <Alert severity="success">{language === 'fr' ? 'La commande a été remise en file.' : 'The command was queued again.'}</Alert>}

      {isLoading && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 5 }}><CircularProgress /></Box>}

      {health && <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)', lg: 'repeat(4, 1fr)' }, gap: 2 }}>
        <Metric label={language === 'fr' ? 'Boîtiers en ligne' : 'Online boxes'} value={`${health.online_boxes} / ${health.total_boxes}`} />
        <Metric label={language === 'fr' ? 'Hors ligne > 24 h' : 'Stale > 24h'} value={health.stale_boxes.toLocaleString()} />
        <Metric label={language === 'fr' ? 'Taux ACK sur 24 h' : '24h ACK rate'} value={`${(health.ack_rate_24h * 100).toFixed(1)}%`} />
        <Metric label={language === 'fr' ? 'Latence p95' : 'p95 latency'} value={health.latency_p95_ms === null ? '—' : `${Math.round(health.latency_p95_ms)} ms`} />
      </Box>}

      {health && <Card sx={{ backgroundColor: '#1c1e22', borderRadius: 0, border: '1px solid rgba(255,255,255,0.05)', p: 2 }}>
        <Typography sx={{ fontWeight: 700, color: '#ffffff', mb: 1 }}>{language === 'fr' ? 'Firmware déployé' : 'Firmware distribution'}</Typography>
        <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
          {health.firmware_distribution.map((entry) => <Chip key={entry.version} label={`${entry.version} · ${entry.count}`} size="small" sx={{ borderRadius: 0 }} />)}
          {!health.firmware_distribution.length && <Typography sx={{ color: '#8e94a3' }}>—</Typography>}
        </Box>
      </Card>}

      <Card sx={{ backgroundColor: '#1c1e22', borderRadius: 0, border: '1px solid rgba(255,255,255,0.05)', overflow: 'hidden' }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 1, p: 2 }}>
          <Typography sx={{ fontWeight: 700, color: '#ffffff' }}>{language === 'fr' ? `Commandes (${commandsQuery.data?.total ?? 0})` : `Commands (${commandsQuery.data?.total ?? 0})`}</Typography>
          <Box sx={{ display: 'flex', gap: 0.75, flexWrap: 'wrap' }}>
            {['', 'pending', 'sent', 'acknowledged', 'failed', 'timeout'].map((item) => <Chip key={item || 'all'} clickable label={item ? statusLabel(item) : language === 'fr' ? 'Toutes' : 'All'} onClick={() => setStatus(item)} color={status === item ? 'primary' : 'default'} size="small" sx={{ borderRadius: 0 }} />)}
          </Box>
        </Box>
        <TableContainer>
          <Table size="small">
            <TableHead sx={{ backgroundColor: '#14161a' }}><TableRow>
              <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Action / Appareil' : 'Action / appliance'}</TableCell>
              <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Statut' : 'Status'}</TableCell>
              <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Créée' : 'Created'}</TableCell>
              <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Acquittement / latence' : 'Acknowledgement / latency'}</TableCell>
              <TableCell align="right" sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Action' : 'Action'}</TableCell>
            </TableRow></TableHead>
            <TableBody>
              {commands.map((command) => <TableRow key={command.id} hover>
                <TableCell>
                  <Typography sx={{ color: '#ffffff', fontFamily: 'monospace' }}>{command.action.toUpperCase()}</Typography>
                  <Typography sx={{ color: '#8e94a3', fontSize: '0.75rem' }}>{command.appliance_name ?? command.box_id}</Typography>
                </TableCell>
                <TableCell><Chip label={statusLabel(command.status)} size="small" sx={{ borderRadius: 0 }} /></TableCell>
                <TableCell sx={{ color: '#e0e4ec' }}>{formatTimestamp(command.created_at)}</TableCell>
                <TableCell sx={{ color: '#e0e4ec' }}>{command.acknowledged_at ? `${formatTimestamp(command.acknowledged_at)}${command.latency_ms === null ? '' : ` · ${Math.round(command.latency_ms)} ms`}` : command.error_message ?? '—'}</TableCell>
                <TableCell align="right">{retryable(command) && <Button size="small" variant="outlined" disabled={!canRetry || retryMutation.isPending} onClick={() => retryMutation.mutate(command.id)}>{language === 'fr' ? 'Relancer' : 'Retry'}</Button>}</TableCell>
              </TableRow>)}
              {!commands.length && !commandsQuery.isLoading && <TableRow><TableCell colSpan={5} align="center" sx={{ color: '#8e94a3', py: 4 }}>{language === 'fr' ? 'Aucune commande pour ce filtre.' : 'No commands for this filter.'}</TableCell></TableRow>}
            </TableBody>
          </Table>
        </TableContainer>
      </Card>

      <Card sx={{ backgroundColor: '#1c1e22', borderRadius: 0, border: '1px solid rgba(255,255,255,0.05)', overflow: 'hidden' }}>
        <Box sx={{ p: 2 }}><Typography sx={{ fontWeight: 700, color: '#ffffff' }}>{language === 'fr' ? `Parc des boîtiers (${boxesQuery.data?.total ?? 0})` : `Box fleet (${boxesQuery.data?.total ?? 0})`}</Typography></Box>
        <TableContainer><Table size="small"><TableHead sx={{ backgroundColor: '#14161a' }}><TableRow>
          <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>UID / {language === 'fr' ? 'Nom' : 'Name'}</TableCell>
          <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Propriétaire' : 'Owner'}</TableCell>
          <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Statut' : 'Status'}</TableCell>
          <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>{language === 'fr' ? 'Dernière synchro' : 'Last sync'}</TableCell>
          <TableCell sx={{ color: '#8e94a3', fontWeight: 700 }}>Firmware</TableCell>
        </TableRow></TableHead><TableBody>
          {boxes.map((box) => <TableRow key={box.id} hover>
            <TableCell><Typography sx={{ color: '#ffffff', fontFamily: 'monospace' }}>{box.uid_hardware ?? box.id}</Typography><Typography sx={{ color: '#8e94a3', fontSize: '0.75rem' }}>{box.name}</Typography></TableCell>
            <TableCell sx={{ color: '#e0e4ec' }}>{mask(box.user_email)}</TableCell>
            <TableCell><Chip label={box.online ? language === 'fr' ? 'En ligne' : 'Online' : box.status} size="small" sx={{ borderRadius: 0 }} /></TableCell>
            <TableCell sx={{ color: '#e0e4ec' }}>{formatTimestamp(box.last_sync)}</TableCell>
            <TableCell sx={{ color: '#e0e4ec' }}>{box.firmware_version ?? '—'}</TableCell>
          </TableRow>)}
          {!boxes.length && !boxesQuery.isLoading && <TableRow><TableCell colSpan={5} align="center" sx={{ color: '#8e94a3', py: 4 }}>{language === 'fr' ? 'Aucun boîtier.' : 'No boxes.'}</TableCell></TableRow>}
        </TableBody></Table></TableContainer>
      </Card>
    </Box>
  );
};

function Metric({ label, value }: { label: string; value: string }) {
  return <Card sx={{ backgroundColor: '#1c1e22', borderRadius: 0, border: '1px solid rgba(255,255,255,0.05)', p: 2 }}><Typography sx={{ fontSize: '0.78rem', color: '#8e94a3', fontWeight: 600 }}>{label}</Typography><Typography sx={{ fontSize: '1.6rem', fontWeight: 700, color: '#ffffff', mt: 1 }}>{value}</Typography></Card>;
}
