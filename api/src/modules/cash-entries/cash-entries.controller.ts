import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import { AppRole } from '../../common/constants/app-roles';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CashEntriesService } from './cash-entries.service';
import { CashEntryQueryDto } from './dto/cash-entry-query.dto';
import { CreateCashEntryDto } from './dto/create-cash-entry.dto';

@ApiTags('cash-entries')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(AppRole.CASHIER, AppRole.MANAGER, AppRole.OWNER)
@Controller('cash-entries')
export class CashEntriesController {
  constructor(private service: CashEntriesService) {}

  @Post()
  async create(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateCashEntryDto,
  ) {
    const data = await this.service.create(user, dto);
    return ApiResponseDto.ok(data, 'Pencatatan kas disimpan');
  }

  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: CashEntryQueryDto,
  ) {
    const data = await this.service.findAll(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Get('summary')
  async summary(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: CashEntryQueryDto,
  ) {
    const data = await this.service.summary(user, query);
    return ApiResponseDto.ok(data);
  }

  @Delete(':id')
  async remove(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    await this.service.remove(user, id);
    return ApiResponseDto.ok(null, 'Pencatatan kas dihapus');
  }
}
