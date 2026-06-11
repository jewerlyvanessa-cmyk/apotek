import {
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { AppRole } from '../constants/app-roles';
import { JwtPayloadUser } from '../decorators/current-user.decorator';
import { userHasAnyRole, userHasRole } from './user-roles.util';

/** Semua cabang yang boleh diakses user (bukan tenant-wide). */
export function assignedBranchIds(
  user: Pick<JwtPayloadUser, 'branchId' | 'branchIds'>,
): string[] {
  if (user.branchIds?.length) return user.branchIds;
  return user.branchId ? [user.branchId] : [];
}

/** Pemilik tenant atau manajer pusat (MANAGER tanpa penugasan cabang). */
export function isTenantWideUser(
  user: Pick<JwtPayloadUser, 'role' | 'roles' | 'branchId' | 'branchIds'>,
): boolean {
  if (userHasRole(user, AppRole.OWNER)) return true;
  if (!userHasRole(user, AppRole.MANAGER)) return false;
  // Kepala cabang: JWT branchIds sudah difilter per peran aktif (MANAGER).
  if (assignedBranchIds(user).length > 0) return false;
  return true;
}

/** Kepala cabang: MANAGER terikat cabang (ada cabang dalam scope sesi). */
export function isBranchManager(
  user: Pick<JwtPayloadUser, 'role' | 'roles' | 'branchId' | 'branchIds'>,
): boolean {
  return userHasRole(user, AppRole.MANAGER) && assignedBranchIds(user).length > 0;
}

export function isPharmacist(user: Pick<JwtPayloadUser, 'role' | 'roles'>): boolean {
  return userHasRole(user, AppRole.PHARMACIST);
}

/** @deprecated Gunakan isTenantWideUser */
export function isOwnerOrManager(user: Pick<JwtPayloadUser, 'role' | 'roles' | 'branchId'>): boolean {
  return isTenantWideUser(user);
}

/** Owner atau manajer pusat — boleh kelola master cabang tenant. */
export function canManageBranches(
  user: Pick<JwtPayloadUser, 'role' | 'roles' | 'branchId'>,
): boolean {
  return isTenantWideUser(user);
}

export function assertCanManageBranches(user: JwtPayloadUser) {
  if (!canManageBranches(user)) {
    throw new ForbiddenException(
      'Hanya owner atau manajer pusat yang dapat mengelola cabang',
    );
  }
}

export function assertCanManageUsers(user: JwtPayloadUser) {
  if (!isTenantWideUser(user)) {
    throw new ForbiddenException(
      'Hanya owner atau manajer pusat yang dapat mengelola user',
    );
  }
}

/**
 * Cabang sesi login — non tenant-wide hanya boleh cabang aktif di JWT.
 */
export function resolveActiveSessionBranchId(
  user: JwtPayloadUser,
  queryBranchId?: string,
): string {
  const sessionBranchId = user.branchId;
  if (!sessionBranchId) {
    throw new BadRequestException(
      'Cabang aktif wajib dipilih. Gunakan ganti cabang di menu.',
    );
  }

  const allowed = assignedBranchIds(user);
  if (allowed.length > 0 && !allowed.includes(sessionBranchId)) {
    throw new ForbiddenException('Cabang sesi tidak valid');
  }
  if (queryBranchId && queryBranchId !== sessionBranchId) {
    throw new ForbiddenException('Hanya dapat mengakses cabang aktif');
  }
  return sessionBranchId;
}

/**
 * Scope baca stok/mutasi: tenant-wide boleh tanpa branch_id (semua cabang).
 */
export function resolveBranchScopeForList(
  user: JwtPayloadUser,
  queryBranchId?: string,
): { branchId?: string } {
  if (isTenantWideUser(user)) {
    return queryBranchId ? { branchId: queryBranchId } : {};
  }
  return { branchId: resolveActiveSessionBranchId(user, queryBranchId) };
}

/** branch_id wajib untuk tulis stok; validasi akses cabang. */
export function resolveBranchIdForWrite(
  user: JwtPayloadUser,
  branchIdFromDto?: string,
): string {
  const branchId = branchIdFromDto ?? user.branchId;
  if (!branchId) {
    throw new BadRequestException('branch_id is required');
  }
  assertBranchAccess(user, branchId);
  return branchId;
}

export function resolveBranchIdForFilter(
  user: JwtPayloadUser,
  queryBranchId?: string,
): string {
  if (isTenantWideUser(user)) {
    if (!queryBranchId) {
      throw new BadRequestException('branch_id is required');
    }
    return queryBranchId;
  }

  if (user.branchId) {
    return resolveActiveSessionBranchId(user, queryBranchId);
  }

  const allowed = assignedBranchIds(user);
  if (!allowed.length) {
    throw new BadRequestException('Akun harus terikat cabang');
  }

  if (queryBranchId) {
    if (!allowed.includes(queryBranchId)) {
      throw new ForbiddenException('Tidak dapat mengakses cabang lain');
    }
    return queryBranchId;
  }

  if (allowed.length === 1) return allowed[0];
  throw new BadRequestException(
    'Cabang aktif wajib dipilih. Gunakan ganti cabang di menu.',
  );
}

export function assertBranchAccess(user: JwtPayloadUser, branchId: string) {
  if (isTenantWideUser(user)) return;
  const allowed = assignedBranchIds(user);
  if (!allowed.includes(branchId)) {
    throw new ForbiddenException('Akses cabang tidak diizinkan');
  }
}

export function canCancelOrder(
  user: JwtPayloadUser,
  order: { branchId: string; status: string },
): boolean {
  if (!['WAITING_PAYMENT', 'PENDING_PHARMACY'].includes(order.status)) {
    return false;
  }
  if (isTenantWideUser(user)) return true;
  if (!assignedBranchIds(user).includes(order.branchId)) return false;
  return userHasAnyRole(user, [AppRole.MANAGER, AppRole.PHARMACIST]);
}
