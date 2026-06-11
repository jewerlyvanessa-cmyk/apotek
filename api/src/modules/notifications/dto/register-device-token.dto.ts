import { IsOptional, IsString } from 'class-validator';

export class RegisterDeviceTokenDto {
  @IsString()
  token: string;

  @IsOptional()
  @IsString()
  platform?: 'android' | 'ios' | 'web';
}

