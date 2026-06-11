import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type QrisChargeRequest = {
  reference: string;
  amount: number;
  orderId: string;
  tenantId: string;
};

export type QrisChargeResult = {
  reference_number: string;
  qr_string: string;
  provider: string;
};

@Injectable()
export class QrisProviderService {
  private readonly logger = new Logger(QrisProviderService.name);

  constructor(private config: ConfigService) {}

  async createCharge(req: QrisChargeRequest): Promise<QrisChargeResult> {
    const provider = (this.config.get<string>('QRIS_PROVIDER') ?? 'mock')
      .trim()
      .toLowerCase();

    if (provider === 'mock') {
      return {
        provider: 'mock',
        reference_number: req.reference,
        qr_string: `qris://mock/${req.reference}?amount=${req.amount}`,
      };
    }

    if (provider === 'xendit') {
      return this.createXenditCharge(req);
    }

    if (provider === 'midtrans') {
      return this.createMidtransCharge(req);
    }

    const apiUrl = this.config.get<string>('QRIS_API_URL')?.trim();
    if (provider === 'http' || provider === 'rest' || apiUrl) {
      return this.createHttpCharge(req, apiUrl);
    }

    const baseUrl = this.config.get<string>('QRIS_BASE_URL')?.trim();
    if (baseUrl) {
      return {
        provider,
        reference_number: req.reference,
        qr_string: `${baseUrl.replace(/\/$/, '')}/${req.reference}?amount=${req.amount}`,
      };
    }

    return {
      provider,
      reference_number: req.reference,
      qr_string: `qris://${provider}/${req.reference}?amount=${req.amount}`,
    };
  }

  private async createXenditCharge(
    req: QrisChargeRequest,
  ): Promise<QrisChargeResult> {
    const secret =
      this.config.get<string>('QRIS_XENDIT_SECRET_KEY')?.trim() ??
      this.config.get<string>('QRIS_API_KEY')?.trim();
    if (!secret) {
      throw new Error('QRIS_XENDIT_SECRET_KEY atau QRIS_API_KEY wajib untuk Xendit');
    }

    const url =
      this.config.get<string>('QRIS_API_URL')?.trim() ??
      'https://api.xendit.co/qr_codes';
    const callbackUrl = this.config.get<string>('QRIS_CALLBACK_URL')?.trim();

    const body: Record<string, unknown> = {
      reference_id: req.reference,
      type: 'DYNAMIC',
      currency: 'IDR',
      amount: req.amount,
      metadata: {
        order_id: req.orderId,
        tenant_id: req.tenantId,
      },
    };
    if (callbackUrl) body.callback_url = callbackUrl;

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${Buffer.from(`${secret}:`).toString('base64')}`,
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      this.logger.error(`Xendit QRIS ${res.status}: ${text}`);
      throw new Error(`Xendit QRIS gagal (${res.status})`);
    }

    const data = (await res.json()) as Record<string, unknown>;
    const qrString =
      (data.qr_string as string) ??
      (data.qrString as string) ??
      ((data.channel_properties as Record<string, unknown> | undefined)
        ?.qr_string as string);
    if (!qrString) {
      throw new Error('Xendit tidak mengembalikan qr_string');
    }

    return {
      provider: 'xendit',
      reference_number:
        (data.reference_id as string) ?? (data.id as string) ?? req.reference,
      qr_string: qrString,
    };
  }

  private async createMidtransCharge(
    req: QrisChargeRequest,
  ): Promise<QrisChargeResult> {
    const serverKey =
      this.config.get<string>('QRIS_MIDTRANS_SERVER_KEY')?.trim() ??
      this.config.get<string>('QRIS_API_KEY')?.trim();
    if (!serverKey) {
      throw new Error(
        'QRIS_MIDTRANS_SERVER_KEY atau QRIS_API_KEY wajib untuk Midtrans',
      );
    }

    const sandbox =
      this.config.get<string>('QRIS_MIDTRANS_SANDBOX')?.trim() !== 'false';
    const url =
      this.config.get<string>('QRIS_API_URL')?.trim() ??
      (sandbox
        ? 'https://api.sandbox.midtrans.com/v2/charge'
        : 'https://api.midtrans.com/v2/charge');

    const body = {
      payment_type: 'qris',
      transaction_details: {
        order_id: req.reference,
        gross_amount: req.amount,
      },
      qris: {
        acquirer: this.config.get<string>('QRIS_MIDTRANS_ACQUIRER') ?? 'gopay',
      },
      custom_field1: req.orderId,
      custom_field2: req.tenantId,
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Basic ${Buffer.from(`${serverKey}:`).toString('base64')}`,
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      this.logger.error(`Midtrans QRIS ${res.status}: ${text}`);
      throw new Error(`Midtrans QRIS gagal (${res.status})`);
    }

    const data = (await res.json()) as Record<string, unknown>;
    const actions = data.actions as Array<Record<string, unknown>> | undefined;
    const qrAction = actions?.find((a) => a.name === 'generate-qr-code');
    const qrString =
      (qrAction?.url as string) ??
      (data.qr_string as string) ??
      ((data.acquirer_info as Record<string, unknown> | undefined)?.qr_string as string);

    if (!qrString) {
      throw new Error('Midtrans tidak mengembalikan QR (actions/url)');
    }

    return {
      provider: 'midtrans',
      reference_number:
        (data.transaction_id as string) ??
        ((data.transaction_details as Record<string, unknown> | undefined)
          ?.order_id as string) ??
        req.reference,
      qr_string: qrString,
    };
  }

  private async createHttpCharge(
    req: QrisChargeRequest,
    apiUrl?: string,
  ): Promise<QrisChargeResult> {
    const url =
      apiUrl ?? this.config.get<string>('QRIS_BASE_URL')?.trim() ?? '';
    if (!url) {
      throw new Error('QRIS_API_URL atau QRIS_BASE_URL belum dikonfigurasi');
    }

    const apiKey = this.config.get<string>('QRIS_API_KEY')?.trim();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    };
    if (apiKey) {
      headers.Authorization = `Bearer ${apiKey}`;
      headers['x-api-key'] = apiKey;
    }

    const body = {
      reference: req.reference,
      reference_number: req.reference,
      amount: req.amount,
      order_id: req.orderId,
      tenant_id: req.tenantId,
    };

    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      this.logger.error(`QRIS provider HTTP ${res.status}: ${text}`);
      throw new Error(`QRIS provider gagal (${res.status})`);
    }

    const data = (await res.json()) as Record<string, unknown>;
    const qrString =
      (data.qr_string as string) ??
      (data.qrString as string) ??
      (data.qr_code as string) ??
      (data.qrCode as string);
    const reference =
      (data.reference_number as string) ??
      (data.referenceNumber as string) ??
      req.reference;

    if (!qrString) {
      throw new Error('QRIS provider tidak mengembalikan qr_string');
    }

    return {
      provider: 'http',
      reference_number: reference,
      qr_string: qrString,
    };
  }
}
