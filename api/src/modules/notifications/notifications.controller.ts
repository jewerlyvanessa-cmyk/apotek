import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import { CurrentUser, JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { NotificationsService } from './notifications.service';

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private service: NotificationsService) {}

  @Post('device-token')
  async registerToken(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: RegisterDeviceTokenDto,
  ) {
    const data = await this.service.registerDeviceToken({
      tenantId: requireTenantId(user),
      userId: user.sub,
      branchId: user.branchId,
      token: dto.token,
      platform: dto.platform,
    });
    return ApiResponseDto.ok(data);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Post('test')
  async testPush(@CurrentUser() user: JwtPayloadUser) {
    const data = await this.service.sendToUser({
      tenantId: requireTenantId(user),
      userId: user.sub,
      title: 'Test notification',
      body: 'FCM is working',
      data: { type: 'test' },
    });
    return ApiResponseDto.ok(data);
  }
}

