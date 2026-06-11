import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { SkipMustChangePassword } from '../../common/decorators/skip-must-change-password.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AuthService } from './auth.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { SwitchBranchDto } from './dto/switch-branch.dto';
import { SwitchRoleDto } from './dto/switch-role.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  async login(@Body() dto: LoginDto, @Req() req: any) {
    const data = await this.authService.login(dto, {
      ipAddress: req?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ?? req?.ip,
      userAgent: req?.headers?.['user-agent'],
    });
    return ApiResponseDto.ok(data);
  }

  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    const data = await this.authService.refresh(dto.refresh_token);
    return ApiResponseDto.ok(data);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @SkipMustChangePassword()
  @Post('change-password')
  async changePassword(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: ChangePasswordDto,
  ) {
    const data = await this.authService.changePassword(user.sub, dto);
    return ApiResponseDto.ok(data, data.message);
  }

  @SkipMustChangePassword()
  @Post('logout')
  async logout(@Body() body: { refresh_token?: string }) {
    const data = await this.authService.logout(body.refresh_token);
    return ApiResponseDto.ok(data);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('switch-role')
  async switchRole(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: SwitchRoleDto,
  ) {
    const data = await this.authService.switchRole(user.sub, dto);
    return ApiResponseDto.ok(data);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('switch-branch')
  async switchBranch(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: SwitchBranchDto,
  ) {
    const data = await this.authService.switchBranch(user.sub, dto);
    return ApiResponseDto.ok(data);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUser() user: JwtPayloadUser) {
    const data = await this.authService.me(user.sub);
    return ApiResponseDto.ok(data);
  }
}
