import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/utils/medicine_barcode_lookup.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/warehouse_branch_provider.dart';
import '../../../medicine/data/medicine_repository.dart';
import '../../../medicine/domain/entities/medicine.dart';
import '../../data/warehouse_repository.dart';
import '../../domain/entities/opname.dart';

class OpnamePage extends ConsumerStatefulWidget {
  const OpnamePage({super.key});

  @override
  ConsumerState<OpnamePage> createState() => _OpnamePageState();
}

class _OpnamePageState extends ConsumerState<OpnamePage> {
  bool _busy = false;
  String _search = '';
  final _searchController = TextEditingController();

  final Map<String, int> _actualByMedicine = {};
  final Map<String, Medicine> _medicineById = {};
  String? _activeOpnameNumber;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _recordBarcodeScan(String barcode) async {
    final med = await findMedicineByBarcodeWithFeedback(context, ref, barcode);
    if (med == null || !mounted) return;

    setState(() {
      _medicineById[med.id] = med;
      _actualByMedicine[med.id] = (_actualByMedicine[med.id] ?? 0) + 1;
    });

    final total = _actualByMedicine[med.id]!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${med.name} +1 (total: $total)'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openContinuousScan() async {
    await openContinuousBarcodeScanner(
      context,
      title: 'Scan Opname',
      onBarcode: _recordBarcodeScan,
    );
  }

  void _setQty(Medicine m, int? qty) {
    setState(() {
      _medicineById[m.id] = m;
      if (qty == null || qty <= 0) {
        _actualByMedicine.remove(m.id);
      } else {
        _actualByMedicine[m.id] = qty;
      }
    });
  }

  Future<void> _submitOpname() async {
    if (_actualByMedicine.isEmpty) return;
    setState(() => _busy = true);

    try {
      final branchId = ref.read(warehouseBranchIdProvider);
      if (branchId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pilih cabang terlebih dahulu'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }
      final repo = ref.read(warehouseRepositoryProvider);

      final opname = await repo.createOpname(branchId: branchId);
      _activeOpnameNumber = opname.opnameNumber;

      final items = _actualByMedicine.entries
          .map(
            (e) => StockOpnameItemInput(
              medicineId: e.key,
              medicineName: _medicineById[e.key]?.name ?? '',
              actualQty: e.value,
            ),
          )
          .toList();

      await repo.upsertOpnameItems(opnameId: opname.id, items: items);
      await repo.submitOpname(opname.id);

      _actualByMedicine.clear();
      _medicineById.clear();
      ref.invalidate(_opnameListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opname submitted${_activeOpnameNumber != null ? ' ($_activeOpnameNumber)' : ''}',
            ),
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Medicine> _recordedMedicines() {
    return _actualByMedicine.keys
        .map((id) => _medicineById[id])
        .whereType<Medicine>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final opnamesAsync = ref.watch(_opnameListProvider);
    final medicinesAsync = ref.watch(_medicineSearchProvider(_search));
    final selectedCount = _actualByMedicine.length;
    final recorded = _recordedMedicines();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        opnamesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Gagal load opname: $e'),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            final last = items.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Card(
                child: ListTile(
                  leading: AppIcon3D.list(
                    icon: Icons.history,
                    accentKey: last.opnameNumber,
                  ),
                  title: Text('Opname terakhir: ${last.opnameNumber}'),
                  subtitle: Text('Status: ${last.status} · Items: ${last.itemCount}'),
                ),
              ),
            );
          },
        ),
        if (!kIsWeb) ...[
          ElevatedButton.icon(
            onPressed: _openContinuousScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Opname (multi barcode)'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Buka kamera dan scan banyak barcode tanpa keluar. Scan ulang barcode yang sama untuk menambah qty.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        BarcodeSearchField(
          controller: _searchController,
          labelText: 'Cari obat untuk opname',
          onSubmitted: (v) => setState(() => _search = v),
          onBarcode: _recordBarcodeScan,
        ),
        if (recorded.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Item tercatat ($selectedCount)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: recorded.length,
              itemBuilder: (context, index) {
                final m = recorded[index];
                final qty = _actualByMedicine[m.id] ?? 0;
                return Card(
                  child: ListTile(
                    dense: true,
                    title: Text(m.name),
                    subtitle: Text(m.barcode ?? m.unit),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: qty <= 1
                              ? () => _setQty(m, null)
                              : () => _setQty(m, qty - 1),
                        ),
                        Text(
                          '$qty',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _setQty(m, qty + 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        medicinesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (items) {
            if (items.isEmpty && recorded.isEmpty) {
              return const Text('Tidak ada obat ditemukan');
            }
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hasil pencarian',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final m = items[index];
                      final current = _actualByMedicine[m.id];
                      return Card(
                        child: ListTile(
                          title: Text(m.name),
                          subtitle: Text(m.unit),
                          trailing: SizedBox(
                            width: 110,
                            child: TextFormField(
                              initialValue: current?.toString() ?? '',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Qty',
                                isDense: true,
                              ),
                              onChanged: (v) {
                                _setQty(m, int.tryParse(v));
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Submit Opname ($selectedCount item)',
          isLoading: _busy,
          onPressed: selectedCount == 0 ? null : _submitOpname,
        ),
        if (user?.branchId != null) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(_opnameListProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh riwayat opname'),
          ),
        ],
      ],
    );
  }
}

final _opnameListProvider = FutureProvider.autoDispose<List<StockOpname>>((ref) async {
  final branchId = ref.watch(warehouseBranchIdProvider);
  if (branchId == null) return [];
  return ref.watch(warehouseRepositoryProvider).listOpnames(branchId: branchId);
});

final _medicineSearchProvider =
    FutureProvider.autoDispose.family<List<Medicine>, String>((ref, search) {
  return ref
      .watch(medicineRepositoryProvider)
      .getMedicines(search: search.isEmpty ? null : search);
});
