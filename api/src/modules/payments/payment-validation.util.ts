import { BadRequestException } from '@nestjs/common';
import { PayOrderDto } from './dto/pay-order.dto';
import { PaymentSplitLineDto } from './dto/payment-split-line.dto';

export type PaymentExtras = {
  amountReceived: number | null;
  changeAmount: number | null;
  proofImageUrl: string | null;
};

export type ResolvedPaymentLine = {
  paymentMethod: string;
  amount: number;
  amountReceived: number | null;
  changeAmount: number | null;
  proofImageUrl: string | null;
  referenceNumber?: string;
};

export function resolvePaymentLines(dto: PayOrderDto): ResolvedPaymentLine[] {
  if (dto.splits?.length) {
    return dto.splits.map((line) => {
      const extras = resolveSplitLineExtras(line);
      return {
        paymentMethod: line.payment_method,
        amount: line.amount,
        amountReceived: extras.amountReceived,
        changeAmount: extras.changeAmount,
        proofImageUrl: extras.proofImageUrl,
        referenceNumber: line.reference_number,
      };
    });
  }

  if (!dto.payment_method || dto.amount == null) {
    throw new BadRequestException(
      'payment_method dan amount wajib, atau gunakan splits untuk bayar campuran',
    );
  }

  const extras = resolvePaymentExtras(dto);
  return [
    {
      paymentMethod: dto.payment_method,
      amount: dto.amount,
      amountReceived: extras.amountReceived,
      changeAmount: extras.changeAmount,
      proofImageUrl: extras.proofImageUrl,
      referenceNumber: dto.reference_number,
    },
  ];
}

function resolveSplitLineExtras(line: PaymentSplitLineDto): PaymentExtras {
  const method = line.payment_method;
  if (method === 'CASH') {
    const received = line.amount_received;
    if (received == null || Number.isNaN(received)) {
      throw new BadRequestException(
        'Uang diterima wajib untuk setiap baris pembayaran tunai',
      );
    }
    if (received < line.amount) {
      throw new BadRequestException(
        `Uang diterima (${received}) kurang dari jumlah baris (${line.amount})`,
      );
    }
    return {
      amountReceived: received,
      changeAmount: Math.round((received - line.amount) * 100) / 100,
      proofImageUrl: null,
    };
  }
  if (method === 'QRIS' || method === 'TRANSFER') {
    const proof = line.proof_image_url?.trim();
    if (!proof) {
      throw new BadRequestException(
        `Bukti wajib untuk baris ${method}`,
      );
    }
    return {
      amountReceived: null,
      changeAmount: null,
      proofImageUrl: proof,
    };
  }
  return {
    amountReceived: null,
    changeAmount: null,
    proofImageUrl: line.proof_image_url?.trim() || null,
  };
}

export function resolvePaymentExtras(dto: PayOrderDto): PaymentExtras {
  const method = dto.payment_method;
  if (!method || dto.amount == null) {
    throw new BadRequestException('payment_method dan amount wajib');
  }

  if (method === 'CASH') {
    const received = dto.amount_received;
    if (received == null || Number.isNaN(received)) {
      throw new BadRequestException('Uang diterima wajib diisi untuk pembayaran tunai');
    }
    if (received < dto.amount) {
      throw new BadRequestException(
        `Uang diterima (${received}) kurang dari total tagihan (${dto.amount})`,
      );
    }
    return {
      amountReceived: received,
      changeAmount: Math.round((received - dto.amount) * 100) / 100,
      proofImageUrl: null,
    };
  }

  if (method === 'QRIS' || method === 'TRANSFER') {
    const proof = dto.proof_image_url?.trim();
    if (!proof) {
      throw new BadRequestException(
        `Foto bukti pembayaran wajib untuk ${method === 'QRIS' ? 'QRIS' : 'transfer'}`,
      );
    }
    return {
      amountReceived: null,
      changeAmount: null,
      proofImageUrl: proof,
    };
  }

  return {
    amountReceived: null,
    changeAmount: null,
    proofImageUrl: dto.proof_image_url?.trim() || null,
  };
}
