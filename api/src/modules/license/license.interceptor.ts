import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Observable } from 'rxjs';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { assertBranchIsActive } from '../../common/utils/tenant-access.util';
import { LicenseService } from './license.service';

@Injectable()
export class LicenseInterceptor implements NestInterceptor {
  constructor(
    private license: LicenseService,
    private config: ConfigService,
    private prisma: PrismaService,
  ) {}

  private apiPrefix(): string {
    const p = this.config.get<string>('API_PREFIX', 'api/v1');
    return `/${p.replace(/^\/|\/$/g, '')}`;
  }

  private isPublicPath(path: string): boolean {
    const prefix = this.apiPrefix();
    const allowed = [
      `${prefix}/health`,
      `${prefix}/license/status`,
      `${prefix}/license/activate`,
      `${prefix}/setup/status`,
    ];
    return allowed.some((p) => path === p || path.startsWith(`${p}/`));
  }

  private skipsTenantCheck(path: string): boolean {
    const prefix = this.apiPrefix();
    const allowed = [
      `${prefix}/auth/login`,
      `${prefix}/auth/refresh`,
    ];
    return (
      this.isPublicPath(path) ||
      allowed.some((p) => path === p || path.startsWith(`${p}/`))
    );
  }

  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    const req = context.switchToHttp().getRequest<{
      url?: string;
      user?: JwtPayloadUser;
    }>();
    const path = (req.url ?? '').split('?')[0];

    if (this.isPublicPath(path)) {
      return next.handle();
    }

    if (this.license.isOnPrem()) {
      this.license.assertInstallationLicense();
    }

    if (this.skipsTenantCheck(path)) {
      return next.handle();
    }

    const user = req.user;
    if (user?.tenantId && user.role !== 'SUPER_ADMIN') {
      await this.license.assertTenantAccess(user.tenantId);
      if (user.branchId) {
        await assertBranchIsActive(this.prisma, user.tenantId, user.branchId);
      }
    }

    return next.handle();
  }
}
