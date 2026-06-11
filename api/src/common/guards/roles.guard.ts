import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppRoleName } from '../constants/app-roles';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { JwtPayloadUser } from '../decorators/current-user.decorator';
import { userHasAnyRole } from '../utils/user-roles.util';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<AppRoleName[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles?.length) return true;

    const { user } = context.switchToHttp().getRequest<{ user: JwtPayloadUser }>();
    if (!user || !userHasAnyRole(user, requiredRoles)) {
      throw new ForbiddenException('Insufficient permissions');
    }
    return true;
  }
}
