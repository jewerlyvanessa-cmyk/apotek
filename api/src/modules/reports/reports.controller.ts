import { Controller, Get, Query, Res, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AppRole } from '../../common/constants/app-roles';
import { UserRole } from '@prisma/client';
import type { Response } from 'express';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ReportRangeDto } from './dto/report-range.dto';
import { TopMedicinesDto } from './dto/top-medicines.dto';
import { ReportsService } from './reports.service';
import {
  buildProfitLossExcel,
  buildSalesExcel,
  buildSalesPdf,
} from './reports-export.util';

@ApiTags('reports')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('reports')
export class ReportsController {
  constructor(private service: ReportsService) {}

  @Roles(
    AppRole.OWNER,
    AppRole.MANAGER,
    AppRole.CASHIER,
    AppRole.PHARMACIST,
    AppRole.STAFF,
  )
  @Get('dashboard')
  async dashboard(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: ReportRangeDto,
  ) {
    const data = await this.service.dashboard(user, query);
    return ApiResponseDto.ok(data);
  }

  @Roles(
    AppRole.OWNER,
    AppRole.MANAGER,
    AppRole.CASHIER,
    AppRole.PHARMACIST,
    AppRole.STAFF,
  )
  @Get('sales')
  async sales(@CurrentUser() user: JwtPayloadUser, @Query() query: ReportRangeDto) {
    const data = await this.service.sales(user, query);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('sales/export.xlsx')
  async exportSalesExcel(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: ReportRangeDto,
    @Res() res: Response,
  ) {
    const data = await this.service.sales(user, query);
    const buf = await buildSalesExcel(data as any);

    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    res.setHeader('Content-Disposition', 'attachment; filename="sales-report.xlsx"');
    return res.send(Buffer.from(buf));
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('sales/export.pdf')
  async exportSalesPdf(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: ReportRangeDto,
    @Res() res: Response,
  ) {
    const data = await this.service.sales(user, query);
    const doc = buildSalesPdf(data as any);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename="sales-report.pdf"');
    doc.pipe(res);
    doc.end();
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('top-medicines')
  async topMedicines(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: TopMedicinesDto,
  ) {
    const data = await this.service.topMedicines(user, query);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('low-stock')
  async lowStock(@CurrentUser() user: JwtPayloadUser, @Query() query: ReportRangeDto) {
    const data = await this.service.lowStock(user, query);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('expired')
  async expired(@CurrentUser() user: JwtPayloadUser, @Query() query: ReportRangeDto) {
    const data = await this.service.expired(user, query);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('profit-loss')
  async profitLoss(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: ReportRangeDto,
  ) {
    const data = await this.service.profitLoss(user, query);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get('profit-loss/export.xlsx')
  async exportProfitLossExcel(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: ReportRangeDto,
    @Res() res: Response,
  ) {
    const data = await this.service.profitLoss(user, query);
    const buf = await buildProfitLossExcel(data);
    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    res.setHeader(
      'Content-Disposition',
      'attachment; filename="profit-loss-report.xlsx"',
    );
    return res.send(Buffer.from(buf));
  }
}

