import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @ApiProperty()
  @IsString()
  @MinLength(6)
  current_password!: string;

  @ApiProperty()
  @IsString()
  @MinLength(8)
  new_password!: string;
}
