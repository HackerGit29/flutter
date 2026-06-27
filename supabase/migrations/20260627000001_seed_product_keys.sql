-- Migration: seed 10 product keys for VIP subscription activation
-- Chaque clé est unique et utilisable une seule fois (is_used=false)

INSERT INTO product_keys (key) VALUES
  ('ARICIE-VIP-2026-0001'),
  ('ARICIE-VIP-2026-0002'),
  ('ARICIE-VIP-2026-0003'),
  ('ARICIE-VIP-2026-0004'),
  ('ARICIE-VIP-2026-0005'),
  ('ARICIE-VIP-2026-0006'),
  ('ARICIE-VIP-2026-0007'),
  ('ARICIE-VIP-2026-0008'),
  ('ARICIE-VIP-2026-0009'),
  ('ARICIE-VIP-2026-0010')
ON CONFLICT (key) DO NOTHING;
