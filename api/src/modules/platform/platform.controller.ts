import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CreateBranchDto } from '../branches/dto/create-branch.dto';
import { CreateTenantDto } from './dto/create-tenant.dto';
import { ProvisionOwnerDto } from './dto/provision-owner.dto';
import { TenantBranchesQueryDto } from './dto/tenant-branches-query.dto';
import { UpdateBranchDto } from './dto/update-branch.dto';
import { ExtendTenantSubscriptionDto } from './dto/extend-tenant-subscription.dto';
import { UpdateTenantDto } from './dto/update-tenant.dto';
import { PlatformTenantAccessInterceptor } from '../../common/interceptors/platform-tenant-access.interceptor';
import { GenerateLicenseDto } from '../license/dto/generate-license.dto';
import { LICENSE_PLAN_CATALOG } from '../license/license-plans';
import { LicenseService } from '../license/license.service';
import { PlatformBackupService } from './platform-backup.service';
import { PlatformService } from './platform.service';

@ApiTags('platform')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@UseInterceptors(PlatformTenantAccessInterceptor)
@Roles(UserRole.SUPER_ADMIN)
@Controller('platform')
export class PlatformController {
  constructor(
    private platformService: PlatformService,
    private platformBackupService: PlatformBackupService,
    private licenseService: LicenseService,
  ) {}

  @Get('tenants')
  async listTenants(@Query() query: PaginationQueryDto) {
    const data = await this.platformService.listTenants(query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Get('tenants/:id')
  async getTenant(@Param('id') id: string) {
    const data = await this.platformService.getTenant(id);
    return ApiResponseDto.ok(data);
  }

  @Post('tenants')
  async createTenant(@Body() dto: CreateTenantDto) {
    const data = await this.platformService.createTenant(dto);
    return ApiResponseDto.ok(data, 'Tenant created');
  }

  @Patch('tenants/:id')
  async updateTenant(@Param('id') id: string, @Body() dto: UpdateTenantDto) {
    const data = await this.platformService.updateTenant(id, dto);
    return ApiResponseDto.ok(data, 'Tenant updated');
  }

  @Delete('tenants/:id')
  async deleteTenant(@Param('id') id: string) {
    const data = await this.platformService.deleteTenant(id);
    const message = data.permanent
      ? 'Tenant dihapus permanen'
      : 'Tenant dinonaktifkan (masih ada cabang atau data terkait)';
    return ApiResponseDto.ok(data, message);
  }

  @Patch('tenants/:id/subscription')
  async extendTenantSubscription(
    @Param('id') id: string,
    @Body() dto: ExtendTenantSubscriptionDto,
  ) {
    const data = await this.platformService.extendTenantSubscription(id, dto);
    return ApiResponseDto.ok(data, 'Langganan tenant diperbarui');
  }

  @Post('tenants/:tenantId/owner')
  async provisionOwner(
    @Param('tenantId') tenantId: string,
    @Body() dto: ProvisionOwnerDto,
  ) {
    const data = await this.platformService.provisionOwner(tenantId, dto);
    return ApiResponseDto.ok(data, 'Owner tenant dibuat');
  }

  @Get('branches')
  async listBranches(@Query() query: TenantBranchesQueryDto) {
    const data = await this.platformService.listBranches(
      query.tenant_id,
      query,
    );
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Post('tenants/:tenantId/branches')
  async createBranch(
    @Param('tenantId') tenantId: string,
    @Body() dto: CreateBranchDto,
  ) {
    const data = await this.platformService.createBranch(tenantId, dto);
    return ApiResponseDto.ok(data, 'Branch created');
  }

  @Put('tenants/:tenantId/branches/:branchId')
  async updateBranch(
    @Param('tenantId') tenantId: string,
    @Param('branchId') branchId: string,
    @Body() dto: UpdateBranchDto,
  ) {
    const data = await this.platformService.updateBranch(
      tenantId,
      branchId,
      dto,
    );
    return ApiResponseDto.ok(data, 'Branch updated');
  }

  @Delete('tenants/:tenantId/branches/:branchId')
  async deleteBranch(
    @Param('tenantId') tenantId: string,
    @Param('branchId') branchId: string,
  ) {
    const data = await this.platformService.deleteBranch(tenantId, branchId);
    return ApiResponseDto.ok(data, 'Cabang dihapus');
  }

  @Get('licenses/plans')
  listLicensePlans() {
    return ApiResponseDto.ok(LICENSE_PLAN_CATALOG, 'Katalog paket lisensi');
  }

  @Post('licenses/generate')
  async generateLicense(@Body() dto: GenerateLicenseDto) {
    let tenantCode = dto.tenant_code?.trim();
    if (dto.tenant_id) {
      const tenant = await this.platformService.getTenant(dto.tenant_id);
      tenantCode = tenant.code;
    }

    const data = this.licenseService.generateLicenseKey({
      customer: dto.customer,
      type: dto.type,
      plan: dto.plan,
      tenant_code: tenantCode,
      max_branches: dto.max_branches,
      days: dto.days,
    });

    if (dto.tenant_id) {
      const payload = data.payload as {
        plan?: string;
        type?: string;
        expires_at?: string | null;
      };
      await this.platformService.syncTenantSubscriptionFromLicense(
        dto.tenant_id,
        {
          plan: payload.plan,
          type: payload.type,
          expiresAt: payload.expires_at ?? null,
        },
      );
    }

    return ApiResponseDto.ok(data, 'Kode lisensi dibuat');
  }

  @Get('backup/tenant/:tenantId')
  async backupTenant(@Param('tenantId') tenantId: string) {
    const data = await this.platformBackupService.exportTenantBackup(tenantId);
    return ApiResponseDto.ok(data, 'Tenant backup ready');
  }

  @Get('backup/branch/:branchId')
  async backupBranch(
    @Param('branchId') branchId: string,
    @Query() query: TenantBranchesQueryDto,
  ) {
    const data = await this.platformBackupService.exportBranchBackup(
      query.tenant_id,
      branchId,
    );
    return ApiResponseDto.ok(data, 'Branch backup ready');
  }
}
