import { SetMetadata } from '@nestjs/common';
import { AppRoleName } from '../constants/app-roles';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: AppRoleName[]) => SetMetadata(ROLES_KEY, roles);
