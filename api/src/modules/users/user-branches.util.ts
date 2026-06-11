import { BadRequestException } from '@nestjs/common';
import { User, UserRole } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { normalizeUserRoles } from '../../common/utils/user-roles.util';
import { BranchAssignmentDto } from './dto/branch-assignment.dto';

export type BranchAssignmentInput = {
  branchId: string;
  roles: UserRole[];
};

const BRANCH_BOUND_ROLES: UserRole[] = [
  UserRole.MANAGER,
  UserRole.PHARMACIST,
  UserRole.CASHIER,
  UserRole.STAFF,
  UserRole.WAREHOUSE,
];

export function unionAllRoles(
  globalRoles: UserRole[],
  assignments: BranchAssignmentInput[],
): UserRole[] {
  const branchRoles = assignments.flatMap((a) => a.roles);
  return [...new Set([...globalRoles, ...branchRoles])];
}

export function resolveBranchIdsFromDto(
  branchIds?: string[],
  branchId?: string | null,
): string[] {
  if (branchIds?.length) return branchIds;
  if (branchId) return [branchId];
  return [];
}

function stripOwnerFromAssignments(
  globalRoles: UserRole[],
  assignments: BranchAssignmentInput[],
): { globalRoles: UserRole[]; assignments: BranchAssignmentInput[] } {
  let globals = [...globalRoles];
  const normalized = assignments.map((a) => {
    const hadOwner = a.roles.includes(UserRole.OWNER);
    const roles = a.roles.filter((r) => r !== UserRole.OWNER);
    if (hadOwner && !globals.includes(UserRole.OWNER)) {
      globals = [...globals, UserRole.OWNER];
    }
    return { branchId: a.branchId, roles: [...new Set(roles)] };
  });
  return { globalRoles: globals, assignments: normalized };
}

export function resolveAssignmentsFromDto(params: {
  branch_assignments?: BranchAssignmentDto[];
  branch_ids?: string[];
  branch_id?: string | null;
  roles?: UserRole[];
  global_roles?: UserRole[];
}): { globalRoles: UserRole[]; assignments: BranchAssignmentInput[] } {
  if (params.branch_assignments?.length) {
    return stripOwnerFromAssignments(
      params.global_roles ?? [],
      params.branch_assignments.map((a) => ({
        branchId: a.branch_id,
        roles: [...new Set(a.roles)],
      })),
    );
  }

  const branchIds = resolveBranchIdsFromDto(params.branch_ids, params.branch_id);
  const allRoles = params.roles ?? [];
  const explicitGlobal = params.global_roles ?? [];

  const globalRoles =
    explicitGlobal.length > 0
      ? explicitGlobal
      : allRoles.filter(
          (r) =>
            r === UserRole.OWNER ||
            (r === UserRole.MANAGER && !branchIds.length),
        );

  const branchRoles = allRoles.filter((r) => {
    if (r === UserRole.OWNER) return false;
    if (r === UserRole.MANAGER && globalRoles.includes(UserRole.MANAGER)) {
      return branchIds.length > 0;
    }
    return BRANCH_BOUND_ROLES.includes(r);
  });

  const assignments = branchIds.map((branchId) => ({
    branchId,
    roles: branchRoles.length
      ? [...new Set(branchRoles)]
      : [...new Set(allRoles.filter((r) => r !== UserRole.OWNER))],
  }));

  return stripOwnerFromAssignments(globalRoles, assignments);
}

export function assertValidAssignments(
  globalRoles: UserRole[],
  assignments: BranchAssignmentInput[],
) {
  if (!globalRoles.length && !assignments.length) {
    throw new BadRequestException('Minimal satu peran global atau penugasan cabang');
  }
  for (const a of assignments) {
    if (!a.roles.length) {
      throw new BadRequestException('Setiap cabang wajib memiliki minimal satu peran');
    }
    if (a.roles.includes(UserRole.OWNER)) {
      throw new BadRequestException('Owner hanya boleh sebagai peran global');
    }
  }
}

