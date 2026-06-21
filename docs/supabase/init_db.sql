-- users : ajout colonnes
ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'user', 'vip'));
ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended'));

-- devices : ajout colonnes
ALTER TABLE devices ADD COLUMN uid_hardware TEXT UNIQUE;
ALTER TABLE devices ADD COLUMN status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'blocked'));
ALTER TABLE devices ADD COLUMN last_sync TIMESTAMPTZ;
ALTER TABLE devices ADD COLUMN public_key TEXT;
ALTER TABLE devices ADD COLUMN firmware_version TEXT;

-- devices : index sur uid_hardware
CREATE UNIQUE INDEX idx_devices_uid_hardware ON devices(uid_hardware) WHERE uid_hardware IS NOT NULL;
CREATE INDEX idx_devices_user_id ON devices(user_id);

-- subscriptions : un user = une subscription active max
CREATE TABLE subscriptions (
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
CREATE TABLE licenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  activation_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expiration_date TIMESTAMPTZ,
  license_key TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- sync_logs
CREATE TABLE sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'unauthorized', 'crypto_mismatch', 'device_blocked')),
  data JSONB,
  error_message TEXT,
  ip_address TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_sync_logs_device_id ON sync_logs(device_id);
CREATE INDEX idx_sync_logs_user_id ON sync_logs(user_id);
CREATE INDEX idx_sync_logs_timestamp ON sync_logs(timestamp DESC);

-- admin_actions
CREATE TYPE admin_action_type AS ENUM (
  'suspend_user', 'activate_user', 'assign_role',
  'reset_device', 'force_sync', 'override_ownership', 'block_device',
  'activate_license', 'revoke_license'
);
CREATE TYPE target_type AS ENUM ('user', 'device', 'license', 'subscription');

CREATE TABLE admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES users(id),
  action admin_action_type NOT NULL,
  target_type target_type NOT NULL,
  target_id TEXT NOT NULL,
  details JSONB,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX idx_admin_actions_timestamp ON admin_actions(timestamp DESC);

-- RLS Policies
CREATE POLICY devices_user_select ON devices FOR SELECT
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');
CREATE POLICY devices_user_insert ON devices FOR INSERT
  WITH CHECK (user_id = auth.uid());
CREATE POLICY devices_user_update ON devices FOR UPDATE
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');
CREATE POLICY devices_user_delete ON devices FOR DELETE
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');

CREATE POLICY subscriptions_select ON subscriptions FOR SELECT
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');

CREATE POLICY sync_logs_select ON sync_logs FOR SELECT
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');

CREATE POLICY admin_actions_select ON admin_actions FOR SELECT
  USING (auth.jwt()->>'role' = 'admin');
CREATE POLICY admin_actions_insert ON admin_actions FOR INSERT
  WITH CHECK (auth.jwt()->>'role' = 'admin');
