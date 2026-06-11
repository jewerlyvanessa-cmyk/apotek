import { ForbiddenException } from '@nestjs/common';
import { JwtPayloadUser } from '../decorators/current-user.decorator';

export function requireTenantId(user: JwtPayloadUser): string {
  const tenantId = user.tenantId;
  if (!tenantId) {
    throw new ForbiddenException('Tenant context required');
  }
  return tenantId;
}
