import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
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
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { BillingWebhookGuard } from './billing-webhook.guard';
import { BillingWebhookDto } from './dto/billing-webhook.dto';
import { RenewalIntentDto } from './dto/renewal-intent.dto';
import { SubscriptionBillingService } from './subscription-billing.service';

@ApiTags('billing')
@Controller('billing')
export class BillingController {
  constructor(private billing: SubscriptionBillingService) {}

  @Get('plans')
  async plans() {
    const data = this.billing.listSubscriptionPlans();
    return ApiResponseDto.ok(data);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Post('renewal-intent')
  async renewalIntent(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: RenewalIntentDto,
  ) {
    const data = await this.billing.createRenewalIntent(
      requireTenantId(user),
      dto.plan,
    );
    return ApiResponseDto.ok(data, 'Referensi perpanjangan dibuat');
  }

  @Post('webhook')
  @UseGuards(BillingWebhookGuard)
  async webhook(@Body() dto: BillingWebhookDto) {
    const data = await this.billing.processWebhook(dto);
    return ApiResponseDto.ok(data, 'Webhook diproses');
  }
}
