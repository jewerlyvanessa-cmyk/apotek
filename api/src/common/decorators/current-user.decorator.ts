import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface JwtPayloadUser {
  sub: string;
  email: string;
  tenantId?: string;
  /** Cabang aktif sesi. */
  branchId?: string;
  /** Semua cabang yang ditugaskan ke user. */
  branchIds?: string[];
  role: string;
  roles?: string[];
}

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtPayloadUser => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);
