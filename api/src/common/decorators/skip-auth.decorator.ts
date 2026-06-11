import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/** Lewati JwtAuthGuard — gunakan guard khusus (mis. webhook) di endpoint yang sama. */
export const SkipAuth = () => SetMetadata(IS_PUBLIC_KEY, true);
