import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
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
import { StockAdjustmentDto, StockMutationDto } from './dto/stock-mutation.dto';
import { StockReceiveDto } from './dto/stock-receive.dto';
import { StockMovementQueryDto } from './dto/stock-movement-query.dto';
import { StockQueryDto } from './dto/stock-query.dto';
import { UpdateStockDto } from './dto/update-stock.dto';
import { StocksService } from './stocks.service';

@ApiTags('stocks')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('stocks')
export class StocksController {
  constructor(private service: StocksService) {}

  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: StockQueryDto,
  ) {
    const data = await this.service.findAll(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Get('realtime/:medicineId')
  async realtime(
    @CurrentUser() user: JwtPayloadUser,
    @Param('medicineId') medicineId: string,
    @Query('branch_id') branchId?: string,
    @Query('sellable_only') sellableOnly?: string,
  ) {
    const sellable =
      sellableOnly === undefined ||
      sellableOnly === 'true' ||
      sellableOnly === '1';
    const data = await this.service.getRealtime(
      user,
      medicineId,
      branchId,
      sellable,
    );
    return ApiResponseDto.ok(data);
  }

  @Get('movements')
  async movements(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: StockMovementQueryDto,
  ) {
    const data = await this.service.movements(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Post('mutation')
  async mutation(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: StockMutationDto,
    @Req() req: any,
  ) {
    const data = await this.service.mutate(user, dto, {
      ipAddress: req?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ?? req?.ip,
      userAgent: req?.headers?.['user-agent'],
    });
    return ApiResponseDto.ok(data, 'Stock updated');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Post('receive')
  async receive(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: StockReceiveDto,
    @Req() req: any,
  ) {
    const data = await this.service.receive(user, dto, {
      ipAddress: req?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ?? req?.ip,
      userAgent: req?.headers?.['user-agent'],
    });
    return ApiResponseDto.ok(data, 'Stock received');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Post('adjust')
  async adjust(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: StockAdjustmentDto,
    @Req() req: any,
  ) {
    const data = await this.service.adjust(user, dto, {
      ipAddress: req?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ?? req?.ip,
      userAgent: req?.headers?.['user-agent'],
    });
    return ApiResponseDto.ok(data, 'Stock adjusted');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Patch(':id')
  async update(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: UpdateStockDto,
    @Req() req: any,
  ) {
    const data = await this.service.updateById(user, id, dto, {
      ipAddress: req?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ?? req?.ip,
      userAgent: req?.headers?.['user-agent'],
    });
    return ApiResponseDto.ok(data, 'Stock updated');
  }
}
