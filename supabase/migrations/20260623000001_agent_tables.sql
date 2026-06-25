-- Migration: Agent AI tables (pgvector, device_commands, audit, embeddings)
-- Date: 2026-06-23

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- 1. device_commands : file d'attente des commandes appareil
--    L'Edge Function insère, le Worker MQTT lit et publie
-- ============================================================
CREATE TABLE IF NOT EXISTS device_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  box_id UUID NOT NULL,
  box_uid TEXT NOT NULL,

  appliance_id UUID,
  appliance_name TEXT,

  relay_index INTEGER NOT NULL CHECK (relay_index BETWEEN 1 AND 3),
  action TEXT NOT NULL CHECK (action IN ('on', 'off')),

  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'acknowledged', 'failed', 'rejected')),

  requested_by TEXT NOT NULL DEFAULT 'ai_agent',
  reason TEXT,
  error_message TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ
);

ALTER TABLE device_commands ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_commands_user_select"
  ON device_commands FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

CREATE POLICY "device_commands_user_insert"
  ON device_commands FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_device_commands_pending
  ON device_commands(status, created_at)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_device_commands_user_created
  ON device_commands(user_id, created_at DESC);

-- ============================================================
-- 2. agent_audit_logs : journal immuable des actions de l'agent
--    Toute décision (autorisée ou bloquée) est tracée
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,

  status TEXT NOT NULL CHECK (status IN ('allowed', 'blocked', 'failed', 'success')),

  details JSONB NOT NULL DEFAULT '{}',

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE agent_audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "agent_audit_logs_admin_select"
  ON agent_audit_logs FOR SELECT
  TO authenticated
  USING (private.is_admin() OR user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_agent_audit_logs_user_created
  ON agent_audit_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_audit_logs_action_created
  ON agent_audit_logs(action, created_at DESC);

-- ============================================================
-- 3. chat_embeddings : RAG vectoriel scope par utilisateur
--    Stocke les embeddings des documents utilisateur
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  scope TEXT NOT NULL DEFAULT 'user',
  source_type TEXT NOT NULL DEFAULT 'doc',
  source_id TEXT,

  content TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',

  embedding VECTOR(1536),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE chat_embeddings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_embeddings_user_select"
  ON chat_embeddings FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid() OR private.is_admin());

CREATE POLICY "chat_embeddings_user_insert"
  ON chat_embeddings FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "chat_embeddings_user_delete"
  ON chat_embeddings FOR DELETE
  TO authenticated
  USING (owner_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_chat_embeddings_owner
  ON chat_embeddings(owner_id);

CREATE INDEX IF NOT EXISTS idx_chat_embeddings_embedding
  ON chat_embeddings
  USING hnsw (embedding vector_cosine_ops);

-- ============================================================
-- 4. Fonction RPC : recherche d'embeddings scope par utilisateur
--    Utilisée par l'Edge Function pour le RAG
-- ============================================================
CREATE OR REPLACE FUNCTION match_user_embeddings(
  query_embedding VECTOR(1536),
  requester_id UUID,
  match_count INT DEFAULT 5,
  min_similarity FLOAT DEFAULT 0.7
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  metadata JSONB,
  similarity FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ce.id,
    ce.content,
    ce.metadata,
    1 - (ce.embedding <=> query_embedding) AS similarity
  FROM chat_embeddings ce
  WHERE
    ce.owner_id = requester_id
    AND 1 - (ce.embedding <=> query_embedding) > min_similarity
  ORDER BY ce.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ============================================================
-- 5. Fonction RPC : extraction des appareils de l'utilisateur
--    Utilisée par l'Edge Function pour le contexte opérationnel
-- ============================================================
CREATE OR REPLACE FUNCTION get_user_appliances_context(
  requester_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT JSONB_AGG(
    JSONB_BUILD_OBJECT(
      'name', a.name,
      'location', a.location,
      'is_on', a.is_on,
      'relay_index', a.relay_index,
      'box_uid', b.uid_hardware
    )
  )
  INTO result
  FROM appliances a
  JOIN boxes b ON b.id = a.box_id
  WHERE a.user_id = requester_id;

  RETURN COALESCE(result, '[]'::JSONB);
END;
$$;
