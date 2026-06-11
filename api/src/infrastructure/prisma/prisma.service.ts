import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { assertTenantModelAccess } from '../../common/utils/tenant-access.context';

function createExtendedClient(base: PrismaClient) {
  return base.$extends({
    query: {
      tenant: {
        async $allOperations({ operation, args, query }) {
          assertTenantModelAccess(operation, args as Record<string, unknown>);
          return query(args);
        },
      },
    },
  });
}

export type ExtendedPrismaClient = ReturnType<typeof createExtendedClient>;

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor() {
    super();
    const extended = createExtendedClient(this);
    return extended as unknown as PrismaService;
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
