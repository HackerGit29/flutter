-- Fix device_commands: add missing statuses and columns for worker
ALTER TABLE device_commands
  DROP CONSTRAINT IF EXISTS device_commands_status_check,
  ADD CONSTRAINT device_commands_status_check
    CHECK (status IN ('pending', 'processing', 'sent', 'acknowledged', 'failed', 'rejected', 'timeout'));

ALTER TABLE device_commands
  ADD COLUMN IF NOT EXISTS processing_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS worker_id TEXT;
