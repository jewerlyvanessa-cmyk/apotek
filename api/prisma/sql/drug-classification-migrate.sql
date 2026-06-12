DO $$ BEGIN
  CREATE TYPE drug_classification AS ENUM (
    'PRESCRIPTION',
    'LIMITED_OTC',
    'OTC',
    'CONTROLLED'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE medicines
  ADD COLUMN IF NOT EXISTS drug_classification drug_classification;

UPDATE medicines m
SET drug_classification = 'PRESCRIPTION'
FROM product_type_definitions pt
WHERE m.product_type_id = pt.id
  AND pt.code = 'DRUG'
  AND m.requires_prescription = true
  AND m.drug_classification IS NULL;
