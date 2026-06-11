import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ApiResponseDto } from '../../common/dto/api-response.dto';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import {
  CurrentUser,
  JwtPayloadUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { assertCanManageUsers } from '../../common/utils/branch-scope.util';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateRoleDto } from './dto/update-role.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Get()
  async list(
    @CurrentUser() user: JwtPayloadUser,
    @Query() query: PaginationQueryDto,
  ) {
    assertCanManageUsers(user);
    const data = await this.usersService.findAll(requireTenantId(user), query);
    return ApiResponseDto.ok(data.items, 'Success', data.meta);
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Post()
  async create(
    @CurrentUser() user: JwtPayloadUser,
    @Body() dto: CreateUserDto,
  ) {
    assertCanManageUsers(user);
    const data = await this.usersService.create(requireTenantId(user), dto);
    return ApiResponseDto.ok(data, 'User created');
  }

  @Roles(UserRole.OWNER)
  @Put(':id/role')
  async updateRole(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: UpdateRoleDto,
  ) {
    const data = await this.usersService.updateRole(
      requireTenantId(user),
      id,
      dto,
    );
    return ApiResponseDto.ok(data, 'Role updated');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Put(':id')
  async updateUser(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: UpdateUserDto,
  ) {
    assertCanManageUsers(user);
    const data = await this.usersService.update(
      requireTenantId(user),
      id,
      dto,
      user.sub,
    );
    return ApiResponseDto.ok(data, 'User updated');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Delete(':id')
  async removeUser(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
  ) {
    assertCanManageUsers(user);
    const data = await this.usersService.remove(
      requireTenantId(user),
      id,
      user.sub,
    );
    return ApiResponseDto.ok(data, 'User dihapus');
  }

  @Roles(UserRole.OWNER, UserRole.MANAGER)
  @Put(':id/password')
  async resetPassword(
    @CurrentUser() user: JwtPayloadUser,
    @Param('id') id: string,
    @Body() dto: ResetPasswordDto,
  ) {
    assertCanManageUsers(user);
    const data = await this.usersService.resetPassword(
      requireTenantId(user),
      id,
      dto.new_password,
    );
    return ApiResponseDto.ok(data, 'Password diperbarui');
  }
}
