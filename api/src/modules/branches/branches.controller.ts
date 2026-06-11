import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AppRole } from '../../common/constants/app-roles';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { BranchQueryDto } from './dto/branch-query.dto';
import { BranchesService } from './branches.service';

@ApiTags('branches')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('branches')
export class BranchesController {
  constructor(private branchesService: BranchesService) {}

  /** Read-only untuk tenant. Kelola cabang hanya via Super Admin (/platform). */
  @Roles(
    AppRole.OWNER,
    AppRole.MANAGER,
    AppRole.CASHIER,
    AppRole.STAFF,
    AppRole.WAREHOUSE,
    AppRole.PHARMACIST,
  )
  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: BranchQueryDto,
  ) {
    const tenantId = requireTenantId(user);
    const data = await this.branchesService.findAll(tenantId, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Roles(AppRole.OWNER, AppRole.MANAGER, AppRole.WAREHOUSE)
  @Get('central')
  async central(@CurrentUser() user: JwtPayloadUser) {
    const data = await this.branchesService.getCentralWarehouse(
      requireTenantId(user),
    );
    return ApiResponseDto.ok(data);
  }
}
