import React, { useEffect, useState } from 'react';
import { Alert, Box, Button, CircularProgress, TextField, Typography } from '@mui/material';
import { getSupabase } from '../../api/supabaseClient';
import { getAdminIdentity } from '../../api/operations';
import { useAppStore } from '../../store/useAppStore';

export const AdminAccess: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const session = useAppStore((state) => state.session);
  const setSession = useAppStore((state) => state.setSession);
  const clearSession = useAppStore((state) => state.clearSession);
  const [ready, setReady] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let alive = true;
    let subscription: { unsubscribe: () => void } | undefined;
    const initialize = async () => {
      try {
        const supabase = getSupabase();
        const { data } = await supabase.auth.getSession();
        const syncSession = async (session: typeof data.session) => {
          if (!alive) return;
          if (!session) {
            clearSession();
            setReady(true);
            return;
          }
          try {
            const identity = await getAdminIdentity();
            if (alive) setSession({ id: identity.id, email: identity.email, level: identity.level, accessToken: session.access_token, expiresAt: session.expires_at ? session.expires_at * 1000 : null });
          } catch (cause) {
            if (alive) {
              clearSession();
              setError(cause instanceof Error ? cause.message : 'Accès administrateur refusé.');
              await supabase.auth.signOut();
            }
          } finally {
            if (alive) setReady(true);
          }
        };
        subscription = supabase.auth.onAuthStateChange((_event, session) => { void syncSession(session); }).data.subscription;
        await syncSession(data.session);
      } catch (cause) {
        if (alive) {
          setError(cause instanceof Error ? cause.message : 'Configuration Supabase invalide.');
          setReady(true);
        }
      }
    };
    void initialize();
    return () => { alive = false; subscription?.unsubscribe(); };
  }, [attempt, clearSession, setSession]);

  const signIn = async (event: React.FormEvent) => {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      const { error: authError } = await getSupabase().auth.signInWithPassword({ email, password });
      if (authError) throw authError;
      setPassword('');
      setAttempt((value) => value + 1);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Connexion refusée.');
    } finally {
      setSubmitting(false);
    }
  };

  if (!ready) return <Box role="status" sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}><CircularProgress /></Box>;
  if (session) return <>{children}</>;

  return <Box component="main" sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center', p: 3 }}>
    <Box component="form" onSubmit={signIn} sx={{ width: '100%', maxWidth: 420, display: 'flex', flexDirection: 'column', gap: 2 }}>
      <Typography variant="h1" sx={{ fontSize: '1.8rem', fontWeight: 700 }}>Connexion au backoffice</Typography>
      <Typography color="text.secondary">Utilisez un compte administrateur actif. Le niveau d’accès est vérifié côté serveur.</Typography>
      {error && <Alert severity="error" role="alert">{error}</Alert>}
      <TextField label="Adresse e-mail" type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} />
      <TextField label="Mot de passe" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} />
      <Button type="submit" variant="contained" disabled={submitting}>{submitting ? 'Connexion…' : 'Se connecter'}</Button>
    </Box>
  </Box>;
};
