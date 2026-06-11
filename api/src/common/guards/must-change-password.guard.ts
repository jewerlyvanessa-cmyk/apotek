import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../decorators/skip-auth.decorator';
import { SKIP_MUST_CHANGE_PASSWORD_KEY } from '../decorators/skip-must-change-password.decorator';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

@Injectable()
export class MustChangePasswordGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const skip = this.reflector.getAllAndOverride<boolean>(
      SKIP_MUST_CHANGE_PASSWORD_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (skip) return true;

    const request = context.switchToHttp().getRequest();
    const userId = request.user?.sub as string | undefined;
    if (!userId) return true;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { mustChangePassword: true },
    });

    if (user?.mustChangePassword) {
      throw new ForbiddenException({
        message: 'Ganti password terlebih dahulu',
        code: 'MUST_CHANGE_PASSWORD',
      });
    }

    return true;
  }
}
