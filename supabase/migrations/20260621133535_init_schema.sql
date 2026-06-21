-- Initialize users table (profile)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'user', 'vip')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- devices : ajout colonnes
-- If table doesn't exist yet, create it. If it does, alter it.
-- Based on the project, we might need to create devices table first.
CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  uid_hardware TEXT UNIQUE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'blocked')),
  last_sync TIMESTAMPTZ,
  public_key TEXT,
  firmware_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Apply columns if table already exists (fallback for migration)
-- Note: In a clean init, the above CREATE TABLE is enough. 
-- But for existing projects, we'd use ALTER.
-- To be safe for 'init', we use CREATE TABLE and avoid ALTER on non-existent tables.

-- devices : index
CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_uid_hardware ON devices(uid_hardware) WHERE uid_hardware IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);

-- subscriptions : un user = une subscription active max
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'free' CHECK (type IN ('free', 'vip')),
  start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  auto_renew BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_active_subscription UNIQUE (user_id)
);

-- licenses : liée à une subscription
CREATE TABLE IF NOT EXISTS licenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  activation_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expiration_date TIMESTAMPTZ,
  license_key TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- sync_logs
CREATE TABLE IF NOT EXISTS sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'unauthorized', 'crypto_mismatch', 'device_blocked')),
  data JSONB,
  error_message TEXT,
  ip_address TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sync_logs_device_id ON sync_logs(device_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_user_id ON sync_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_timestamp ON sync_logs(timestamp DESC);

-- admin_actions
DO $$ BEGIN
    CREATE TYPE admin_action_type AS ENUM ('suspend_user', 'activate_user', 'assign_role', 'reset_device', 'force_sync', 'override_ownership', 'block_device', 'activate_license', 'revoke_license');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE target_type AS ENUM ('user', 'device', 'license', 'subscription');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES users(id),
  action admin_action_type NOT NULL,
  target_type target_type NOT NULL,
  target_id TEXT NOT NULL,
  details JSONB,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_timestamp ON admin_actions(timestamp DESC);

-- energy_consumption (legacy)
CREATE TABLE IF NOT EXISTS energy_consumption (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  device_id UUID REFERENCES devices(id),
  period_type TEXT,
  total_day DOUBLE PRECISION DEFAULT 0,
  total_week DOUBLE PRECISION DEFAULT 0,
  total_month DOUBLE PRECISION DEFAULT 0,
  device1 DOUBLE PRECISION DEFAULT 0,
  device2 DOUBLE PRECISION DEFAULT 0,
  device3 DOUBLE PRECISION DEFAULT 0,
  date DATE DEFAULT CURRENT_DATE,
  week INT,
  month INT,
  year INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_energy_consumption_user ON energy_consumption(user_id);
CREATE INDEX IF NOT EXISTS idx_energy_consumption_date ON energy_consumption(date DESC);

-- temp_data (legacy IoT)
CREATE TABLE IF NOT EXISTS temp_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  value DOUBLE PRECISION,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- hum_data (legacy IoT)
CREATE TABLE IF NOT EXISTS hum_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  value DOUBLE PRECISION,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- alerts (legacy)
CREATE TABLE IF NOT EXISTS alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  device_id UUID REFERENCES devices(id),
  type TEXT,
  message TEXT,
  severity TEXT DEFAULT 'info',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_alerts_user ON alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_alerts_created ON alerts(created_at DESC);

-- RLS Policies (Using a function to safely create policies)
-- This is a simplified version; normally we'd check if policy exists.
-- In a fresh migration, we can just call CREATE POLICY.

-- devices
-- Note: Policies can only be created if RLS is enabled.
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS devices_user_select ON devices;
    CREATE POLICY devices_user_select ON devices FOR SELECT USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS devices_user_insert ON devices;
    CREATE POLICY devices_user_insert ON devices FOR INSERT WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS devices_user_update ON devices;
    CREATE POLICY devices_user_update ON devices FOR UPDATE USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS devices_user_delete ON devices;
    CREATE POLICY devices_user_delete ON devices FOR DELETE USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;

-- subscriptions
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS subscriptions_select ON subscriptions;
    CREATE POLICY subscriptions_select ON subscriptions FOR SELECT USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;

-- sync_logs
ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS sync_logs_select ON sync_logs;
    CREATE POLICY sync_logs_select ON sync_logs FOR SELECT USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;

-- admin_actions
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS admin_actions_select ON admin_actions;
    CREATE POLICY admin_actions_select ON admin_actions FOR SELECT USING (auth.jwt()->>'role' = 'admin');
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS admin_actions_insert ON admin_actions;
    CREATE POLICY admin_actions_insert ON admin_actions FOR INSERT WITH CHECK (auth.jwt()->>'role' = 'admin');
EXCEPTION WHEN others THEN null; END $$;
