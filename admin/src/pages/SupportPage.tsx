import React, { useState } from 'react';
import { Alert, Box, Button, Card, CircularProgress, TextField, Typography } from '@mui/material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AdminApiError } from '../api/client';
import { createAdminNote, listAdminNotes, listUsers } from '../api/operations';
import { maskEmail, useAppStore } from '../store/useAppStore';

export const SupportPage: React.FC = () => {
  const language = useAppStore((state) => state.language);
  const level = useAppStore((state) => state.session?.level ?? null);
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [selectedUserId, setSelectedUserId] = useState('');
  const [body, setBody] = useState('');
  const usersQuery = useQuery({ queryKey: ['admin-api', 'users', 'support'], queryFn: () => listUsers({ page: 1, page_size: 100 }) });
  const notesQuery = useQuery({ queryKey: ['admin-api', 'notes', 'support', search], queryFn: () => listAdminNotes({ page: 1, page_size: 100, target_type: 'user' }) });
  const mutation = useMutation({
    mutationFn: () => createAdminNote({ target_type: 'user', target_id: selectedUserId, body: body.trim() }),
    onSuccess: async () => {
      setBody('');
      await queryClient.invalidateQueries({ queryKey: ['admin-api', 'notes', 'support'] });
      await queryClient.invalidateQueries({ queryKey: ['admin-api', 'notes', 'user', selectedUserId] });
    },
  });
  const users = usersQuery.data?.data ?? [];
  const notes = (notesQuery.data?.data ?? []).filter((note) => note.body.toLowerCase().includes(search.toLowerCase()) || (note.admin_email ?? '').toLowerCase().includes(search.toLowerCase()));
  const canWrite = level === 'operator' || level === 'super_admin';
  const error = usersQuery.error ?? notesQuery.error;
  const errorMessage = error instanceof AdminApiError || error instanceof Error ? error.message : 'Erreur API';

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box><Typography variant="h1" sx={{ fontSize: { xs: '1.6rem', md: '2.2rem' }, fontWeight: 700, color: '#fff' }}>{language === 'fr' ? 'Support · Notes internes' : 'Support · Internal notes'}</Typography><Typography sx={{ color: '#8e94a3', fontSize: '.88rem', mt: .5 }}>{language === 'fr' ? 'Notes réelles stockées par admin-api. Les tickets ne sont pas exposés par le backend.' : 'Internal notes stored by admin-api. Ticket endpoints are not available in the backend.'}</Typography></Box>
      {error && <Alert severity="error" action={<Button color="inherit" onClick={() => { void usersQuery.refetch(); void notesQuery.refetch(); }}>{language === 'fr' ? 'Réessayer' : 'Retry'}</Button>}>{errorMessage}</Alert>}
      {mutation.error && <Alert severity="error">{mutation.error instanceof Error ? mutation.error.message : 'Erreur API'}</Alert>}
      {mutation.isSuccess && <Alert severity="success">{language === 'fr' ? 'Note enregistrée.' : 'Note saved.'}</Alert>}
      {(usersQuery.isLoading || notesQuery.isLoading) && <Box role="status" sx={{ display: 'flex', justifyContent: 'center', py: 4 }}><CircularProgress /></Box>}
      <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', p: 2 }}>
        <TextField fullWidth size="small" value={search} onChange={(event) => setSearch(event.target.value)} placeholder={language === 'fr' ? 'Filtrer les notes…' : 'Filter notes…'} />
      </Card>
      {canWrite && <Card sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', p: 2, display: 'flex', flexDirection: 'column', gap: 1.5 }}>
        <Typography sx={{ fontWeight: 700, color: '#fff' }}>{language === 'fr' ? 'Ajouter une note interne à un client' : 'Add an internal user note'}</Typography>
        <TextField select label={language === 'fr' ? 'Client' : 'User'} value={selectedUserId} onChange={(event) => setSelectedUserId(event.target.value)} slotProps={{ select: { native: true } }}>
          <option value="">{language === 'fr' ? 'Sélectionner un client' : 'Select a user'}</option>
          {users.map((user) => <option key={user.id} value={user.id}>{maskEmail(user.email, level)}</option>)}
        </TextField>
        <TextField label={language === 'fr' ? 'Note' : 'Note'} value={body} onChange={(event) => setBody(event.target.value)} multiline minRows={3} />
        <Button variant="contained" disabled={!selectedUserId || !body.trim() || mutation.isPending} onClick={() => mutation.mutate()}>{mutation.isPending ? '…' : language === 'fr' ? 'Enregistrer la note' : 'Save note'}</Button>
      </Card>}
      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: 'repeat(2, 1fr)' }, gap: 2 }}>
        {notes.map((note) => {
          const user = users.find((item) => item.id === note.target_id);
          return <Card key={note.id} sx={{ backgroundColor: '#1c1e22', border: '1px solid rgba(255,255,255,0.05)', p: 2 }}>
            <Typography sx={{ color: '#e0e4ec', whiteSpace: 'pre-wrap' }}>{note.body}</Typography>
            <Typography sx={{ color: '#8e94a3', fontSize: '.75rem', mt: 1 }}>{user ? maskEmail(user.email, level) : note.target_id} · {note.admin_email ?? note.admin_id} · {new Date(note.created_at).toLocaleString()}</Typography>
          </Card>;
        })}
        {!notes.length && !notesQuery.isLoading && !notesQuery.error && <Alert severity="info" sx={{ gridColumn: '1 / -1' }}>{language === 'fr' ? 'Aucune note interne enregistrée.' : 'No internal notes recorded.'}</Alert>}
      </Box>
    </Box>
  );
};
