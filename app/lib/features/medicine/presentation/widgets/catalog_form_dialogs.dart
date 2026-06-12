import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_text_field.dart';
import '../../data/catalog_repository.dart';
import '../../domain/entities/catalog_entities.dart';
import '../providers/catalog_provider.dart';

/// Returns id kategori baru/diperbarui, atau null jika dibatalkan/gagal.
Future<String?> showCategoryFormDialog(
  BuildContext context,
  WidgetRef ref, {
  MedicineCategory? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final isEdit = existing != null;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori'),
      content: AppTextField(controller: nameCtrl, label: 'Nama kategori'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(isEdit ? 'Simpan' : 'Tambah'),
        ),
      ],
    ),
  );

  if (saved != true) return null;

  final name = nameCtrl.text.trim();
  if (name.isEmpty) return null;

  final repo = ref.read(catalogRepositoryProvider);
  try {
    final MedicineCategory result;
    if (isEdit) {
      result = await repo.updateCategory(existing.id, name);
    } else {
      result = await repo.createCategory(name);
    }
    ref.invalidate(categoriesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Kategori diperbarui' : 'Kategori ditambahkan'),
          backgroundColor: AppColors.success,
        ),
      );
    }
    return result.id;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return null;
  }
}

/// Returns nama satuan baru/diperbarui, atau null jika dibatalkan/gagal.
Future<String?> showUnitFormDialog(
  BuildContext context,
  WidgetRef ref, {
  MedicineUnit? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final isEdit = existing != null;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Satuan' : 'Tambah Satuan'),
      content: TextFormField(
        controller: nameCtrl,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
          TextInputFormatter.withFunction((old, neu) {
            return TextEditingValue(
              text: neu.text.toUpperCase(),
              selection: neu.selection,
            );
          }),
        ],
        decoration: const InputDecoration(labelText: 'Nama satuan'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(isEdit ? 'Simpan' : 'Tambah'),
        ),
      ],
    ),
  );

  if (saved != true) return null;

  final name = nameCtrl.text.trim().toUpperCase();
  if (name.isEmpty) return null;

  final repo = ref.read(catalogRepositoryProvider);
  try {
    final MedicineUnit result;
    if (isEdit) {
      result = await repo.updateUnit(existing.id, name);
    } else {
      result = await repo.createUnit(name);
    }
    ref.invalidate(unitsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Satuan diperbarui' : 'Satuan ditambahkan'),
          backgroundColor: AppColors.success,
        ),
      );
    }
    return result.name;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return null;
  }
}

/// Returns id supplier baru/diperbarui, atau null jika dibatalkan/gagal.
Future<String?> showSupplierFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Supplier? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final emailCtrl = TextEditingController(text: existing?.email ?? '');
  final addressCtrl = TextEditingController(text: existing?.address ?? '');
  final isEdit = existing != null;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Supplier' : 'Tambah Supplier'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: nameCtrl, label: 'Nama supplier'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(controller: phoneCtrl, label: 'Telepon'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(controller: emailCtrl, label: 'Email'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(controller: addressCtrl, label: 'Alamat'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(isEdit ? 'Simpan' : 'Tambah'),
        ),
      ],
    ),
  );

  if (saved != true) return null;

  final name = nameCtrl.text.trim();
  if (name.isEmpty) return null;

  final repo = ref.read(catalogRepositoryProvider);
  final payload = <String, dynamic>{
    'name': name,
    if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
    if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
    if (addressCtrl.text.trim().isNotEmpty) 'address': addressCtrl.text.trim(),
  };

  try {
    final Supplier result;
    if (isEdit) {
      result = await repo.updateSupplier(existing.id, payload);
    } else {
      result = await repo.createSupplier(payload);
    }
    ref.invalidate(suppliersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Supplier diperbarui' : 'Supplier ditambahkan'),
          backgroundColor: AppColors.success,
        ),
      );
    }
    return result.id;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return null;
  }
}
