import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { ActivateLicenseDto } from './dto/activate-license.dto';
import { LicenseService } from './license.service';

@ApiTags('license')
@Controller('license')
export class LicenseController {
  constructor(private license: LicenseService) {}

  @Get('status')
  async status() {
    const data = await this.license.getPublicStatus();
    return ApiResponseDto.ok(data);
  }

  @Post('activate')
  async activate(@Body() dto: ActivateLicenseDto) {
    const data = await this.license.activateLicenseKey(dto.license_key);
    return ApiResponseDto.ok(data, 'Lisensi diaktifkan');
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUser() user: JwtPayloadUser) {
    const data = await this.license.getPublicStatus(user.tenantId);
    return ApiResponseDto.ok(data);
  }
}
