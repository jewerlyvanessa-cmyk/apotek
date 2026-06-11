import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/utils/medicine_barcode_lookup.dart';
import '../../../inventory/data/stock_repository.dart';
import '../../../inventory/domain/entities/stock_item.dart';
import '../../../warehouse/presentation/providers/central_warehouse_provider.dart';

final _distributionListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    '/transfer-stocks',
    queryParameters: {'limit': 30, 'transfer_type': 'DISTRIBUTION'},
  );
  final list = (res.data?['data'] as List?) ?? [];
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final _nonCentralBranchesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final central = await ref.watch(centralWarehouseProvider.future);
  final centralId = central['id']?.toString();
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    '/branches',
    queryParameters: {'limit': 50},
  );
  final list = (res.data?['data'] as List?) ?? [];
  return list
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((b) => b['id']?.toString() != centralId)
      .where(
        (b) =>
            b['isCentralWarehouse'] != true &&
            b['is_central_warehouse'] != true,
      )
      .toList();
});

final _centralStocksProvider =
    FutureProvider.autoDispose<List<StockItem>>((ref) async {
  final central = await ref.watch(centralWarehouseProvider.future);
  final branchId = central['id']?.toString();
  if (branchId == null) return [];
  final result =
      await ref.watch(stockRepositoryProvider).getStocks(branchId: branchId);
  return result.items;
});

class DistributionPage extends ConsumerStatefulWidget {
  const DistributionPage({super.key});

  @override
  ConsumerState<DistributionPage> createState() => _DistributionPageState();
}

class _DistributionPageState extends ConsumerState<DistributionPage> {
  bool _busy = false;
  String? _toBranchId;
  final Map<String, int> _qtyByStockId = {};
  final _stockSearchController = TextEditingController();
  String _stockSearch = '';

  @override
  void dispose() {
    _stockSearchController.dispose();
    super.dispose();
  }

  bool _stockMatchesQuery(StockItem s, String q) {
    final name = s.medicineName.toLowerCase();
    final batch = (s.batchNumber ?? '').toLowerCase();
    final rack = (s.rackPosition ?? '').toLowerCase();
    final barcode = (s.barcode ?? '').toLowerCase();
    return name.contains(q) ||
        batch.contains(q) ||
        rack.contains(q) ||
        barcode.contains(q);
  }

  List<StockItem> _filterStocks(List<StockItem> stocks) {
    final q = _stockSearch.trim().toLowerCase();
    if (q.isEmpty) return stocks;
    return stocks.where((s) => _stockMatchesQuery(s, q)).toList();
  }

