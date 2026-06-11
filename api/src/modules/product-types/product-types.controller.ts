import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CreateProductTypeDto } from './dto/create-product-type.dto';
import { UpdateProductTypeDto } from './dto/update-product-type.dto';
import { ProductTypesService } from './product-types.service';

@ApiTags('product-types')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('product-types')
export class ProductTypesController {
  constructor(private service: ProductTypesService) {}

  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: PaginationQueryDto,
  ) {
    const data = await this.service.findAll(requireTenantId(user), query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Get(':id')
  async getOne(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    const data = await this.service.findOne(requireTenantId(user), id);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Post()
  async create(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateProductTypeDto,
  ) {
    const data = await this.service.create(requireTenantId(user), dto);
    return ApiResponseDto.ok(data, 'Tipe produk dibuat');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Put(':id')
  async update(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: UpdateProductTypeDto,
  ) {
    const data = await this.service.update(requireTenantId(user), id, dto);
    return ApiResponseDto.ok(data, 'Tipe produk diperbarui');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Delete(':id')
  async remove(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    await this.service.remove(requireTenantId(user), id);
    return ApiResponseDto.ok(null, 'Tipe produk dihapus');
  }
}
