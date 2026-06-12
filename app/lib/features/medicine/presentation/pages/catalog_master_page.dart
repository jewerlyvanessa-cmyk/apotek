import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/app_text_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../data/catalog_repository.dart';
import '../../domain/entities/catalog_entities.dart';
import '../providers/catalog_provider.dart';
import '../widgets/catalog_form_dialogs.dart';

class CatalogMasterPage extends ConsumerStatefulWidget {
  const CatalogMasterPage({super.key});

  @override
  ConsumerState<CatalogMasterPage> createState() => _CatalogMasterPageState();
}

class _CatalogMasterPageState extends ConsumerState<CatalogMasterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(productTypesProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(unitsProvider);
    ref.invalidate(suppliersProvider);
  }

  Future<void> _confirmDelete({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await onConfirm();
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil dihapus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Master Katalog',
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Tipe Produk'),
              Tab(text: 'Kategori'),
              Tab(text: 'Satuan'),
              Tab(text: 'Supplier'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ProductTypesTab(
                  onRefresh: _refreshAll,
                  onDelete: _confirmDelete,
                ),
                _CategoriesTab(
                  onRefresh: _refreshAll,
                  onDelete: _confirmDelete,
                ),
                _UnitsTab(
                  onRefresh: _refreshAll,
                  onDelete: _confirmDelete,
                ),
                _SuppliersTab(
                  onRefresh: _refreshAll,
                  onDelete: _confirmDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTypesTab extends ConsumerWidget {
  const _ProductTypesTab({
    required this.onRefresh,
    required this.onDelete,
  });

  final VoidCallback onRefresh;
  final Future<void> Function({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) onDelete;

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    ProductTypeDef? existing,
  }) async {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    var allowsRx = existing?.allowsPrescription ?? false;
    final isEdit = existing != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isEdit ? 'Edit Tipe Produk' : 'Tambah Tipe Produk'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeCtrl,
                  enabled: !isEdit,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
                    TextInputFormatter.withFunction((old, neu) {
                      return TextEditingValue(
                        text: neu.text.toUpperCase(),
                        selection: neu.selection,
                      );
                    }),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kode (DRUG, HEALTH, ...)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(controller: nameCtrl, label: 'Nama tampilan'),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Boleh wajib resep'),
                  value: allowsRx,
                  onChanged: (v) => setLocal(() => allowsRx = v),
                ),
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
      ),
    );

    if (saved != true) return;

    final repo = ref.read(catalogRepositoryProvider);
    try {
      if (isEdit) {
        await repo.updateProductType(existing.id, {
          'name': nameCtrl.text.trim(),
          'allows_prescription': allowsRx,
        });
      } else {
        await repo.createProductType({
          'code': codeCtrl.text.trim(),
          'name': nameCtrl.text.trim(),
          'allows_prescription': allowsRx,
        });
      }
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Tipe produk diperbarui' : 'Tipe produk ditambahkan'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(productTypesProvider);

    return typesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: 'Tambah Tipe Produk',
              onPressed: () => _showForm(context, ref),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Belum ada tipe produk'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, unused) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.code}'
                          '${item.allowsPrescription ? ' · Boleh resep' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showForm(
                                context,
                                ref,
                                existing: item,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onDelete(
                                title: 'Hapus tipe produk',
                                message:
                                    'Hapus "${item.name}"? Tidak bisa jika masih dipakai produk.',
                                onConfirm: () => ref
                                    .read(catalogRepositoryProvider)
                                    .deleteProductType(item.id),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({
    required this.onRefresh,
    required this.onDelete,
  });

  final VoidCallback onRefresh;
  final Future<void> Function({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) onDelete;

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    MedicineCategory? existing,
  }) async {
    final id = await showCategoryFormDialog(context, ref, existing: existing);
    if (id != null) onRefresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider);

    return catsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: 'Tambah Kategori',
              onPressed: () => _showForm(context, ref),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Belum ada kategori'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, unused) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showForm(
                                context,
                                ref,
                                existing: item,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onDelete(
                                title: 'Hapus kategori',
                                message:
                                    'Hapus "${item.name}"? Tidak bisa jika masih dipakai produk.',
                                onConfirm: () => ref
                                    .read(catalogRepositoryProvider)
                                    .deleteCategory(item.id),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UnitsTab extends ConsumerWidget {
  const _UnitsTab({
    required this.onRefresh,
    required this.onDelete,
  });

  final VoidCallback onRefresh;
  final Future<void> Function({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) onDelete;

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    MedicineUnit? existing,
  }) async {
    final name = await showUnitFormDialog(context, ref, existing: existing);
    if (name != null) onRefresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);

    return unitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: 'Tambah Satuan',
              onPressed: () => _showForm(context, ref),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Belum ada satuan'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, unused) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showForm(
                                context,
                                ref,
                                existing: item,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onDelete(
                                title: 'Hapus satuan',
                                message:
                                    'Hapus "${item.name}"? Tidak bisa jika masih dipakai produk.',
                                onConfirm: () => ref
                                    .read(catalogRepositoryProvider)
                                    .deleteUnit(item.id),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SuppliersTab extends ConsumerWidget {
  const _SuppliersTab({
    required this.onRefresh,
    required this.onDelete,
  });

  final VoidCallback onRefresh;
  final Future<void> Function({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) onDelete;

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    Supplier? existing,
  }) async {
    final id = await showSupplierFormDialog(context, ref, existing: existing);
    if (id != null) onRefresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return suppliersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: 'Tambah Supplier',
              onPressed: () => _showForm(context, ref),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Belum ada supplier'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, unused) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          [
                            if (item.phone != null && item.phone!.isNotEmpty)
                              item.phone,
                            if (item.email != null && item.email!.isNotEmpty)
                              item.email,
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showForm(
                                context,
                                ref,
                                existing: item,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onDelete(
                                title: 'Hapus supplier',
                                message:
                                    'Hapus "${item.name}"? Tidak bisa jika masih dipakai produk.',
                                onConfirm: () => ref
                                    .read(catalogRepositoryProvider)
                                    .deleteSupplier(item.id),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
