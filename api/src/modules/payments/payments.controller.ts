import {
  Body,
  Controller,
  FileTypeValidator,
  Get,
  MaxFileSizeValidator,
  Param,
  ParseFilePipe,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { SkipAuth } from '../../common/decorators/skip-auth.decorator';
import { QrisWebhookGuard } from './qris-webhook.guard';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import type { Request } from 'express';
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
import { PayOrderDto } from './dto/pay-order.dto';
import { QrisWebhookDto } from './dto/qris-webhook.dto';
import { PaymentQueryDto } from './dto/payment-query.dto';
import { ensureUploadsDir } from '../../common/utils/uploads';
import { PaymentsService } from './payments.service';

@ApiTags('payments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('payments')
export class PaymentsController {
  constructor(private service: PaymentsService) {}

  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: PaymentQueryDto,
  ) {
    const data = await this.service.findAll(user, query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Roles(UserRole.CASHIER, UserRole.MANAGER, UserRole.OWNER)
  @Post('upload-proof')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (
          _req: Request,
          _file: Express.Multer.File,
          cb: (error: Error | null, destination: string) => void,
        ) => cb(null, ensureUploadsDir('payments')),
        filename: (
          _req: Request,
          file: Express.Multer.File,
          cb: (error: Error | null, filename: string) => void,
        ) => {
          const safeExt = extname(file.originalname || '').toLowerCase() || '.jpg';
          cb(null, `pay_${Date.now()}${safeExt}`);
        },
      }),
    }),
  )
  async uploadProof(
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }),
          new FileTypeValidator({
            fileType: /(jpg|jpeg|png|webp)$/i,
            skipMagicNumbersValidation: true,
          }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    const url = `/uploads/payments/${file.filename}`;
    return ApiResponseDto.ok({ url }, 'Bukti pembayaran diunggah');
  }

  @Get(':id')
  async getOne(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    const data = await this.service.findOne(user, id);
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.CASHIER, UserRole.MANAGER, UserRole.OWNER)
  @Post()
  async pay(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: PayOrderDto,
    @Req() req: any,
  ) {
    const data = await this.service.pay(user, dto, {
      ipAddress: req?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ?? req?.ip,
      userAgent: req?.headers?.['user-agent'],
    });
    return ApiResponseDto.ok(data, 'Payment successful');
  }

  // QRIS: create a charge and return qr_string for UI.
  @Roles(UserRole.CASHIER, UserRole.MANAGER, UserRole.OWNER)
  @Post('qris')
  async createQris(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: PayOrderDto,
    @Req() req: any,
  ) {
    const data = await this.service.createQrisCharge(user, dto, {
      ipAddress: req?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ?? req?.ip,
      userAgent: req?.headers?.['user-agent'],
    });
    return ApiResponseDto.ok(data, 'QRIS created');
  }

  @SkipAuth()
  @UseGuards(QrisWebhookGuard)
  @Post('qris/webhook')
  async qrisWebhook(@Body() dto: QrisWebhookDto) {
    if (dto.status !== 'PAID') {
      return ApiResponseDto.ok({ ok: true, ignored: true });
    }
    const data = await this.service.confirmQrisPaid({
      tenantId: dto.tenant_id,
      orderId: dto.order_id,
      referenceNumber: dto.reference_number,
      amount: dto.amount,
    });
    return ApiResponseDto.ok(data);
  }
}
