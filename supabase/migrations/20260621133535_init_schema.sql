-- Initialize users table (profile)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'user', 'vip')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- boxes : boîtiers physiques avec UID matériel
CREATE TABLE IF NOT EXISTS boxes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid_hardware TEXT UNIQUE,
  name TEXT NOT NULL,
  location TEXT,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'inactive' CHECK (status IN ('active', 'inactive', 'blocked')),
  last_sync TIMESTAMPTZ,
  public_key TEXT,
  firmware_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_boxes_uid_hardware ON boxes(uid_hardware) WHERE uid_hardware IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_boxes_user_id ON boxes(user_id);

-- appliances : relais (1..3 par boîtier)
CREATE TABLE IF NOT EXISTS appliances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  box_id UUID NOT NULL REFERENCES boxes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  relay_index INT NOT NULL CHECK (relay_index BETWEEN 1 AND 3),
  name TEXT NOT NULL,
  location TEXT,
  is_on BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(box_id, relay_index)
);
CREATE INDEX IF NOT EXISTS idx_appliances_user_id ON appliances(user_id);
CREATE INDEX IF NOT EXISTS idx_appliances_box_id ON appliances(box_id);

-- energy_data : agrégations quotidiennes par appliance
CREATE TABLE IF NOT EXISTS energy_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  appliance_id UUID NOT NULL REFERENCES appliances(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  total_day DOUBLE PRECISION DEFAULT 0,
  total_week DOUBLE PRECISION DEFAULT 0,
  total_month DOUBLE PRECISION DEFAULT 0,
  total_year DOUBLE PRECISION DEFAULT 0,
  week INT NOT NULL,
  month INT NOT NULL,
  year INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(appliance_id, date)
);
CREATE INDEX IF NOT EXISTS idx_energy_data_user_id ON energy_data(user_id);
CREATE INDEX IF NOT EXISTS idx_energy_data_appliance_id ON energy_data(appliance_id);
CREATE INDEX IF NOT EXISTS idx_energy_data_date ON energy_data(date DESC);

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

-- sync_logs : journal des synchronisations boîtier
CREATE TABLE IF NOT EXISTS sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  box_id UUID NOT NULL REFERENCES boxes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'unauthorized', 'crypto_mismatch', 'device_blocked')),
  data JSONB,
  error_message TEXT,
  ip_address TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sync_logs_box_id ON sync_logs(box_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_user_id ON sync_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_timestamp ON sync_logs(timestamp DESC);

-- admin_actions
DO $$ BEGIN
    CREATE TYPE admin_action_type AS ENUM ('suspend_user', 'activate_user', 'assign_role', 'reset_device', 'force_sync', 'override_ownership', 'block_device', 'activate_license', 'revoke_license', 'reset_box', 'assign_box');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE target_type AS ENUM ('user', 'device', 'license', 'subscription', 'box', 'appliance');
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

-- RLS Policies
ALTER TABLE boxes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS boxes_user_select ON boxes;
    CREATE POLICY boxes_user_select ON boxes FOR SELECT USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS boxes_user_insert ON boxes;
    CREATE POLICY boxes_user_insert ON boxes FOR INSERT WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS boxes_user_update ON boxes;
    CREATE POLICY boxes_user_update ON boxes FOR UPDATE USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS boxes_user_delete ON boxes;
    CREATE POLICY boxes_user_delete ON boxes FOR DELETE USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;

ALTER TABLE appliances ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS appliances_user_select ON appliances;
    CREATE POLICY appliances_user_select ON appliances FOR SELECT USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS appliances_user_update ON appliances;
    CREATE POLICY appliances_user_update ON appliances FOR UPDATE USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;

ALTER TABLE energy_data ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS energy_data_user_select ON energy_data;
    CREATE POLICY energy_data_user_select ON energy_data FOR SELECT USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS subscriptions_select ON subscriptions;
    CREATE POLICY subscriptions_select ON subscriptions FOR SELECT USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;

ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS sync_logs_select ON sync_logs;
    CREATE POLICY sync_logs_select ON sync_logs FOR SELECT USING (user_id = auth.uid() OR (auth.jwt()->>'role' = 'admin'));
EXCEPTION WHEN others THEN null; END $$;

ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    DROP POLICY IF EXISTS admin_actions_select ON admin_actions;
    CREATE POLICY admin_actions_select ON admin_actions FOR SELECT USING (auth.jwt()->>'role' = 'admin');
EXCEPTION WHEN others THEN null; END $$;
DO $$ BEGIN
    DROP POLICY IF EXISTS admin_actions_insert ON admin_actions;
    CREATE POLICY admin_actions_insert ON admin_actions FOR INSERT WITH CHECK (auth.jwt()->>'role' = 'admin');
EXCEPTION WHEN others THEN null; END $$;
