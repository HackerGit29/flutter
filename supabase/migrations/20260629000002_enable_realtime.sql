-- Activer Realtime broadcast sur energy_data et device_commands
-- Permet à l'app Flutter et au worker de recevoir les changements en direct

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'energy_data'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE energy_data;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'device_commands'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;
  END IF;
END $$;
