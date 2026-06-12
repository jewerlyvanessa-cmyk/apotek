import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/app_text_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/medicine_repository.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../../../core/constants/drug_classification.dart';
import '../../domain/entities/medicine.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../providers/medicine_list_query.dart';
import '../providers/medicine_provider.dart';
import '../widgets/catalog_form_dialogs.dart';

class MedicineFormPage extends ConsumerStatefulWidget {
  const MedicineFormPage({super.key, this.medicineId});

  final String? medicineId;

  bool get isEdit => medicineId != null;

  @override
  ConsumerState<MedicineFormPage> createState() => _MedicineFormPageState();
}

class _MedicineFormPageState extends ConsumerState<MedicineFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _compositionController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _skuController = TextEditingController();
  String _unit = 'STRIP';
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _minStockController = TextEditingController(text: '0');
  final _batchController = TextEditingController();
  final _initialQtyController = TextEditingController();

  String? _categoryId;
  String? _branchIdForStock;
  DateTime? _expiredDate;
  String? _supplierId;
  String? _productTypeId;
  DrugClassification? _drugClassification;
  bool _isLoading = false;
  String? _loadedMedicineId;
  XFile? _pickedImage;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _compositionController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _minStockController.dispose();
    _batchController.dispose();
    _initialQtyController.dispose();
    super.dispose();
  }

  String? _formatDate(DateTime? d) {
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickExpiredDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiredDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: 'Tanggal kadaluarsa',
    );
    if (picked != null && mounted) {
      setState(() => _expiredDate = picked);
    }
  }

  @override
  void didUpdateWidget(MedicineFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.medicineId != widget.medicineId) {
      _loadedMedicineId = null;
    }
  }

  void _applyMedicine(Medicine m) {
    _nameController.text = m.name;
    _compositionController.text = m.composition ?? '';
    _barcodeController.text = m.barcode ?? '';
    _skuController.text = m.sku ?? '';
    _unit = m.unit;
    _buyPriceController.text = m.buyPrice.round().toString();
    _sellPriceController.text = m.sellPrice.round().toString();
    _minStockController.text = m.minStock.toString();
    _categoryId = m.categoryId;
    _supplierId = m.supplierId;
    _productTypeId = m.productTypeId;
    _drugClassification = m.drugClassification ??
        (m.requiresPrescription ? DrugClassification.prescription : null);
    _loadedMedicineId = m.id;
  }

  void _setDefaultProductType(List<ProductTypeDef> types) {
    if (widget.isEdit || _productTypeId != null) return;
    final active = types.where((t) => t.isActive).toList();
    if (active.isEmpty) return;
    setState(() => _productTypeId = active.first.id);
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (file != null) setState(() => _pickedImage = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final initialQty = int.tryParse(_initialQtyController.text.trim()) ?? 0;
    final user = ref.read(authProvider).user;
    if (!widget.isEdit && initialQty > 0) {
      if (_batchController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No. batch wajib jika ada stok awal'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (user?.isTenantWideManager == true && _branchIdForStock == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih cabang untuk stok awal'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    final repo = ref.read(medicineRepositoryProvider);

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'composition': _compositionController.text.trim().isEmpty
          ? null
          : _compositionController.text.trim(),
      'barcode': _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      'sku': _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      'unit': _unit.trim(),
      'buy_price': int.parse(_buyPriceController.text),
      'sell_price': int.parse(_sellPriceController.text),
      'min_stock': int.tryParse(_minStockController.text) ?? 0,
      if (_productTypeId != null) 'product_type_id': _productTypeId,
      'drug_classification': _drugClassification?.apiValue,
      if (_categoryId != null) 'category_id': _categoryId,
      if (_supplierId != null) 'supplier_id': _supplierId,
    };

    try {
      Medicine? saved;
      if (widget.isEdit) {
        saved = await repo.updateMedicine(widget.medicineId!, payload);
      } else {
        final initialQty = int.tryParse(_initialQtyController.text.trim()) ?? 0;
        if (_batchController.text.trim().isNotEmpty) {
          final batch = <String, dynamic>{
            'batch_number': _batchController.text.trim(),
          };
          final exp = _formatDate(_expiredDate);
          if (exp != null) batch['expired_date'] = exp;
          if (initialQty > 0) batch['initial_quantity'] = initialQty;
          payload['batch'] = batch;
        }
        if (initialQty > 0 && _branchIdForStock != null) {
          payload['branch_id'] = _branchIdForStock;
        }
        saved = await repo.createMedicine(payload);
      }

      if (_pickedImage != null) {
        await repo.uploadImage(medicineId: saved.id, file: _pickedImage!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit ? 'Obat diperbarui' : 'Obat ditambahkan',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
        Future.microtask(() {
          ref.invalidate(medicineListProvider(const MedicineListQuery()));
          ref.invalidate(stockListProvider);
        });
      }
    } catch (e) {
      if (mounted) {
        final message = e is DioException && e.response?.statusCode == 403
            ? 'Tidak punya izin mengelola katalog. Gunakan akun Owner, Manajer, atau Gudang.'
            : friendlyErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final unitsAsync = ref.watch(unitsProvider);
    final productTypesAsync = ref.watch(productTypesProvider);

    productTypesAsync.whenData(_setDefaultProductType);

    if (widget.isEdit) {
      final medicineId = widget.medicineId!;
      final detailAsync = ref.watch(medicineDetailProvider(medicineId));

      return detailAsync.when(
        loading: () => const AppScaffold(
          title: 'Edit Produk',
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppScaffold(
          title: 'Edit Produk',
          body: Center(child: Text('$e')),
        ),
        data: (medicine) {
          if (_loadedMedicineId != medicine.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _loadedMedicineId == medicine.id) return;
              setState(() => _applyMedicine(medicine));
            });
            return const AppScaffold(
              title: 'Edit Produk',
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildForm(
            categoriesAsync,
            suppliersAsync,
            unitsAsync,
            productTypesAsync,
          );
        },
      );
    }

    return _buildForm(
      categoriesAsync,
      suppliersAsync,
      unitsAsync,
      productTypesAsync,
    );
  }

  Widget _buildForm(
    AsyncValue<List<MedicineCategory>> categoriesAsync,
    AsyncValue<List<Supplier>> suppliersAsync,
    AsyncValue<List<MedicineUnit>> unitsAsync,
    AsyncValue<List<ProductTypeDef>> productTypesAsync,
  ) {
    final user = ref.watch(authProvider).user;
    final canManageCatalog = user?.canManageCatalog == true;
    final needsBranchForStock =
        !widget.isEdit && (user?.isTenantWideManager == true);
    final selectedTypeAllowsRx = productTypesAsync.maybeWhen(
      data: (types) {
        final t = types.where((x) => x.id == _productTypeId).firstOrNull;
        return t?.allowsPrescription ?? false;
      },
      orElse: () => false,
    );

    return AppScaffold(
      title: widget.isEdit ? 'Edit Produk' : 'Tambah Produk',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: KeyedSubtree(
            key: ValueKey(
              'medicine-fields-${_loadedMedicineId ?? 'new'}-$_productTypeId',
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _pickedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _pickedImage!.path,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, unused, imageError) => const Icon(Icons.image_outlined),
                                ),
                              )
                            : const Icon(Icons.image_outlined, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Gambar produk',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Upload gambar (jpg/png/webp, max 2MB)',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _pickImage,
                        icon: const Icon(Icons.upload),
                        label: const Text('Pilih'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              productTypesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => const SizedBox.shrink(),
                data: (types) {
                  final active = types.where((t) => t.isActive).toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _productTypeId,
                    decoration: const InputDecoration(labelText: 'Tipe produk'),
                    items: active
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Row(
                              children: [
                                Icon(t.legacyType.icon, size: 20),
                                const SizedBox(width: 8),
                                Text(t.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final type =
                          active.where((t) => t.id == v).firstOrNull;
                      setState(() {
                        _productTypeId = v;
                        if (type != null && !type.allowsPrescription) {
                          _drugClassification = null;
                        }
                        if (type != null &&
                            type.code != 'DRUG' &&
                            _unit == 'STRIP') {
                          _unit = 'PCS';
                        }
                      });
                    },
                    validator: (v) =>
                        v == null ? 'Pilih tipe produk' : null,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _nameController,
                label: 'Nama produk',
                validator: (v) => v == null || v.length < 2
                    ? 'Nama minimal 2 karakter'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _compositionController,
                label: 'Kandungan / Sediaan',
                hint: 'Contoh: Paracetamol 500 mg · Tablet',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _barcodeController, label: 'Barcode'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _skuController, label: 'SKU'),
              const SizedBox(height: AppSpacing.md),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => const SizedBox.shrink(),
                data: (cats) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Kategori'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Pilih —'),
                          ),
                          ...cats.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                    if (canManageCatalog)
                      IconButton(
                        tooltip: 'Tambah kategori',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          final id = await showCategoryFormDialog(context, ref);
                          if (id != null && mounted) {
                            setState(() => _categoryId = id);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              suppliersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
                data: (sups) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _supplierId,
                        decoration: const InputDecoration(labelText: 'Supplier'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Pilih —'),
                          ),
                          ...sups.map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _supplierId = v),
                      ),
                    ),
                    if (canManageCatalog)
                      IconButton(
                        tooltip: 'Tambah supplier',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          final id = await showSupplierFormDialog(context, ref);
                          if (id != null && mounted) {
                            setState(() => _supplierId = id);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              unitsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => const SizedBox.shrink(),
                data: (units) {
                  final unitNames = units.map((u) => u.name).toList();
                  if (!unitNames.contains(_unit)) {
                    unitNames.add(_unit);
                    unitNames.sort();
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _unit,
                          decoration: const InputDecoration(labelText: 'Satuan'),
                          items: unitNames
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _unit = v);
                          },
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Pilih satuan' : null,
                        ),
                      ),
                      if (canManageCatalog)
                        IconButton(
                          tooltip: 'Tambah satuan',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () async {
                            final name =
                                await showUnitFormDialog(context, ref);
                            if (name != null && mounted) {
                              setState(() => _unit = name);
                            }
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _buyPriceController,
                      label: 'Harga Beli',
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v ?? '') == null ? 'Wajib angka' : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _sellPriceController,
                      label: 'Harga Jual',
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v ?? '') == null ? 'Wajib angka' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _minStockController,
                label: 'Stok Minimum',
                keyboardType: TextInputType.number,
              ),
              if (!widget.isEdit) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Batch & stok awal (opsional)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _batchController,
                  label: 'No. Batch',
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal kadaluarsa'),
                  subtitle: Text(
                    _expiredDate == null
                        ? 'Belum dipilih'
                        : _formatDate(_expiredDate)!,
                  ),
                  trailing: TextButton(
                    onPressed: _isLoading ? null : _pickExpiredDate,
                    child: const Text('Pilih'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _initialQtyController,
                  label: 'Stok awal (qty)',
                  keyboardType: TextInputType.number,
                ),
                if (needsBranchForStock) ...[
                  const SizedBox(height: AppSpacing.md),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: ref.read(adminRepositoryProvider).listBranches(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final branches = snap.data!;
                      return DropdownButtonFormField<String>(
                        initialValue: _branchIdForStock,
                        decoration: const InputDecoration(
                          labelText: 'Cabang untuk stok awal',
                        ),
                        items: branches
                            .map(
                              (b) => DropdownMenuItem<String>(
                                value: b['id']?.toString(),
                                child: Text(b['name']?.toString() ?? '-'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _branchIdForStock = v),
                      );
                    },
                  ),
                ],
              ],
              if (selectedTypeAllowsRx) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<DrugClassification?>(
                  initialValue: _drugClassification,
                  decoration: const InputDecoration(
                    labelText: 'Golongan obat',
                    helperText: 'Merah · Biru · Hijau · Hitam (narkotika)',
                  ),
                  items: [
                    const DropdownMenuItem<DrugClassification?>(
                      value: null,
                      child: Text('— Pilih —'),
                    ),
                    ...DrugClassification.catalogOptions.map(
                      (c) => DropdownMenuItem<DrugClassification?>(
                        value: c,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: c.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(c.label),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _drugClassification = v),
                  validator: (v) =>
                      selectedTypeAllowsRx && v == null
                          ? 'Pilih golongan obat'
                          : null,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: widget.isEdit ? 'Simpan Perubahan' : 'Simpan Produk',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
