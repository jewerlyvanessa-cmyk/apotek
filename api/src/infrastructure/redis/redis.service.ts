import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

type MemoryEntry = { payload: string; expiresAt: number };

@Injectable()
export class RedisCacheService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisCacheService.name);
  private readonly client: Redis | null;
  private readonly prefix: string;
  private readonly memory = new Map<string, MemoryEntry>();
  private readonly memoryTagIndex = new Map<string, Set<string>>();

  constructor(private config: ConfigService) {
    const url = this.config.get<string>('REDIS_URL')?.trim();
    this.prefix = this.config.get<string>('REDIS_PREFIX', 'apotikflow');

    if (!url) {
      this.client = null;
      this.logger.log(
        'REDIS_URL not set — using in-memory cache (no Docker/Redis required)',
      );
      return;
    }

    this.client = new Redis(url, {
      maxRetriesPerRequest: 1,
      enableReadyCheck: true,
      connectTimeout: 500,
      lazyConnect: true,
    });

    this.client.on('error', (err) => {
      this.logger.warn(`Redis error: ${err?.message ?? err}`);
    });
  }

  async onModuleDestroy() {
    if (!this.client) return;
    try {
      await this.client.quit();
    } catch {
      // ignore
    }
  }

  enabled() {
    return true;
  }

  usesRedis() {
    return !!this.client;
  }

  async healthCheck(): Promise<{ enabled: boolean; ok: boolean }> {
    if (!this.client) {
      return { enabled: false, ok: true };
    }
    try {
      const pong = await this.client.ping();
      return { enabled: true, ok: pong === 'PONG' };
    } catch {
      return { enabled: true, ok: false };
    }
  }

  key(raw: string) {
    return `${this.prefix}:${raw}`;
  }

  tagKey(tag: string) {
    return this.key(`tag:${tag}`);
  }

  private memoryGet<T>(fullKey: string): T | null {
    const entry = this.memory.get(fullKey);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.memory.delete(fullKey);
      return null;
    }
    try {
      return JSON.parse(entry.payload) as T;
    } catch {
      return null;
    }
  }

  private memorySet(
    fullKey: string,
    value: unknown,
    ttlSeconds: number,
    tags: string[],
  ) {
    this.memory.set(fullKey, {
      payload: JSON.stringify(value),
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
    if (tags.length === 0) return;
    for (const tag of tags) {
      const tkey = this.tagKey(tag);
      let keys = this.memoryTagIndex.get(tkey);
      if (!keys) {
        keys = new Set();
        this.memoryTagIndex.set(tkey, keys);
      }
      keys.add(fullKey);
    }
  }

  private memoryInvalidateTags(tags: string[]) {
    for (const tag of tags) {
      const tkey = this.tagKey(tag);
      const keys = this.memoryTagIndex.get(tkey);
      if (!keys) continue;
      for (const k of keys) {
        this.memory.delete(k);
      }
      this.memoryTagIndex.delete(tkey);
    }
  }

  async getJson<T>(rawKey: string): Promise<T | null> {
    const fullKey = this.key(rawKey);
    if (!this.client) {
      return this.memoryGet<T>(fullKey);
    }
    try {
      const val = await this.client.get(fullKey);
      if (!val) return null;
      try {
        return JSON.parse(val) as T;
      } catch {
        return null;
      }
    } catch (err) {
      this.logger.warn(`Redis get failed: ${(err as Error)?.message ?? err}`);
      return this.memoryGet<T>(fullKey);
    }
  }

  async setJson(
    rawKey: string,
    value: unknown,
    ttlSeconds: number,
    tags: string[] = [],
  ) {
    const fullKey = this.key(rawKey);
    if (!this.client) {
      this.memorySet(fullKey, value, ttlSeconds, tags);
      return;
    }
    try {
      await this.client.set(fullKey, JSON.stringify(value), 'EX', ttlSeconds);
      if (tags.length > 0) {
        const expireSeconds = Math.max(ttlSeconds * 10, 3600);
        const pipeline = this.client.pipeline();
        for (const tag of tags) {
          pipeline.sadd(this.tagKey(tag), fullKey);
          pipeline.expire(this.tagKey(tag), expireSeconds);
        }
        await pipeline.exec();
      }
    } catch (err) {
      this.logger.warn(`Redis set failed: ${(err as Error)?.message ?? err}`);
      this.memorySet(fullKey, value, ttlSeconds, tags);
    }
  }

  async invalidateTags(tags: string[]) {
    if (!this.client) {
      this.memoryInvalidateTags(tags);
      return;
    }
    try {
      for (const tag of tags) {
        const tkey = this.tagKey(tag);
        const keys = await this.client.smembers(tkey);
        if (keys.length > 0) {
          await this.client.del(...keys);
        }
        await this.client.del(tkey);
      }
    } catch (err) {
      this.logger.warn(
        `Redis invalidate failed: ${(err as Error)?.message ?? err}`,
      );
      this.memoryInvalidateTags(tags);
    }
  }
}
