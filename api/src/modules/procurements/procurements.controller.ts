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
import { CreateProcurementDto } from './dto/create-procurement.dto';
import { ProcurementQueryDto } from './dto/procurement-query.dto';
import { ProcurementsService } from './procurements.service';

@ApiTags('procurements')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('procurements')
export class ProcurementsController {
  constructor(private service: ProcurementsService) {}

  @Get()
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: ProcurementQueryDto,
  ) {
    const data = await this.service.findAll(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Get(':id')
  @Roles(UserRole.OWNER, UserRole.MANAGER, UserRole.WAREHOUSE)
  async getOne(@CurrentUser() user: JwtPayloadUser, @Param('id') id: string) {
    const data = await this.service.findOne(user, id);
    return ApiResponseDto.ok(data);
  }

  @Post()
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async create(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateProcurementDto,
  ) {
    const data = await this.service.create(user, dto);
    return ApiResponseDto.ok(data, 'Procurement created');
  }

  @Post(':id/complete')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async complete(@CurrentUser() user: JwtPayloadUser, @Param('id') id: string) {
    const data = await this.service.complete(user, id);
    return ApiResponseDto.ok(data, 'Procurement completed — stok masuk gudang pusat');
  }

  @Post(':id/cancel')
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  async cancel(@CurrentUser() user: JwtPayloadUser, @Param('id') id: string) {
    const data = await this.service.cancel(user, id);
    return ApiResponseDto.ok(data, 'Procurement cancelled');
  }
}
