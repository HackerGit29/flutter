-- Migration: add INSERT policy for subscriptions
-- Les utilisateurs doivent pouvoir créer leur propre abonnement après avoir claim une clé

DROP POLICY IF EXISTS subscriptions_insert ON public.subscriptions;
CREATE POLICY subscriptions_insert
  ON public.subscriptions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());
