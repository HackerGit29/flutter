import React, { useState } from 'react';
import {
  Alert, Box, Button, Card, Chip, CircularProgress, InputAdornment, Table,
  TableBody, TableCell, TableContainer, TableHead, TableRow, TextField, Typography,
} from '@mui/material';
import SearchRoundedIcon from '@mui/icons-material/SearchRounded';
import FileDownloadRoundedIcon from '@mui/icons-material/FileDownloadRounded';
import { useQuery } from '@tanstack/react-query';
import { AdminApiError } from '../api/client';
import { listFusedAudit } from '../api/operations';
import { useAppStore } from '../store/useAppStore';

export const AuditPage: React.FC = () => {
  const language = useAppStore((state) => state.language);
  const [search, setSearch] = useState('');
  const query = useQuery({
    queryKey: ['admin-api', 'audit', 'all'],
    queryFn: () => listFusedAudit({ page: 1, page_size: 100, source: 'all' }),
  });
  const logs = (query.data?.data ?? []).filter((log) =>
    [log.action, log.target_id ?? '', log.actor_email ?? '', JSON.stringify(log.details)]
      .some((value) => value.toLowerCase().includes(search.toLowerCase())),
  );
  const exportCsv = () => {
    const escape = (value: unknown) => `"${String(value ?? '').replace(/"/g, '""')}"`;
    const rows = [
      ['Timestamp', 'Source', 'Actor', 'Action', 'Target type', 'Target ID', 'Status', 'Details'],
      ...logs.map((log) => [log.at, log.source, log.actor_email ?? log.actor_id, log.action, log.target_type, log.target_id, log.status, JSON.stringify(log.details)]),
    ];
    const csv = rows.map((row) => row.map(escape).join(',')).join('\r\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8;' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = 'aricie-audit.csv';
    link.click();
    URL.revokeObjectURL(url);
  };
  const errorMessage = query.error instanceof AdminApiError || query.error instanceof Error ? query.error.message : 'Erreur API';

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 2, flexWrap: 'wrap' }}>
        <Box><Typography variant="h1" sx={{ fontSize: { xs: '1.6rem', md: '2.2rem' }, fontWeight: 700, color: '#fff' }}>{language === 'fr' ? 'Journal d’audit' : 'Audit log'}</Typography><Typography sx={{ color: '#8e94a3', fontSize: '.88rem', mt: .5 }}>{language === 'fr' ? 'Événements retournés par admin-api.' : 'Events returned by admin-api.'}</Typography></Box>
        <Button variant="outlined" onClick={exportCsv} disabled={!logs.length} startIcon={<FileDownloadRoundedIcon />}>{language === 'fr' ? 'Exporter les résultats CSV' : 'Export results CSV'}</Button>
      </Box>
      {query.error && <Alert severity="error" action={<Button color="inherit" onClick={() => void query.refetch()}>{language === 'fr' ? 'Réessayer' : 'Retry'}</Button>}>{errorMessage}</Alert>}
      {query.isLoading && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 4 }}><CircularProgress /></Box>}
      <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', p: 2 }}><TextField fullWidth size="small" value={search} onChange={(event) => setSearch(event.target.value)} placeholder={language === 'fr' ? 'Rechercher dans les événements…' : 'Search events…'} slotProps={{ input: { startAdornment: <InputAdornment position="start"><SearchRoundedIcon /></InputAdornment> } }} /></Card>
      <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', overflow: 'hidden' }}>
        <TableContainer><Table size="small"><TableHead sx={{ backgroundColor: '#14161a' }}><TableRow>{['Date', 'Source', language === 'fr' ? 'Acteur' : 'Actor', language === 'fr' ? 'Action' : 'Action', language === 'fr' ? 'Cible' : 'Target', language === 'fr' ? 'Statut' : 'Status', language === 'fr' ? 'Détails' : 'Details'].map((label) => <TableCell key={label} sx={{ color: '#8e94a3', fontWeight: 700 }}>{label}</TableCell>)}</TableRow></TableHead>
          <TableBody>{logs.map((log) => <TableRow key={`${log.source}:${log.id}`} hover>
            <TableCell sx={{ color: '#cfd4dc', whiteSpace: 'nowrap' }}>{new Date(log.at).toLocaleString()}</TableCell>
            <TableCell><Chip size="small" label={log.source} /></TableCell>
            <TableCell sx={{ color: '#e0e4ec' }}>{log.actor_email ?? log.actor_id ?? '—'}</TableCell>
            <TableCell sx={{ color: '#fff' }}>{log.action}</TableCell>
            <TableCell sx={{ color: '#cfd4dc' }}>{[log.target_type, log.target_id].filter(Boolean).join(' · ') || '—'}</TableCell>
            <TableCell sx={{ color: '#cfd4dc' }}>{log.status ?? '—'}</TableCell>
            <TableCell sx={{ color: '#8e94a3', maxWidth: 360, overflowWrap: 'anywhere' }}>{JSON.stringify(log.details)}</TableCell>
          </TableRow>)}
          {!logs.length && !query.isLoading && !query.error && <TableRow><TableCell colSpan={7} align="center" sx={{ color: '#8e94a3', py: 4 }}>{language === 'fr' ? 'Aucun événement sur cette période.' : 'No events in this period.'}</TableCell></TableRow>}</TableBody>
        </Table></TableContainer>
      </Card>
    </Box>
  );
};
