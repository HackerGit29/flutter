-- Voir la migration officielle : supabase/migrations/20260621133535_init_schema.sql
-- Ce fichier est maintenu pour référence uniquement.

-- Tables principales
-- boxes : boîtiers physiques (remplace devices)
-- appliances : relais (1..3 par box, relay_index 1-3)
-- energy_data : consommation agrégée par appliance/jour
-- sync_logs : payload JSONB bruts (source de vérité)
-- admin_actions : audit trail administrateur

-- RLS : user_id = auth.uid() sur boxes, appliances, energy_data, sync_logs
-- Admin bypass via private.is_admin() (SECURITY DEFINER function)

-- Types enum
CREATE TYPE box_status AS ENUM ('active', 'inactive', 'blocked');
CREATE TYPE sync_status AS ENUM ('success', 'failed', 'unauthorized', 'crypto_mismatch', 'device_blocked');

-- Boxes
CREATE TABLE boxes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid_hardware TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  location TEXT,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status box_status DEFAULT 'active',
  public_key TEXT,
  last_sync TIMESTAMPTZ,
  firmware_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Appliances (1..3 par box)
CREATE TABLE appliances (
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

-- Energy data (par appliance)
CREATE TABLE energy_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  appliance_id UUID NOT NULL REFERENCES appliances(id) ON DELETE CASCADE,
  date DATE NOT NULL,
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
