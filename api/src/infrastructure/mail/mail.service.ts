import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly config: ConfigService) {}

  isConfigured(): boolean {
    const host = this.config.get<string>('SMTP_HOST')?.trim();
    const from = this.config.get<string>('SMTP_FROM')?.trim();
    return Boolean(host && from);
  }

  async send(params: {
    to: string | string[];
    subject: string;
    text: string;
    html?: string;
  }): Promise<boolean> {
    if (!this.isConfigured()) {
      this.logger.debug(`Email skipped (SMTP not configured): ${params.subject}`);
      return false;
    }

    const host = this.config.get<string>('SMTP_HOST')!.trim();
    const port = Number(this.config.get<string>('SMTP_PORT') ?? 587);
    const secure = (this.config.get<string>('SMTP_SECURE') ?? 'false') === 'true';
    const user = this.config.get<string>('SMTP_USER')?.trim();
    const pass = this.config.get<string>('SMTP_PASS')?.trim();
    const from = this.config.get<string>('SMTP_FROM')!.trim();

    const transport = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: user && pass ? { user, pass } : undefined,
    });

    const recipients = Array.isArray(params.to) ? params.to.join(', ') : params.to;
    try {
      await transport.sendMail({
        from,
        to: recipients,
        subject: params.subject,
        text: params.text,
        html: params.html ?? params.text.replace(/\n/g, '<br>'),
      });
      this.logger.log(`Email sent: ${params.subject} → ${recipients}`);
      return true;
    } catch (err) {
      this.logger.error(`Email failed: ${params.subject}`, err);
      return false;
    }
  }
}
