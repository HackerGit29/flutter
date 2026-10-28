import React, { useState } from 'react';
import {
  Alert, Box, Button, Card, Chip, CircularProgress, Dialog, DialogActions,
  DialogContent, DialogTitle, Drawer, IconButton, InputAdornment, Table,
  TableBody, TableCell, TableContainer, TableHead, TableRow, TextField, Typography,
} from '@mui/material';
import SearchRoundedIcon from '@mui/icons-material/SearchRounded';
import PersonOutlineRoundedIcon from '@mui/icons-material/PersonOutlineRounded';
import CloseRoundedIcon from '@mui/icons-material/CloseRounded';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AdminApiError } from '../api/client';
import { createAdminNote, getUser, listAdminNotes, listUsers, updateUserStatus } from '../api/operations';
import { maskEmail, useAppStore } from '../store/useAppStore';
import type { AdminUserListItem } from '../api/operations';

export const UsersPage: React.FC = () => {
  const language = useAppStore((state) => state.language);
  const level = useAppStore((state) => state.session?.level ?? null);
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [userToUpdate, setUserToUpdate] = useState<AdminUserListItem | null>(null);
  const [noteBody, setNoteBody] = useState('');
  const usersQuery = useQuery({
    queryKey: ['admin-api', 'users', search],
    queryFn: () => listUsers({ page: 1, page_size: 100, q: search.trim() || undefined }),
  });
  const profileQuery = useQuery({
    queryKey: ['admin-api', 'users', selectedId],
    queryFn: () => getUser(selectedId!),
    enabled: Boolean(selectedId),
  });
  const notesQuery = useQuery({
    queryKey: ['admin-api', 'notes', 'user', selectedId],
    queryFn: () => listAdminNotes({ page: 1, page_size: 50, target_type: 'user', target_id: selectedId! }),
    enabled: Boolean(selectedId) && (level === 'operator' || level === 'super_admin'),
  });
  const statusMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: 'active' | 'suspended' }) => updateUserStatus(id, status),
    onSuccess: async () => {
      setUserToUpdate(null);
      await queryClient.invalidateQueries({ queryKey: ['admin-api', 'users'] });
      if (selectedId) await queryClient.invalidateQueries({ queryKey: ['admin-api', 'users', selectedId] });
    },
  });
  const noteMutation = useMutation({
    mutationFn: () => createAdminNote({ target_type: 'user', target_id: selectedId!, body: noteBody.trim() }),
    onSuccess: async () => {
      setNoteBody('');
      await queryClient.invalidateQueries({ queryKey: ['admin-api', 'notes', 'user', selectedId] });
    },
  });
  const users = usersQuery.data?.data ?? [];
  const profile = profileQuery.data;
  const canManage = level === 'operator' || level === 'super_admin';
  const error = usersQuery.error ?? profileQuery.error;
  const displayError = (cause: unknown) => cause instanceof AdminApiError || cause instanceof Error ? cause.message : 'Erreur API';

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box>
        <Typography variant="h1" sx={{ fontSize: { xs: '1.6rem', md: '2.2rem' }, fontWeight: 700, color: '#fff' }}>
          {language === 'fr' ? 'Clients' : 'Users'}
        </Typography>
        <Typography sx={{ color: '#8e94a3', fontSize: '0.88rem', mt: 0.5 }}>
          {language === 'fr' ? 'Comptes, abonnements et boîtiers chargés depuis admin-api.' : 'Accounts, subscriptions and boxes loaded from admin-api.'}
        </Typography>
      </Box>
      {error && <Alert severity="error" action={<Button color="inherit" onClick={() => void usersQuery.refetch()}>{language === 'fr' ? 'Réessayer' : 'Retry'}</Button>}>{displayError(error)}</Alert>}
      {statusMutation.error && <Alert severity="error">{displayError(statusMutation.error)}</Alert>}
      {noteMutation.error && <Alert severity="error">{displayError(noteMutation.error)}</Alert>}
      <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', p: 2 }}>
        <TextField
          fullWidth size="small" value={search} onChange={(event) => setSearch(event.target.value)}
          placeholder={language === 'fr' ? 'Rechercher par e-mail…' : 'Search by email…'}
          slotProps={{ input: { startAdornment: <InputAdornment position="start"><SearchRoundedIcon /></InputAdornment> } }}
        />
      </Card>
      {usersQuery.isLoading && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 5 }}><CircularProgress /></Box>}
      <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', overflow: 'hidden' }}>
        <TableContainer><Table size="small">
          <TableHead sx={{ backgroundColor: '#14161a' }}><TableRow>
            <TableCell sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Compte' : 'Account'}</TableCell>
            <TableCell sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Rôle' : 'Role'}</TableCell>
            <TableCell sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Abonnement' : 'Subscription'}</TableCell>
            <TableCell sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Boîtiers' : 'Boxes'}</TableCell>
            <TableCell sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Statut' : 'Status'}</TableCell>
            <TableCell align="right" sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Actions' : 'Actions'}</TableCell>
          </TableRow></TableHead>
          <TableBody>
            {users.map((user) => <TableRow key={user.id} hover>
              <TableCell><Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}><PersonOutlineRoundedIcon color="primary" /><Box><Typography sx={{ color: '#fff', fontWeight: 600 }}>{maskEmail(user.email, level)}</Typography><Typography sx={{ color: '#8e94a3', fontSize: '.75rem' }}>{new Date(user.created_at).toLocaleDateString()}</Typography></Box></Box></TableCell>
              <TableCell sx={{ color: '#e0e4ec' }}>{user.role}</TableCell>
              <TableCell><Chip size="small" label={user.subscription ? `${user.subscription.type.toUpperCase()}${user.subscription.is_active ? '' : ' · inactive'}` : '—'} /></TableCell>
              <TableCell sx={{ color: '#e0e4ec' }}>{user.box_count}</TableCell>
              <TableCell><Chip size="small" color={user.status === 'active' ? 'success' : 'error'} label={user.status} /></TableCell>
              <TableCell align="right"><Button size="small" onClick={() => setSelectedId(user.id)}>{language === 'fr' ? 'Détails' : 'Details'}</Button>{canManage && <Button size="small" color={user.status === 'active' ? 'error' : 'success'} disabled={statusMutation.isPending} onClick={() => setUserToUpdate(user)}>{user.status === 'active' ? (language === 'fr' ? 'Suspendre' : 'Suspend') : (language === 'fr' ? 'Réactiver' : 'Activate')}</Button>}</TableCell>
            </TableRow>)}
            {!users.length && !usersQuery.isLoading && <TableRow><TableCell colSpan={6} align="center" sx={{ color: '#8e94a3', py: 4 }}>{language === 'fr' ? 'Aucun utilisateur trouvé.' : 'No users found.'}</TableCell></TableRow>}
          </TableBody>
        </Table></TableContainer>
      </Card>
      <Drawer anchor="right" open={Boolean(selectedId)} onClose={() => setSelectedId(null)} slotProps={{ paper: { sx: { width: { xs: '100%', sm: 520 }, backgroundColor: '#1c1e22', color: '#fff', p: 3 } } }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}><Typography variant="h2" sx={{ fontSize: '1.25rem' }}>{language === 'fr' ? 'Profil client' : 'User profile'}</Typography><IconButton onClick={() => setSelectedId(null)} aria-label="Fermer"><CloseRoundedIcon /></IconButton></Box>
        {profileQuery.isLoading && <CircularProgress />}
        {profileQuery.error && <Alert severity="error">{displayError(profileQuery.error)}</Alert>}
        {profile && <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <Card sx={{ backgroundColor: '#14161a', p: 2 }}>
            <Typography sx={{ color: '#fff' }}>{maskEmail(profile.email, level)}</Typography>
            <Typography sx={{ color: '#8e94a3' }}>{profile.role} · {profile.status} · {new Date(profile.created_at).toLocaleDateString()}</Typography>
            <Typography sx={{ color: '#cfd4dc', mt: 1 }}>{language === 'fr' ? 'Boîtiers' : 'Boxes'}: {profile.totals.box_count} · {language === 'fr' ? 'Commandes 30 j' : 'Commands 30d'}: {profile.totals.commands_30d}</Typography>
            <Typography sx={{ color: '#cfd4dc' }}>{language === 'fr' ? 'Énergie 30 j' : 'Energy 30d'}: {profile.totals.kwh_30d} kWh · {language === 'fr' ? 'Année' : 'Year'}: {profile.totals.kwh_year} kWh</Typography>
            <Typography sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Dernière synchronisation' : 'Last sync'}: {profile.last_sync ? new Date(profile.last_sync).toLocaleString() : '—'}</Typography>
          </Card>
          <Typography sx={{ fontWeight: 700 }}>{language === 'fr' ? 'Abonnement' : 'Subscription'}</Typography>
          {profile.subscription ? <Typography sx={{ color: '#cfd4dc' }}>{profile.subscription.type} · {profile.subscription.is_active ? 'active' : 'inactive'} · {profile.subscription.end_date ? new Date(profile.subscription.end_date).toLocaleDateString() : '—'}</Typography> : <Typography sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Aucun abonnement.' : 'No subscription.'}</Typography>}
          <Typography sx={{ fontWeight: 700 }}>{language === 'fr' ? 'Boîtiers associés' : 'Linked boxes'}</Typography>
          {!profile.boxes.length && <Typography sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Aucun boîtier associé.' : 'No linked boxes.'}</Typography>}
          {profile.boxes.map((box) => <Card key={box.id} sx={{ backgroundColor: '#14161a', p: 1.5 }}><Typography sx={{ color: '#fff' }}>{box.uid_hardware ?? box.id} · {box.name}</Typography><Typography sx={{ color: '#8e94a3' }}>{box.status} · {box.firmware_version ?? '—'} · {box.last_sync ? new Date(box.last_sync).toLocaleString() : '—'}</Typography></Card>)}
          {(level === 'operator' || level === 'super_admin') && <>
            <Typography sx={{ fontWeight: 700, mt: 1 }}>{language === 'fr' ? 'Notes internes' : 'Internal notes'}</Typography>
            {notesQuery.isLoading && <CircularProgress size={22} />}
            {notesQuery.error && <Alert severity="error">{displayError(notesQuery.error)}</Alert>}
            {(notesQuery.data?.data ?? []).map((note) => <Card key={note.id} sx={{ backgroundColor: '#14161a', p: 1.5 }}><Typography sx={{ color: '#e0e4ec', whiteSpace: 'pre-wrap' }}>{note.body}</Typography><Typography sx={{ color: '#8e94a3', fontSize: '.75rem', mt: 1 }}>{note.admin_email ?? note.admin_id} · {new Date(note.created_at).toLocaleString()}</Typography></Card>)}
            {!notesQuery.isLoading && !notesQuery.error && !(notesQuery.data?.data.length) && <Typography sx={{ color: '#8e94a3' }}>{language === 'fr' ? 'Aucune note enregistrée.' : 'No notes recorded.'}</Typography>}
            <TextField label={language === 'fr' ? 'Nouvelle note interne' : 'New internal note'} value={noteBody} onChange={(event) => setNoteBody(event.target.value)} multiline minRows={3} />
            <Button variant="contained" disabled={!noteBody.trim() || noteMutation.isPending} onClick={() => noteMutation.mutate()}>{noteMutation.isPending ? '…' : language === 'fr' ? 'Enregistrer la note' : 'Save note'}</Button>
          </>}
        </Box>}
      </Drawer>
      <Dialog open={Boolean(userToUpdate)} onClose={() => setUserToUpdate(null)}>
        <DialogTitle>{userToUpdate?.status === 'active' ? (language === 'fr' ? 'Suspendre le compte ?' : 'Suspend account?') : (language === 'fr' ? 'Réactiver le compte ?' : 'Reactivate account?')}</DialogTitle>
        <DialogContent>{maskEmail(userToUpdate?.email ?? '', level)}</DialogContent>
        <DialogActions><Button onClick={() => setUserToUpdate(null)}>{language === 'fr' ? 'Annuler' : 'Cancel'}</Button><Button color={userToUpdate?.status === 'active' ? 'error' : 'success'} disabled={statusMutation.isPending} onClick={() => userToUpdate && statusMutation.mutate({ id: userToUpdate.id, status: userToUpdate.status === 'active' ? 'suspended' : 'active' })}>{language === 'fr' ? 'Confirmer' : 'Confirm'}</Button></DialogActions>
      </Dialog>
    </Box>
  );
};
