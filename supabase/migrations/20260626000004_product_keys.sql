CREATE TABLE IF NOT EXISTS product_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  is_used BOOLEAN NOT NULL DEFAULT false,
  used_by UUID REFERENCES auth.users(id),
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE product_keys ENABLE ROW LEVEL SECURITY;

-- Admin: full access
CREATE POLICY product_keys_admin_select ON product_keys FOR SELECT TO authenticated USING (private.is_admin());
CREATE POLICY product_keys_admin_insert ON product_keys FOR INSERT TO authenticated WITH CHECK (private.is_admin());
CREATE POLICY product_keys_admin_update ON product_keys FOR UPDATE TO authenticated USING (private.is_admin());
CREATE POLICY product_keys_admin_delete ON product_keys FOR DELETE TO authenticated USING (private.is_admin());

-- Users: can read (to check if key exists) and claim via RPC
CREATE POLICY product_keys_user_select ON product_keys FOR SELECT TO authenticated USING (true);

-- Index for fast key lookup
CREATE INDEX IF NOT EXISTS idx_product_keys_key ON product_keys(key);
CREATE INDEX IF NOT EXISTS idx_product_keys_unused ON product_keys(is_used) WHERE is_used = false;
