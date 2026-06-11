import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import admin from 'firebase-admin';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

type FirebaseReady = { ok: true } | { ok: false; reason: string };

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private initialized = false;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
  ) {}

  private ready(): FirebaseReady {
    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.config.get<string>('FIREBASE_PRIVATE_KEY');

    if (!projectId || !clientEmail || !privateKey) {
      return { ok: false, reason: 'Firebase env not configured' };
    }
    return { ok: true };
  }

  private initFirebaseIfNeeded() {
    if (this.initialized) return;
    const status = this.ready();
    if (!status.ok) return;

    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID')!;
    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL')!;
    const privateKey = this.config
      .get<string>('FIREBASE_PRIVATE_KEY')!
      .replace(/\\n/g, '\n');

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
    }
    this.initialized = true;
    this.logger.log('Firebase admin initialized');
  }

  async registerDeviceToken(params: {
    tenantId: string;
    userId: string;
    branchId?: string | null;
    token: string;
    platform?: string | null;
  }) {
    const { tenantId, userId, branchId, token, platform } = params;

    await this.prisma.deviceToken.upsert({
      where: { token },
      update: {
        tenantId,
        userId,
        branchId: branchId ?? null,
        platform: platform ?? null,
        isActive: true,
        lastSeenAt: new Date(),
      },
      create: {
        tenantId,
        userId,
        branchId: branchId ?? null,
        token,
        platform: platform ?? null,
        isActive: true,
        lastSeenAt: new Date(),
      },
    });

    return { ok: true };
  }

  async sendToUser(params: {
    tenantId: string;
    userId: string;
    title: string;
    body: string;
    data?: Record<string, string>;
  }) {
    this.initFirebaseIfNeeded();
    const status = this.ready();
    if (!status.ok) {
      return { ok: false, reason: status.reason };
    }

    const tokens = await this.prisma.deviceToken.findMany({
      where: { tenantId: params.tenantId, userId: params.userId, isActive: true },
      select: { token: true },
      take: 20,
    });

    if (!tokens.length) return { ok: true, sent: 0 };

    const message: admin.messaging.MulticastMessage = {
      tokens: tokens.map((t) => t.token),
      notification: {
        title: params.title,
        body: params.body,
      },
      data: params.data,
    };

    const resp = await admin.messaging().sendEachForMulticast(message);

    // Deactivate invalid tokens
    const invalidTokens: string[] = [];
    resp.responses.forEach((r, idx) => {
      if (r.success) return;
      const code = (r.error as any)?.code as string | undefined;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalidTokens.push(tokens[idx].token);
      }
    });

    if (invalidTokens.length) {
      await this.prisma.deviceToken.updateMany({
        where: { token: { in: invalidTokens } },
        data: { isActive: false },
      });
    }

    return { ok: true, sent: resp.successCount, failed: resp.failureCount };
  }
}

