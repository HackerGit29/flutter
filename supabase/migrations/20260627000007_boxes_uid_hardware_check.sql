ALTER TABLE boxes DROP CONSTRAINT IF EXISTS boxes_uid_hardware_length_check;
ALTER TABLE boxes ADD CONSTRAINT boxes_uid_hardware_length_check
  CHECK (uid_hardware IS NULL OR length(uid_hardware) > 8);
