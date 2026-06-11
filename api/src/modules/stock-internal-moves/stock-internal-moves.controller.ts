import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
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
import { InternalMoveQueryDto } from './dto/internal-move-query.dto';
import { ReplenishStockDto } from './dto/replenish-stock.dto';
import { UpdateBranchStockModeDto } from './dto/update-branch-stock-mode.dto';
import { StockInternalMovesService } from './stock-internal-moves.service';

@ApiTags('stock-internal-moves')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class StockInternalMovesController {
  constructor(private service: StockInternalMovesService) {}

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Get('branches/:branchId/stock-locations')
  async locations(
    @CurrentUser() user: JwtPayloadUser,
    @Param('branchId') branchId: string,
  ) {
    const data = await this.service.listLocations(user, branchId);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Patch('branches/:branchId/stock-mode')
  async updateStockMode(
    @CurrentUser() user: JwtPayloadUser,
    @Param('branchId') branchId: string,
    @Body() dto: UpdateBranchStockModeDto,
  ) {
    const data = await this.service.updateBranchStockMode(
      user,
      branchId,
      dto.stock_mode,
      dto.move_existing_to,
    );
    return ApiResponseDto.ok(data, 'Mode stok cabang diperbarui');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Get('stock-internal-moves')
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: InternalMoveQueryDto,
  ) {
    const data = await this.service.list(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Post('stock-internal-moves/replenish')
  async replenish(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: ReplenishStockDto,
  ) {
    const data = await this.service.replenish(user, dto);
    return ApiResponseDto.ok(data, 'Etalase berhasil diisi');
  }
}
