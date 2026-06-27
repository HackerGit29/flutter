-- Migration: fix product_keys claim for regular users
-- Permet aux utilisateurs authentifiés de marquer une clé comme utilisée (claim atomique)
-- Uniquement sur les colonnes is_used, used_by, used_at

DROP POLICY IF EXISTS product_keys_claim_update ON product_keys;
CREATE POLICY product_keys_claim_update
  ON product_keys FOR UPDATE
  TO authenticated
  USING (is_used = false)
  WITH CHECK (is_used = true AND used_by = auth.uid());
