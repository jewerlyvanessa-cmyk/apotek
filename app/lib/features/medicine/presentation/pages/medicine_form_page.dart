import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/app_text_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/medicine_repository.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/entities/medicine.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../providers/medicine_list_query.dart';
import '../providers/medicine_provider.dart';

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
  final _barcodeController = TextEditingController();
  final _skuController = TextEditingController();
  final _unitController = TextEditingController(text: 'STRIP');
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
  bool _requiresPrescription = false;
  bool _isLoading = false;
  bool _initialized = false;
  XFile? _pickedImage;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _unitController.dispose();
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

  void _fillForm(Medicine m) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = m.name;
    _barcodeController.text = m.barcode ?? '';
    _skuController.text = m.sku ?? '';
    _unitController.text = m.unit;
    _buyPriceController.text = m.buyPrice.round().toString();
    _sellPriceController.text = m.sellPrice.round().toString();
    _minStockController.text = m.minStock.toString();
    _categoryId = m.categoryId;
    _supplierId = m.supplierId;
    _productTypeId = m.productTypeId;
    _requiresPrescription = m.requiresPrescription;
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
      'barcode': _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      'sku': _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      'unit': _unitController.text.trim(),
      'buy_price': int.parse(_buyPriceController.text),
      'sell_price': int.parse(_sellPriceController.text),
      'min_stock': int.tryParse(_minStockController.text) ?? 0,
      if (_productTypeId != null) 'product_type_id': _productTypeId,
      'requires_prescription': _requiresPrescription,
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

      ref.invalidate(medicineListProvider(const MedicineListQuery()));
      ref.invalidate(stockListProvider);
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final productTypesAsync = ref.watch(productTypesProvider);

    if (widget.isEdit) {
      final detailAsync = ref.watch(medicineDetailProvider(widget.medicineId!));
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
          _fillForm(medicine);
          return _buildForm(categoriesAsync, suppliersAsync, productTypesAsync);
        },
      );
    }

    return _buildForm(categoriesAsync, suppliersAsync, productTypesAsync);
  }

  Widget _buildForm(
    AsyncValue<List<MedicineCategory>> categoriesAsync,
    AsyncValue<List<Supplier>> suppliersAsync,
    AsyncValue<List<ProductTypeDef>> productTypesAsync,
  ) {
    final user = ref.watch(authProvider).user;
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
                  if (_productTypeId == null && active.isNotEmpty) {
                    _productTypeId = active.first.id;
                  }
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
                          _requiresPrescription = false;
                        }
                        if (type != null &&
                            type.code != 'DRUG' &&
                            _unitController.text == 'STRIP') {
                          _unitController.text = 'PCS';
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
              AppTextField(controller: _barcodeController, label: 'Barcode'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _skuController, label: 'SKU'),
              const SizedBox(height: AppSpacing.md),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => const SizedBox.shrink(),
                data: (cats) => DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('— Pilih —'),
                    ),
                    ...cats.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              suppliersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
                data: (sups) => DropdownButtonFormField<String?>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('— Pilih —'),
                    ),
                    ...sups.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _unitController, label: 'Satuan'),
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
                SwitchListTile(
                  title: const Text('Butuh resep dokter'),
                  subtitle: const Text('Hanya untuk tipe yang mendukung resep'),
                  value: _requiresPrescription,
                  onChanged: (v) => setState(() => _requiresPrescription = v),
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
    );
  }
}
