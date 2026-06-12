import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { resolveProductTypeId } from '../../common/utils/product-type-defaults.util';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { CreateMedicineDto } from './dto/create-medicine.dto';
import { MedicineQueryDto } from './dto/medicine-query.dto';
import { UpdateMedicineDto } from './dto/update-medicine.dto';
import { resolveDrugClassification } from '../../common/constants/drug-classification';
import {
  assertDrugClassificationForType,
  assertPrescriptionForType,
} from './medicine-product.util';
import {
  findOrCreateStockRow,
  loadBranchForStock,
  resolveInboundLocationId,
} from '../../common/utils/stock-location.util';

const productTypeSelect = {
  id: true,
  code: true,
  name: true,
  allowsPrescription: true,
} as const;

const medicineInclude = {
  category: { select: { id: true, name: true } },
  supplier: { select: { id: true, name: true } },
  productType: { select: productTypeSelect },
  batches: {
    orderBy: { createdAt: 'desc' as const },
    take: 5,
  },
};

@Injectable()
export class MedicinesService {
  constructor(private prisma: PrismaService) {}

  private async resolveType(
    tenantId: string,
    input?: { product_type_id?: string; product_type?: string },
  ) {
    try {
      return await resolveProductTypeId(this.prisma, tenantId, input);
    } catch (e) {
      throw new BadRequestException(
        e instanceof Error ? e.message : 'Tipe produk tidak valid',
      );
    }
  }

  private async productTypeFilter(
    tenantId: string,
    query: MedicineQueryDto,
  ): Promise<Prisma.MedicineWhereInput | null> {
    if (query.product_type_id) {
      return { productTypeId: query.product_type_id };
    }
    if (query.product_type) {
      const type = await this.resolveType(tenantId, {
        product_type: query.product_type,
      });
      return { productTypeId: type.id };
    }
    return null;
  }

  async findAll(tenantId: string, query: MedicineQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const typeFilter = await this.productTypeFilter(tenantId, query);

    const where: Prisma.MedicineWhereInput = {
      tenantId,
      isActive: true,
      ...(query.category_id ? { categoryId: query.category_id } : {}),
      ...(typeFilter ?? {}),
      ...(query.barcode ? { barcode: query.barcode } : {}),
      ...(query.search
        ? {
            OR: [
              { name: { contains: query.search, mode: 'insensitive' } },
              { composition: { contains: query.search, mode: 'insensitive' } },
              { barcode: { contains: query.search, mode: 'insensitive' } },
              { sku: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.medicine.findMany({
        where,
        skip,
        take: limit,
        orderBy: { name: 'asc' },
        include: medicineInclude,
      }),
      this.prisma.medicine.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(tenantId: string, id: string) {
    const item = await this.prisma.medicine.findFirst({
      where: { id, tenantId },
      include: {
        ...medicineInclude,
        batches: { orderBy: { createdAt: 'desc' } },
      },
    });
    if (!item) throw new NotFoundException('Medicine not found');
    return item;
  }

  async create(tenantId: string, user: JwtPayloadUser, dto: CreateMedicineDto) {
    const { batch, branch_id: branchIdFromDto, ...data } = dto;
    const type = await this.resolveType(tenantId, data);
    const { drugClassification, requiresPrescription } = resolveDrugClassification(
      {
        drug_classification: data.drug_classification,
        requires_prescription: data.requires_prescription,
      },
    );
    assertDrugClassificationForType(type.allowsPrescription, drugClassification);
    assertPrescriptionForType(type.allowsPrescription, requiresPrescription);

    return this.prisma.$transaction(async (tx) => {
      const medicine = await tx.medicine.create({
        data: {
          tenantId,
          name: data.name,
          composition: data.composition?.trim() || null,
          barcode: data.barcode,
          sku: data.sku,
          categoryId: data.category_id,
          supplierId: data.supplier_id,
          unit: data.unit ?? (type.code === 'DRUG' ? 'STRIP' : 'PCS'),
          buyPrice: data.buy_price,
          sellPrice: data.sell_price,
          minStock: data.min_stock ?? 0,
          productTypeId: type.id,
          drugClassification,
          requiresPrescription,
        },
        include: medicineInclude,
      });

      let batchId: string | null = null;
      if (batch) {
        const createdBatch = await tx.medicineBatch.create({
          data: {
            medicineId: medicine.id,
            batchNumber: batch.batch_number,
            expiredDate: batch.expired_date
              ? new Date(batch.expired_date)
              : null,
            buyPrice: batch.buy_price ?? data.buy_price,
            sellPrice: batch.sell_price ?? data.sell_price,
          },
        });
        batchId = createdBatch.id;

        const initialQty = batch.initial_quantity ?? 0;
        if (initialQty > 0) {
          const branchId = branchIdFromDto ?? user.branchId ?? undefined;
          if (!branchId) {
            throw new BadRequestException(
              'branch_id wajib untuk stok awal (pilih cabang)',
            );
          }
          const branch = await loadBranchForStock(tx, tenantId, branchId);
          const locationId = await resolveInboundLocationId(tx, branch);
          await findOrCreateStockRow(tx, {
            tenantId,
            branchId,
            locationId,
            medicineId: medicine.id,
            batchId,
            initialQuantity: initialQty,
          });
          await tx.stockMovement.create({
            data: {
              tenantId,
              branchId,
              medicineId: medicine.id,
              batchId,
              movementType: 'PURCHASE',
              quantity: initialQty,
              referenceType: 'MEDICINE',
              referenceId: medicine.id,
              notes: 'Stok awal saat tambah obat',
              createdById: user.sub,
            },
          });
        }
      }

      return tx.medicine.findFirst({
        where: { id: medicine.id },
        include: medicineInclude,
      });
    });
  }

  async update(tenantId: string, id: string, dto: UpdateMedicineDto) {
    const existing = await this.findOne(tenantId, id);

    const type =
      dto.product_type_id !== undefined || dto.product_type !== undefined
        ? await this.resolveType(tenantId, dto)
        : {
            id: existing.productTypeId,
            code: existing.productType.code,
            allowsPrescription: existing.productType.allowsPrescription,
          };

    const { drugClassification, requiresPrescription } = resolveDrugClassification(
      {
        drug_classification: dto.drug_classification,
        requires_prescription: dto.requires_prescription,
        existingClassification: existing.drugClassification,
        existingRequiresPrescription: existing.requiresPrescription,
      },
    );

    assertDrugClassificationForType(type.allowsPrescription, drugClassification);
    assertPrescriptionForType(type.allowsPrescription, requiresPrescription);

    return this.prisma.medicine.update({
      where: { id },
      data: {
        name: dto.name,
        composition:
          dto.composition !== undefined
            ? dto.composition?.trim() || null
            : undefined,
        barcode: dto.barcode,
        sku: dto.sku,
        categoryId: dto.category_id,
        supplierId: dto.supplier_id,
        unit: dto.unit,
        buyPrice: dto.buy_price,
        sellPrice: dto.sell_price,
        minStock: dto.min_stock,
        productTypeId: type.id,
        drugClassification,
        requiresPrescription,
        isActive: dto.is_active,
      },
      include: medicineInclude,
    });
  }

  async remove(tenantId: string, id: string) {
    await this.findOne(tenantId, id);
    return this.prisma.medicine.update({
      where: { id },
      data: { isActive: false },
    });
  }

  async setImageUrl(tenantId: string, id: string, imageUrl: string) {
    await this.findOne(tenantId, id);
    return this.prisma.medicine.update({
      where: { id },
      data: { imageUrl },
      include: medicineInclude,
    });
  }
}
