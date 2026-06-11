/**
 * Role string literals — tidak bergantung pada enum Prisma yang mungkin stale di IDE.
 * Nilai harus sama dengan enum UserRole di prisma/schema.prisma.
 */
export const AppRole = {
  SUPER_ADMIN: 'SUPER_ADMIN',
  OWNER: 'OWNER',
  MANAGER: 'MANAGER',
  PHARMACIST: 'PHARMACIST',
  CASHIER: 'CASHIER',
  STAFF: 'STAFF',
  WAREHOUSE: 'WAREHOUSE',
} as const;

export type AppRoleName = (typeof AppRole)[keyof typeof AppRole];
