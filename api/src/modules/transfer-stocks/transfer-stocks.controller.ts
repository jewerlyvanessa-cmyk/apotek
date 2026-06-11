import {
  Body,
  Controller,
  Get,
  Param,
  Post,
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
import { CreateDistributionDto } from './dto/create-distribution.dto';
import { CreateTransferStockDto } from './dto/create-transfer-stock.dto';
import { TransferQueryDto } from './dto/transfer-query.dto';
import { TransferStocksService } from './transfer-stocks.service';

@ApiTags('transfer-stocks')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('transfer-stocks')
export class TransferStocksController {
  constructor(private service: TransferStocksService) {}

  @Get()
  async list(@CurrentUser() user: JwtPayloadUser, @Query() query: TransferQueryDto) {
    const data = await this.service.findAll(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Roles(UserRole.WAREHOUSE, UserRole.MANAGER, UserRole.OWNER)
  @Post()
  async create(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateTransferStockDto,
  ) {
    const data = await this.service.create(user, dto);
    return ApiResponseDto.ok(data, 'Transfer created');
  }

  @Roles(UserRole.WAREHOUSE, UserRole.MANAGER, UserRole.OWNER)
  @Post('distributions')
  async createDistribution(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateDistributionDto,
  ) {
    const data = await this.service.createDistribution(user, dto);
    return ApiResponseDto.ok(data, 'Distribusi dibuat');
  }

  @Get(':id')
  async getOne(@CurrentUser() user: JwtPayloadUser, @Param('id') id: string) {
    const data = await this.service.findOne(user, id);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.WAREHOUSE, UserRole.MANAGER, UserRole.OWNER)
  @Post(':id/submit')
  async submit(@CurrentUser() user: JwtPayloadUser, @Param('id') id: string) {
    const data = await this.service.submit(user, id);
    return ApiResponseDto.ok(data, 'Transfer completed');
  }

  @Roles(UserRole.WAREHOUSE, UserRole.MANAGER, UserRole.OWNER)
  @Post(':id/send')
  async sendDistribution(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    const data = await this.service.sendDistribution(user, id);
    return ApiResponseDto.ok(data, 'Distribusi dikirim');
  }

  @Roles(UserRole.WAREHOUSE, UserRole.MANAGER, UserRole.OWNER)
  @Post(':id/receive')
  async receiveDistribution(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    const data = await this.service.receiveDistribution(user, id);
    return ApiResponseDto.ok(data, 'Distribusi diterima');
  }
}

