import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/utils/medicine_barcode_lookup.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/warehouse_branch_provider.dart';
import '../../../medicine/data/medicine_repository.dart';
import '../../../medicine/domain/entities/medicine.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  bool _busy = false;
  String? _toBranchId;
  String _search = '';
  final _searchController = TextEditingController();

  final Map<String, int> _qtyByMedicine = {};
  String? _lastTransferNumber;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitTransfer() async {
    final user = ref.read(authProvider).user;
    final fromBranchId = ref.read(warehouseBranchIdProvider) ?? user?.branchId;
    if (fromBranchId == null) return;
    if (_toBranchId == null) return;
    if (_qtyByMedicine.isEmpty) return;

    setState(() => _busy = true);
    try {
      final dio = ref.read(dioProvider);

      final createRes = await dio.post<Map<String, dynamic>>(
        '/transfer-stocks',
        data: {
          'from_branch_id': fromBranchId,
          'to_branch_id': _toBranchId,
          'items': _qtyByMedicine.entries
              .map((e) => {'medicine_id': e.key, 'quantity': e.value})
              .toList(),
        },
      );

      final transferId = (createRes.data?['data'] as Map?)?['id'] as String?;
      _lastTransferNumber =
          (createRes.data?['data'] as Map?)?['transferNumber'] as String?;
      if (transferId == null) throw Exception('Transfer create failed');

      await dio.post('/transfer-stocks/$transferId/submit');

      _qtyByMedicine.clear();
      ref.invalidate(_transferListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transfer completed${_lastTransferNumber != null ? ' ($_lastTransferNumber)' : ''}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(_branchesProvider);
    final transfersAsync = ref.watch(_transferListProvider);
    final medicinesAsync = ref.watch(_medicineSearchProvider(_search));
    final selected = _qtyByMedicine.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        transfersAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Gagal load transfer: $e'),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            final last = items.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Card(
                child: ListTile(
                  leading: AppIcon3D.list(
                    icon: Icons.history,
                    accentKey: last['transferNumber']?.toString() ?? '',
                  ),
                  title: Text('Transfer terakhir: ${last['transferNumber']}'),
                  subtitle: Text(
                    'Status: ${last['status']} · Items: ${(last['_count'] as Map?)?['items'] ?? 0}',
                  ),
                ),
              ),
            );
          },
        ),
        branchesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Gagal load cabang: $e'),
          data: (branches) {
            return DropdownButtonFormField<String>(
              initialValue: _toBranchId,
              decoration: const InputDecoration(labelText: 'Tujuan cabang'),
              items: branches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b['id'] as String,
                      child: Text(b['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _toBranchId = v),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        BarcodeSearchField(
          controller: _searchController,
          labelText: 'Cari obat untuk transfer',
          onSubmitted: (v) => setState(() => _search = v),
          onBarcode: (barcode) async {
            final med = await findMedicineByBarcodeWithFeedback(
              context,
              ref,
              barcode,
            );
            if (med != null && mounted) {
              setState(() => _search = med.name);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        medicinesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (items) {
            if (items.isEmpty) return const Text('Tidak ada obat ditemukan');
            return SizedBox(
              height: 240,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final m = items[index];
                  final current = _qtyByMedicine[m.id];
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
                            final qty = int.tryParse(v);
                            setState(() {
                              if (qty == null || qty <= 0) {
                                _qtyByMedicine.remove(m.id);
                              } else {
                                _qtyByMedicine[m.id] = qty;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Submit Transfer ($selected item)',
          isLoading: _busy,
          onPressed: selected == 0 || _toBranchId == null ? null : _submitTransfer,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(_transferListProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh riwayat transfer'),
        ),
      ],
    );
  }
}

final _medicineSearchProvider =
    FutureProvider.autoDispose.family<List<Medicine>, String>((ref, search) {
  return ref
      .watch(medicineRepositoryProvider)
      .getMedicines(search: search.isEmpty ? null : search);
});

final _branchesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>('/branches', queryParameters: {'limit': 50});
  final data = res.data!;
  final list = (data['data'] as List).cast<Map>();
  return list.map((e) => Map<String, dynamic>.from(e)).toList();
});

final _transferListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    '/transfer-stocks',
    queryParameters: {'limit': 20},
  );
  final data = res.data!;
  final list = (data['data'] as List).cast<Map>();
  return list.map((e) => Map<String, dynamic>.from(e)).toList();
});

