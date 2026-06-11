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
import { AppRole } from '../../common/constants/app-roles';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderQueryDto } from './dto/order-query.dto';
import { ApprovePharmacyDto } from './dto/approve-pharmacy.dto';
import { RefundOrderDto } from './dto/refund-order.dto';
import { UpdateOrderDto } from './dto/update-order.dto';
import { OrdersService } from './orders.service';

@ApiTags('orders')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('orders')
export class OrdersController {
  constructor(private service: OrdersService) {}

  @Roles(
    AppRole.STAFF,
    AppRole.MANAGER,
    AppRole.CASHIER,
    AppRole.PHARMACIST,
  )
  @Post()
  async create(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateOrderDto,
  ) {
    const data = await this.service.create(user, dto);
    return ApiResponseDto.ok(
      {
        id: data.id,
        order_number: data.orderNumber,
        status: data.status,
        total: data.total,
      },
      'Order created',
    );
  }

  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: OrderQueryDto,
  ) {
    const data = await this.service.findAll(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Get(':id')
  async getOne(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    const data = await this.service.findOne(user, id);
    return ApiResponseDto.ok(data);
  }

  @Roles(AppRole.STAFF, AppRole.MANAGER, AppRole.OWNER)
  @Put(':id')
  async update(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: UpdateOrderDto,
  ) {
    const data = await this.service.update(user, id, dto);
    return ApiResponseDto.ok(
      {
        id: data.id,
        order_number: data.orderNumber,
        status: data.status,
        total: data.total,
      },
      'Order updated',
    );
  }

  @Roles(AppRole.CASHIER, AppRole.MANAGER, AppRole.OWNER)
  @Post(':id/refund')
  async refund(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: RefundOrderDto,
  ) {
    const data = await this.service.refund(user, id, dto);
    return ApiResponseDto.ok(data, 'Retur berhasil — stok dikembalikan');
  }

  @Roles(AppRole.MANAGER, AppRole.PHARMACIST, AppRole.OWNER)
  @Post(':id/cancel')
  async cancel(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    const data = await this.service.cancel(user, id);
    return ApiResponseDto.ok(data, 'Order cancelled');
  }

  @Roles(AppRole.PHARMACIST, AppRole.OWNER)
  @Post(':id/approve-pharmacy')
  async approvePharmacy(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: ApprovePharmacyDto,
  ) {
    const data = await this.service.approvePharmacy(user, id, dto);
    return ApiResponseDto.ok(
      {
        id: data.id,
        order_number: data.orderNumber,
        status: data.status,
      },
      'Telaah apoteker disetujui',
    );
  }
}
