import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

export type AuditLogRequestMeta = {
  ipAddress?: string | null;
  userAgent?: string | null;
};

export type CreateAuditLogInput = {
  tenantId: string;
  userId?: string | null;
  module: string;
  action: string;
  referenceId?: string | null;
  oldData?: unknown;
  newData?: unknown;
} & AuditLogRequestMeta;

@Injectable()
export class AuditLogsService {
  constructor(private prisma: PrismaService) {}

  async log(input: CreateAuditLogInput) {
    const { oldData, newData, ...rest } = input;
    return this.prisma.auditLog.create({
      data: {
        ...rest,
        oldData: oldData === undefined ? undefined : (oldData as any),
        newData: newData === undefined ? undefined : (newData as any),
      },
    });
  }
}

