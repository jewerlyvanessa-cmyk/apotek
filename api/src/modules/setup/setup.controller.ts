import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import {
  DatabaseConnectionDto,
  DatabaseSetupDto,
} from './dto/database-connection.dto';
import { SetupService } from './setup.service';

@ApiTags('setup')
@Controller('setup')
export class SetupController {
  constructor(private setup: SetupService) {}

  @Get('status')
  async status() {
    const data = await this.setup.getStatus();
    return ApiResponseDto.ok(data);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @Get('database')
  async getDatabase(@Req() req: { user?: JwtPayloadUser }) {
    const data = await this.setup.getDatabaseConfig(req.user?.role);
    return ApiResponseDto.ok(data);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @Post('database/test')
  async testDatabase(
    @Body() dto: DatabaseConnectionDto,
    @Req() req: { user?: JwtPayloadUser },
  ) {
    const data = await this.setup.testConnection(dto, req.user?.role);
    return ApiResponseDto.ok(
      data,
      data.ok ? 'Koneksi berhasil' : 'Koneksi gagal',
    );
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @Post('database/create')
  async createDatabase(
    @Body() dto: DatabaseSetupDto,
    @Req() req: { user?: JwtPayloadUser },
  ) {
    const data = await this.setup.createDatabase(dto, req.user?.role);
    return ApiResponseDto.ok(data, data.message);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @Post('database/apply')
  async applyDatabase(
    @Body() dto: DatabaseSetupDto,
    @Req() req: { user?: JwtPayloadUser },
  ) {
    const data = await this.setup.applyDatabaseConfig(dto, req.user?.role);
    return ApiResponseDto.ok(data, data.message);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @Post('database/migrate')
  async migrateDatabase(
    @Body() dto: DatabaseSetupDto,
    @Req() req: { user?: JwtPayloadUser },
  ) {
    const data = await this.setup.runMigrations(dto, req.user?.role);
    return ApiResponseDto.ok(data, data.message);
  }
}