export async function syncUserBranchAssignments(
  prisma: PrismaService,
  params: {
    userId: string;
    tenantId: string;
    globalRoles: UserRole[];
    assignments: BranchAssignmentInput[];
    primaryBranchId?: string | null;
  },
): Promise<{ primaryBranchId: string | null; unionRoles: UserRole[] }> {
  const uniqueAssignments = new Map<string, UserRole[]>();
  for (const a of params.assignments) {
    uniqueAssignments.set(a.branchId, [...new Set(a.roles)]);
  }
  const branchIds = [...uniqueAssignments.keys()];

  if (branchIds.length) {
    const count = await prisma.branch.count({
      where: { tenantId: params.tenantId, id: { in: branchIds } },
    });
    if (count !== branchIds.length) {
      throw new BadRequestException('Satu atau lebih cabang tidak valid');
    }
  }

  const unionRoles = unionAllRoles(params.globalRoles, [...uniqueAssignments.entries()].map(
    ([branchId, roles]) => ({ branchId, roles }),
  ));

  await prisma.$transaction([
    prisma.userBranch.deleteMany({ where: { userId: params.userId } }),
    ...(branchIds.length
      ? [
          prisma.userBranch.createMany({
            data: branchIds.map((branchId) => ({
              userId: params.userId,
              branchId,
              roles: uniqueAssignments.get(branchId)!,
            })),
            skipDuplicates: true,
          }),
        ]
      : []),
    prisma.user.update({
      where: { id: params.userId },
      data: {
        globalRoles: params.globalRoles,
        roles: unionRoles,
      },
    }),
  ]);

  const primary =
    params.primaryBranchId && branchIds.includes(params.primaryBranchId)
      ? params.primaryBranchId
      : branchIds[0] ?? null;

  return { primaryBranchId: primary, unionRoles };
}

export function rolesAtBranch(
  assignments: { branchId: string; roles: UserRole[] }[],
  branchId?: string | null,
): UserRole[] {
  if (!branchId) return [];
  return assignments.find((a) => a.branchId === branchId)?.roles ?? [];
}

export function sessionRolesForContext(
  globalRoles: UserRole[],
  assignments: { branchId: string; roles: UserRole[] }[],
  branchId?: string | null,
): UserRole[] {
  if (!branchId) {
    const branchUnion = assignments.flatMap((a) => a.roles);
    return [...new Set([...globalRoles, ...branchUnion])];
  }
  const branch = rolesAtBranch(assignments, branchId);
  const global = globalRoles.filter((r) => r === UserRole.OWNER);
  return [...new Set([...global, ...branch])];
}

/** Peran valid sesi — cabang/global + fallback akun platform (SUPER_ADMIN). */
export function resolveSessionRoles(
  user: Pick<User, 'role' | 'roles' | 'globalRoles'>,
  assignments: { branchId: string; roles: UserRole[] }[],
  branchId?: string | null,
): UserRole[] {
  const fromContext = sessionRolesForContext(
    user.globalRoles ?? [],
    assignments,
    branchId,
  );
  if (fromContext.length) return fromContext;

  if (user.role === UserRole.SUPER_ADMIN) {
    return [UserRole.SUPER_ADMIN];
  }

  const normalized = normalizeUserRoles(user.roles, user.role);
  if (normalized.length) return normalized;
  return user.role ? [user.role] : [];
}

export function assertRoleAllowedInContext(
  role: UserRole,
  branchId: string | null | undefined,
  globalRoles: UserRole[],
  assignments: { branchId: string; roles: UserRole[] }[],
) {
  if (role === UserRole.SUPER_ADMIN) return;

  const allowed = sessionRolesForContext(globalRoles, assignments, branchId);
  if (!allowed.includes(role)) {
    throw new BadRequestException(
      branchId
        ? 'Peran tidak ditugaskan di cabang ini'
        : 'Peran aktif tidak berlaku tanpa cabang',
    );
  }
}

export function pickRoleForBranch(
  assignments: { branchId: string; roles: UserRole[] }[],
  branchId: string,
  preferred?: UserRole,
): UserRole {
  const allowed = rolesAtBranch(assignments, branchId);
  if (!allowed.length) {
    throw new BadRequestException('Tidak ada peran di cabang ini');
  }
  if (preferred && allowed.includes(preferred)) return preferred;
  return allowed[0];
}
