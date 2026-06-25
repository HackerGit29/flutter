-- Fix admin authorization policies so they use the application role stored in public.users.
-- Also add the missing INSERT policy for appliances.

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION private.is_admin() FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_admin() TO authenticated;

DROP POLICY IF EXISTS boxes_user_select ON public.boxes;
CREATE POLICY boxes_user_select
  ON public.boxes FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS boxes_user_insert ON public.boxes;
CREATE POLICY boxes_user_insert
  ON public.boxes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS boxes_user_update ON public.boxes;
CREATE POLICY boxes_user_update
  ON public.boxes FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin())
  WITH CHECK (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS boxes_user_delete ON public.boxes;
CREATE POLICY boxes_user_delete
  ON public.boxes FOR DELETE
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS appliances_user_select ON public.appliances;
CREATE POLICY appliances_user_select
  ON public.appliances FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS appliances_user_insert ON public.appliances;
CREATE POLICY appliances_user_insert
  ON public.appliances FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS appliances_user_update ON public.appliances;
CREATE POLICY appliances_user_update
  ON public.appliances FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin())
  WITH CHECK (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS energy_data_user_select ON public.energy_data;
CREATE POLICY energy_data_user_select
  ON public.energy_data FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS subscriptions_select ON public.subscriptions;
CREATE POLICY subscriptions_select
  ON public.subscriptions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS subscriptions_update ON public.subscriptions;
CREATE POLICY subscriptions_update
  ON public.subscriptions FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin())
  WITH CHECK (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS sync_logs_select ON public.sync_logs;
CREATE POLICY sync_logs_select
  ON public.sync_logs FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS sync_logs_insert ON public.sync_logs;
CREATE POLICY sync_logs_insert
  ON public.sync_logs FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS admin_actions_select ON public.admin_actions;
CREATE POLICY admin_actions_select
  ON public.admin_actions FOR SELECT
  TO authenticated
  USING (private.is_admin());

DROP POLICY IF EXISTS admin_actions_insert ON public.admin_actions;
CREATE POLICY admin_actions_insert
  ON public.admin_actions FOR INSERT
  TO authenticated
  WITH CHECK (private.is_admin());

DROP POLICY IF EXISTS "device_commands_user_select" ON public.device_commands;
CREATE POLICY "device_commands_user_select"
  ON public.device_commands FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS "agent_audit_logs_admin_select" ON public.agent_audit_logs;
CREATE POLICY "agent_audit_logs_admin_select"
  ON public.agent_audit_logs FOR SELECT
  TO authenticated
  USING (private.is_admin() OR user_id = auth.uid());

DROP POLICY IF EXISTS "chat_embeddings_user_select" ON public.chat_embeddings;
CREATE POLICY "chat_embeddings_user_select"
  ON public.chat_embeddings FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid() OR private.is_admin());