  Future<void> _onStockBarcode(String barcode) async {
    final med = await findMedicineByBarcodeWithFeedback(context, ref, barcode);
    if (!mounted) return;

    final query = med?.name ?? barcode;
    _stockSearchController.text = query;
    setState(() => _stockSearch = query);

    final stocks = ref.read(_centralStocksProvider).valueOrNull ?? [];
    final matches = stocks.where((s) {
      if (med != null && s.medicineId == med.id) return true;
      return _stockMatchesQuery(s, barcode.toLowerCase());
    }).toList();

    if (matches.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            med != null
                ? '${med.name} tidak ada di stok gudang pusat'
                : 'Obat tidak ditemukan di gudang pusat',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _createDistribution() async {
    if (_toBranchId == null || _qtyByStockId.isEmpty) return;

    final stocks = await ref.read(_centralStocksProvider.future);
    final stockById = {for (final s in stocks) s.id: s};

    final items = <Map<String, dynamic>>[];
    for (final entry in _qtyByStockId.entries) {
      final stock = stockById[entry.key];
      if (stock == null) continue;
      items.add({
        'medicine_id': stock.medicineId,
        'batch_id': stock.batchId,
        'quantity': entry.value,
      });
    }
    if (items.isEmpty) return;

    setState(() => _busy = true);
    try {
      final dio = ref.read(dioProvider);
      final createRes = await dio.post<Map<String, dynamic>>(
        '/transfer-stocks/distributions',
        data: {
          'to_branch_id': _toBranchId,
          'items': items,
        },
      );
      final id = (createRes.data?['data'] as Map?)?['id'] as String?;
      if (id != null) {
        await dio.post('/transfer-stocks/$id/send');
      }
      _qtyByStockId.clear();
      ref.invalidate(_distributionListProvider);
      ref.invalidate(_centralStocksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distribusi dibuat dan dikirim'),
            backgroundColor: AppColors.success,
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive(String id) async {
    try {
      await ref.read(dioProvider).post('/transfer-stocks/$id/receive');
      ref.invalidate(_distributionListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distribusi diterima di cabang'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final centralAsync = ref.watch(centralWarehouseProvider);
    final branchesAsync = ref.watch(_nonCentralBranchesProvider);
    final stocksAsync = ref.watch(_centralStocksProvider);
    final listAsync = ref.watch(_distributionListProvider);

    return AppScaffold(
      title: 'Distribusi ke Cabang',
      body: centralAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (e, _) => AsyncErrorView.fromError(
          e,
          onRetry: () => ref.invalidate(centralWarehouseProvider),
        ),
        data: (central) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: ListTile(
                leading: AppIcon3D.list(
                  icon: Icons.warehouse,
                  accentKey: central['name']?.toString() ?? 'central',
                ),
                title: const Text('Asal: Gudang Pusat'),
                subtitle: Text(
                  '${central['name']} (${central['code'] ?? '-'})',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Riwayat distribusi',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            listAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AsyncErrorView.fromError(
                e,
                onRetry: () => ref.invalidate(_distributionListProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyStateView(
                    title: 'Belum ada distribusi',
                    icon: Icons.call_split,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  );
                }
                return Column(
                  children: items.map((d) {
                    final status = d['status']?.toString() ?? '';
                    final id = d['id']?.toString() ?? '';
                    final toName =
                        (d['toBranch'] as Map?)?['name']?.toString() ?? '-';
                    return Card(
                      child: ListTile(
                        title: Text(d['transferNumber']?.toString() ?? id),
                        subtitle: Text('$toName · $status'),
                        trailing: status == 'SENT'
                            ? TextButton(
                                onPressed: () => _receive(id),
                                child: const Text('Terima'),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Buat distribusi baru',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            branchesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (branches) {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Cabang tujuan'),
                  items: branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b['id'] as String?,
                          child: Text(b['name']?.toString() ?? '-'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _toBranchId = v),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            BarcodeSearchField(
              controller: _stockSearchController,
              labelText: 'Cari obat / batch / rak',
              hintText: 'Ketik nama atau scan barcode...',
              onChanged: (v) => setState(() => _stockSearch = v),
              onBarcode: _onStockBarcode,
            ),
            const SizedBox(height: AppSpacing.sm),
            stocksAsync.when(
              loading: () => const AsyncLoadingView(),
              error: (e, _) => AsyncErrorView.fromError(
                e,
                onRetry: () => ref.invalidate(_centralStocksProvider),
              ),
              data: (stocks) {
                if (stocks.isEmpty) {
                  return const Text('Stok gudang pusat kosong');
                }
                final filtered = _filterStocks(stocks);
                if (filtered.isEmpty) {
                  return Text(
                    'Tidak ada obat cocok dengan "$_stockSearch"',
                    style: const TextStyle(color: AppColors.textSecondary),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_stockSearch.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'Menampilkan ${filtered.length} dari ${stocks.length} item',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ...filtered.map(
                      (s) => Card(
                        child: ListTile(
                          title: Text(s.medicineName),
                          subtitle: Text(
                            [
                              'Batch: ${s.batchNumber ?? '-'}',
                              'Tersedia: ${s.availableQuantity}',
                              if (s.rackPosition != null &&
                                  s.rackPosition!.isNotEmpty)
                                'Rak: ${s.rackPosition}',
                            ].join(' · '),
                          ),
                          trailing: SizedBox(
                            width: 72,
                            child: TextFormField(
                              initialValue:
                                  _qtyByStockId[s.id]?.toString() ?? '',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Qty',
                                isDense: true,
                              ),
                              onChanged: (v) {
                                final q = int.tryParse(v);
                                setState(() {
                                  if (q == null || q <= 0) {
                                    _qtyByStockId.remove(s.id);
                                  } else {
                                    _qtyByStockId[s.id] = q;
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Kirim distribusi (${_qtyByStockId.length} item)',
              isLoading: _busy,
              onPressed: _toBranchId == null || _qtyByStockId.isEmpty
                  ? null
                  : _createDistribution,
            ),
          ],
        ),
      ),
    );
  }
}
