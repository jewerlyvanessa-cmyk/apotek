import {
  BadRequestException,
  Controller,
  ForbiddenException,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import {
  assertBranchAccess,
  isTenantWideUser,
} from '../../common/utils/branch-scope.util';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PlatformBackupService } from '../platform/platform-backup.service';

@ApiTags('backup')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('backup')
export class BackupController {
  constructor(
    private backup: PlatformBackupService,
    private prisma: PrismaService,
  ) {}

  /** Manager cabang: backup cabang sendiri. Manager pusat/owner: pilih cabang via query. */
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('branch')
  async backupBranch(
    @CurrentUser() user: JwtPayloadUser,
    @Query('branch_id') branchId?: string,
  ) {
    const tenantId = requireTenantId(user);
    const targetBranchId = branchId?.trim() || user.branchId;
    if (!targetBranchId) {
      throw new BadRequestException(
        'Pilih cabang (branch_id) untuk backup',
      );
    }

    const branch = await this.prisma.branch.findFirst({
      where: { id: targetBranchId, tenantId },
      select: { id: true },
    });
    if (!branch) {
      throw new BadRequestException('Cabang tidak ditemukan');
    }

    if (!isTenantWideUser(user)) {
      assertBranchAccess(user, targetBranchId);
    }

    const data = await this.backup.exportBranchBackup(tenantId, targetBranchId);
    return ApiResponseDto.ok(data, 'Branch backup ready');
  }

  /** Owner / manajer pusat: backup seluruh tenant. */
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('tenant')
  async backupTenant(@CurrentUser() user: JwtPayloadUser) {
    if (!isTenantWideUser(user)) {
      throw new ForbiddenException(
        'Backup tenant hanya untuk owner atau manajer pusat',
      );
    }
    const tenantId = requireTenantId(user);
    const data = await this.backup.exportTenantBackup(tenantId);
    return ApiResponseDto.ok(data, 'Tenant backup ready');
  }
}
