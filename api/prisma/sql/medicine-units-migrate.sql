CREATE TABLE IF NOT EXISTS medicine_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_medicine_units_tenant_name
  ON medicine_units (tenant_id, name);

INSERT INTO medicine_units (tenant_id, name)
SELECT t.id, u.name
FROM tenants t
CROSS JOIN (
  VALUES ('STRIP'), ('PCS'), ('BOTOL'), ('BOX'), ('TUBE'), ('SACHET')
) AS u(name)
ON CONFLICT (tenant_id, name) DO NOTHING;
