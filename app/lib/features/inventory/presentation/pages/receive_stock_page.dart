import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/app_text_field.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/utils/medicine_barcode_lookup.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../medicine/data/medicine_repository.dart';
import '../../../medicine/domain/entities/medicine.dart';
import '../../data/stock_repository.dart';
import '../providers/stock_provider.dart';

final _branchesForReceiveProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final all = filterActiveBranches(
    await ref.watch(adminRepositoryProvider).listBranches(),
  );
  if (user.isTenantWideStock) return all;
  final loginBranch = user.branchId;
  if (loginBranch == null || loginBranch.isEmpty) return [];
  return all.where((b) => b['id']?.toString() == loginBranch).toList();
});

class ReceiveStockPage extends ConsumerStatefulWidget {
  const ReceiveStockPage({super.key, this.initialBranchId});

  final String? initialBranchId;

  @override
  ConsumerState<ReceiveStockPage> createState() => _ReceiveStockPageState();
}

class _ReceiveStockPageState extends ConsumerState<ReceiveStockPage> {
  final _searchController = TextEditingController();
  final _batchController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  Medicine? _selectedMedicine;
  String? _branchId;
  DateTime? _expiredDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _branchId = widget.initialBranchId;
    final user = ref.read(authProvider).user;
    if (_branchId == null && user != null && !user.isTenantWideStock) {
      _branchId = user.branchId;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _batchController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
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

  Future<void> _submit() async {
    if (_selectedMedicine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih obat terlebih dahulu'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final qty = int.tryParse(_qtyController.text);
    if (qty == null || qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Qty masuk minimal 1'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_branchId == null || _branchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih cabang'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(stockRepositoryProvider).receiveStock(
            medicineId: _selectedMedicine!.id,
            quantity: qty,
            branchId: _branchId,
            batchNumber: _batchController.text.trim().isEmpty
                ? null
                : _batchController.text.trim(),
            expiredDate: _formatDate(_expiredDate),
            notes: _notesController.text.trim().isEmpty
                ? 'Penerimaan stok'
                : _notesController.text.trim(),
          );
      ref.invalidate(stockListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stok berhasil diterima'),
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
    final branchesAsync = ref.watch(_branchesForReceiveProvider);
    final user = ref.watch(authProvider).user;
    final needsBranchPicker = user?.isTenantWideManager == true;

    return AppScaffold(
      title: 'Terima Stok',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarcodeSearchField(
              controller: _searchController,
              labelText: 'Cari obat / barcode',
              onSubmitted: (v) async {
                if (v.trim().isEmpty) return;
                final meds = await ref
                    .read(medicineRepositoryProvider)
                    .getMedicines(search: v.trim());
                if (!mounted) return;
                if (meds.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Obat tidak ditemukan')),
                  );
                  return;
                }
                setState(() {
                  _selectedMedicine = meds.first;
                  _searchController.text = meds.first.name;
                });
              },
              onBarcode: (barcode) async {
                final med = await findMedicineByBarcodeWithFeedback(
                  context,
                  ref,
                  barcode,
                );
                if (med != null && mounted) {
                  setState(() {
                    _selectedMedicine = med;
                    _searchController.text = med.name;
                  });
                }
              },
            ),
            if (_selectedMedicine != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Card(
                color: AppColors.primary.withValues(alpha: 0.06),
                child: ListTile(
                  title: Text(
                    _selectedMedicine!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _selectedMedicine!.barcode ?? _selectedMedicine!.sku ?? '-',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _selectedMedicine = null;
                      _searchController.clear();
                    }),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (needsBranchPicker)
              branchesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, unused) => const SizedBox.shrink(),
                data: (branches) {
                  if (branches.isEmpty) {
                    return const Text(
                      'Tidak ada cabang. Tambahkan cabang di Admin.',
                      style: TextStyle(color: AppColors.danger),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _branchId,
                    decoration: const InputDecoration(labelText: 'Cabang'),
                    items: branches
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b['id']?.toString(),
                            child: Text(b['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _branchId = v),
                    validator: (v) => v == null ? 'Wajib pilih cabang' : null,
                  );
                },
              )
            else if (user?.branchName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Cabang: ${user!.branchName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _batchController,
              label: 'No. Batch (opsional)',
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
            if (_expiredDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _expiredDate = null),
                  child: const Text('Hapus tanggal'),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _qtyController,
              label: 'Qty masuk',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _notesController,
              label: 'Catatan (opsional)',
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              label: 'Simpan penerimaan stok',
              button: true,
              child: AppButton(
                label: 'Simpan Penerimaan',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
