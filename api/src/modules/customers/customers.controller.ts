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
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { CustomerTransactionsQueryDto } from './dto/customer-transactions-query.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { CustomersService } from './customers.service';

@ApiTags('customers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('customers')
export class CustomersController {
  constructor(private service: CustomersService) {}

  @Roles(
    UserRole.OWNER,
    UserRole.MANAGER,
    UserRole.STAFF,
    UserRole.CASHIER,
  )
  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: PaginationQueryDto,
  ) {
    const data = await this.service.findAll(requireTenantId(user), query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Roles(
    UserRole.OWNER,
    UserRole.MANAGER,
    UserRole.STAFF,
    UserRole.CASHIER,
  )
  @Roles(
    UserRole.OWNER,
    UserRole.MANAGER,
    UserRole.STAFF,
    UserRole.CASHIER,
  )
  @Get(':id/transactions')
  async transactions(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Query() query: CustomerTransactionsQueryDto,
  ) {
    const data = await this.service.getTransactions(
      requireTenantId(user),
      id,
      query,
    );
    return ApiResponseDto.ok(data, 'Success', data.meta);
  }

  @Get(':id')
  async getOne(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    const data = await this.service.findOne(requireTenantId(user), id);
    return ApiResponseDto.ok(data);
  }

  @Roles(
    UserRole.OWNER,
    UserRole.MANAGER,
    UserRole.STAFF,
    UserRole.CASHIER,
  )
  @Post()
  async create(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateCustomerDto,
  ) {
    const data = await this.service.create(requireTenantId(user), dto);
    return ApiResponseDto.ok(data, 'Customer created');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER)
  @Put(':id')
  async update(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: UpdateCustomerDto,
  ) {
    const data = await this.service.update(requireTenantId(user), id, dto);
    return ApiResponseDto.ok(data, 'Customer updated');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Delete(':id')
  async remove(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    await this.service.remove(requireTenantId(user), id);
    return ApiResponseDto.ok(null, 'Customer deactivated');
  }
}
