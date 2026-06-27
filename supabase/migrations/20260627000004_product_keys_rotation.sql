-- Migration: product keys rotation system
-- Adds expiration, random format, weekly rotation cron

ALTER TABLE product_keys ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE product_keys ADD COLUMN IF NOT EXISTS rotation_batch INTEGER DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_product_keys_claimable
  ON product_keys(is_used, expires_at)
  WHERE is_used = false;

-- Migrate existing data: batch 0 = used (never expire), batch 1 = current rotation
UPDATE product_keys SET
  expires_at = NULL,
  rotation_batch = 0
WHERE is_used = true;

UPDATE product_keys SET
  expires_at = NOW() + INTERVAL '7 days',
  rotation_batch = 1
WHERE is_used = false AND expires_at IS NULL;

-- Transform unused keys from sequential to random alphanumeric format
DO $$
DECLARE
  r RECORD;
  new_key TEXT;
BEGIN
  FOR r IN SELECT id FROM product_keys WHERE is_used = false LOOP
    LOOP
      new_key := 'ARICIE-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 8));
      CONTINUE WHEN EXISTS (SELECT 1 FROM product_keys WHERE key = new_key);
      EXIT;
    END LOOP;
    UPDATE product_keys SET key = new_key WHERE id = r.id;
  END LOOP;
END;
$$;

-- Update RLS claim policy to check expiration
DROP POLICY IF EXISTS product_keys_claim_update ON product_keys;
CREATE POLICY product_keys_claim_update
  ON product_keys FOR UPDATE
  TO authenticated
  USING (is_used = false AND (expires_at IS NULL OR expires_at > NOW()))
  WITH CHECK (is_used = true AND used_by = auth.uid());

-- Weekly rotation function (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION rotate_product_keys()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_batch INTEGER;
  key_count CONSTANT INTEGER := 10;
  new_key TEXT;
  i INTEGER;
BEGIN
  SELECT COALESCE(MAX(rotation_batch), 0) + 1 INTO new_batch FROM product_keys;

  -- Expire all currently unused, non-expired keys
  UPDATE product_keys
  SET expires_at = NOW()
  WHERE is_used = false AND (expires_at IS NULL OR expires_at > NOW());

  -- Generate new batch of random keys (valid 7 days)
  FOR i IN 1..key_count LOOP
    LOOP
      new_key := 'ARICIE-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 8));
      EXIT WHEN NOT EXISTS (SELECT 1 FROM product_keys WHERE key = new_key);
    END LOOP;
    INSERT INTO product_keys (key, expires_at, rotation_batch)
    VALUES (new_key, NOW() + INTERVAL '7 days', new_batch);
  END LOOP;
END;
$$;

-- Schedule weekly rotation (every Monday at 00:00 UTC)
SELECT cron.schedule(
  'rotate-product-keys',
  '0 0 * * 1',
  $$SELECT rotate_product_keys();$$
);
