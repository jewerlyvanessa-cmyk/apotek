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
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';
import { SuppliersService } from './suppliers.service';

@ApiTags('suppliers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('suppliers')
export class SuppliersController {
  constructor(private service: SuppliersService) {}

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
    @Body() dto: CreateSupplierDto,
  ) {
    const data = await this.service.create(requireTenantId(user), dto);
    return ApiResponseDto.ok(data, 'Supplier created');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  @Put(':id')
  async update(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: UpdateSupplierDto,
  ) {
    const data = await this.service.update(requireTenantId(user), id, dto);
    return ApiResponseDto.ok(data, 'Supplier updated');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Delete(':id')
  async remove(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    await this.service.remove(requireTenantId(user), id);
    return ApiResponseDto.ok(null, 'Supplier deleted');
  }
}
