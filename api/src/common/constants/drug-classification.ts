import { DrugClassification } from '@prisma/client';

export { DrugClassification };

export const DRUG_CLASSIFICATION_VALUES = Object.values(DrugClassification);

export function requiresPrescriptionFromClassification(
  classification?: DrugClassification | null,
): boolean {
  return (
    classification === DrugClassification.PRESCRIPTION ||
    classification === DrugClassification.CONTROLLED
  );
}

export type ResolvedDrugClassification = {
  drugClassification: DrugClassification | null;
  requiresPrescription: boolean;
};

export function resolveDrugClassification(input: {
  drug_classification?: DrugClassification | null;
  requires_prescription?: boolean;
  existingClassification?: DrugClassification | null;
  existingRequiresPrescription?: boolean;
}): ResolvedDrugClassification {
  if (input.drug_classification !== undefined) {
    const drugClassification = input.drug_classification;
    return {
      drugClassification,
      requiresPrescription:
        requiresPrescriptionFromClassification(drugClassification),
    };
  }

  if (input.requires_prescription !== undefined) {
    const requiresPrescription = input.requires_prescription;
    return {
      drugClassification: requiresPrescription
        ? DrugClassification.PRESCRIPTION
        : input.existingClassification ?? null,
      requiresPrescription,
    };
  }

  return {
    drugClassification: input.existingClassification ?? null,
    requiresPrescription: input.existingRequiresPrescription ?? false,
  };
}
