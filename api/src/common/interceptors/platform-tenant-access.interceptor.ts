import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { runWithFullTenantAccess } from '../utils/tenant-access.context';

/** Mengaktifkan akses penuh ke model Tenant selama request platform (Super Admin). */
@Injectable()
export class PlatformTenantAccessInterceptor implements NestInterceptor {
  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return new Observable((subscriber) => {
      runWithFullTenantAccess(() => {
        next.handle().subscribe({
          next: (value) => subscriber.next(value),
          error: (err) => subscriber.error(err),
          complete: () => subscriber.complete(),
        });
      });
    });
  }
}
