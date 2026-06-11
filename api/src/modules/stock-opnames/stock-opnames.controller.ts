import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
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
import { CreateStockOpnameDto } from './dto/create-stock-opname.dto';
import { StockOpnameQueryDto } from './dto/opname-query.dto';
import { UpsertOpnameItemsDto } from './dto/upsert-opname-items.dto';
import { StockOpnamesService } from './stock-opnames.service';

@ApiTags('stock-opnames')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('stock-opnames')
export class StockOpnamesController {
  constructor(private service: StockOpnamesService) {}

  @Roles(UserRole.WAREHOUSE, UserRole.MANAGER, UserRole.OWNER)
  @Post()
  async create(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateStockOpnameDto,
  ) {
    const data = await this.service.create(user, dto);
    return ApiResponseDto.ok(data, 'Opname created');
  }

  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: StockOpnameQueryDto,
  ) {
    const data = await this.service.findAll(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Get(':id')
  async getOne(@CurrentUser() user: JwtPayloadUser, @Param('id') id: string) {
    const data = await this.service.findOne(user, id);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.WAREHOUSE, UserRole.MANAGER, UserRole.OWNER)
  @Put(':id/items')
  async upsertItems(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: UpsertOpnameItemsDto,
  ) {
    const data = await this.service.upsertItems(user, id, dto);
    return ApiResponseDto.ok(data, 'Items updated');
  }

  @Roles(UserRole.WAREHOUSE, UserRole.MANAGER, UserRole.OWNER)
  @Post(':id/submit')
  async submit(@CurrentUser() user: JwtPayloadUser, @Param('id') id: string) {
    const data = await this.service.submit(user, id);
    return ApiResponseDto.ok(data, 'Opname submitted');
  }
}

