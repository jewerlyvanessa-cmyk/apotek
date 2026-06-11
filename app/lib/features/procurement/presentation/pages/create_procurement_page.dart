import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../medicine/domain/entities/medicine.dart';
import '../../../medicine/presentation/providers/medicine_list_query.dart';
import '../../../medicine/presentation/providers/medicine_provider.dart';

class _ProcurementLine {
  _ProcurementLine({required this.medicine});

  final Medicine medicine;
  int quantity = 1;
  String batchNumber = '';
  DateTime? expiredDate;
  String buyPrice = '';
  String sellPrice = '';
}

class CreateProcurementPage extends ConsumerStatefulWidget {
  const CreateProcurementPage({super.key});

  @override
  ConsumerState<CreateProcurementPage> createState() =>
      _CreateProcurementPageState();
}

class _CreateProcurementPageState extends ConsumerState<CreateProcurementPage> {
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _supplierId;
  final List<_ProcurementLine> _lines = [];
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addMedicine(Medicine m) {
    final idx = _lines.indexWhere((l) => l.medicine.id == m.id);
    setState(() {
      if (idx >= 0) {
        _lines[idx].quantity += 1;
      } else {
        _lines.add(_ProcurementLine(medicine: m));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${m.name} ditambahkan'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _save() async {
    if (_lines.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post(
        '/procurements',
        data: {
          if (_supplierId != null) 'supplier_id': _supplierId,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
          'items': _lines
              .map((l) {
                final item = <String, dynamic>{
                  'medicine_id': l.medicine.id,
                  'quantity': l.quantity,
                };
                final batch = l.batchNumber.trim();
                if (batch.isNotEmpty) item['batch_number'] = batch;
                if (l.expiredDate != null) {
                  final d = l.expiredDate!;
                  item['expired_date'] =
                      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                }
                final buy = double.tryParse(l.buyPrice.replaceAll('.', ''));
                if (buy != null && buy >= 0) item['buy_price'] = buy;
                final sell = double.tryParse(l.sellPrice.replaceAll('.', ''));
                if (sell != null && sell >= 0) item['sell_price'] = sell;
                return item;
              })
              .toList(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft pengadaan berhasil dibuat'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg ?? e.message ?? '$e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final medsAsync = ref.watch(
      medicineListProvider(
        MedicineListQuery(
          search: _searchQuery.isEmpty ? null : _searchQuery,
        ),
      ),
    );

    return AppScaffold(
      title: 'Pengadaan Baru',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                suppliersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (suppliers) {
                    return DropdownButtonFormField<String?>(
                      initialValue: _supplierId,
                      decoration: const InputDecoration(
                        labelText: 'Supplier (opsional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— Tanpa supplier —'),
                        ),
                        ...suppliers.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _supplierId = v),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Cari & tambah obat',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                BarcodeSearchField(
                  controller: _searchController,
                  labelText: 'Nama / barcode obat',
                  onSubmitted: (v) => setState(() => _searchQuery = v.trim()),
                  onBarcode: (code) async {
                    setState(() => _searchQuery = code);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                medsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: AsyncLoadingView(),
                  ),
                  error: (e, _) => AsyncErrorView.fromError(e),
                  data: (meds) {
                    if (_searchQuery.isEmpty) {
                      return const Text(
                        'Ketik nama obat atau scan barcode untuk mencari.',
                        style: TextStyle(color: AppColors.textSecondary),
                      );
                    }
                    if (meds.isEmpty) {
                      return const Text('Obat tidak ditemukan');
                    }
                    return Column(
                      children: meds.take(15).map((m) {
                        final inCart =
                            _lines.any((l) => l.medicine.id == m.id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: ListTile(
                            dense: true,
                            title: Text(m.name),
                            subtitle: Text(
                              [m.unit, m.sku]
                                  .where((s) => s != null && s.isNotEmpty)
                                  .join(' · '),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                inCart ? Icons.check_circle : Icons.add_circle_outline,
                                color: AppColors.primary,
                              ),
                              onPressed: () => _addMedicine(m),
                            ),
                            onTap: () => _addMedicine(m),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Item pengadaan (${_lines.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    if (_lines.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _lines.clear()),
                        child: const Text('Kosongkan'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_lines.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Belum ada item. Cari obat di atas lalu tap + untuk menambah.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ..._lines.map((line) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.medicine.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        line.medicine.unit,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.danger,
                                  ),
                                  onPressed: () =>
                                      setState(() => _lines.remove(line)),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                const Text('Qty'),
                                const SizedBox(width: AppSpacing.sm),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      if (line.quantity > 1) line.quantity -= 1;
                                    });
                                  },
                                ),
                                SizedBox(
                                  width: 56,
                                  child: TextFormField(
                                    key: ValueKey('qty-${line.medicine.id}'),
                                    initialValue: '${line.quantity}',
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                    onChanged: (v) {
                                      final q = int.tryParse(v);
                                      if (q != null && q > 0) line.quantity = q;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () =>
                                      setState(() => line.quantity += 1),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'No. batch (opsional)',
                                isDense: true,
                              ),
                              onChanged: (v) => line.batchNumber = v,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: line.expiredDate ??
                                            DateTime.now().add(
                                              const Duration(days: 365),
                                            ),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 3650),
                                        ),
                                      );
                                      if (picked != null) {
                                        setState(() => line.expiredDate = picked);
                                      }
                                    },
                                    child: Text(
                                      line.expiredDate == null
                                          ? 'Tgl expired'
                                          : '${line.expiredDate!.day}/${line.expiredDate!.month}/${line.expiredDate!.year}',
                                    ),
                                  ),
                                ),
                                if (line.expiredDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () =>
                                        setState(() => line.expiredDate = null),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Harga beli',
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => line.buyPrice = v,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Harga jual',
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => line.sellPrice = v,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppButton(
                  label: 'Simpan Draft (${_lines.length} item)',
                  isLoading: _saving,
                  onPressed: _lines.isEmpty || _saving ? null : _save,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
