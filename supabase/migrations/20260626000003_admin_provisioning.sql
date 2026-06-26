-- Clean up orphan boxes with empty or short UID
UPDATE boxes SET uid_hardware = NULL WHERE uid_hardware = '' OR length(uid_hardware) <= 8;

-- CHECK constraint: uid_hardware must be > 8 chars if set
ALTER TABLE boxes
  ADD CONSTRAINT boxes_uid_hardware_length_check
  CHECK (uid_hardware IS NULL OR length(uid_hardware) > 8);

-- DELETE policy on appliances for admin
CREATE POLICY "appliances_admin_delete" ON appliances
  FOR DELETE USING (private.is_admin());
