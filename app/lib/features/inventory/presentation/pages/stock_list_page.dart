import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/websocket/socket_service.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/stock_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_badge.dart';

class StockListPage extends ConsumerStatefulWidget {
  const StockListPage({
    super.key,
    this.fixedBranchId,
    this.title,
    this.locationCode,
    this.sellableOnly,
  });

  /// Jika diisi, filter cabang dikunci (mis. stok gudang pusat).
  final String? fixedBranchId;
  final String? title;
  final String? locationCode;
  final bool? sellableOnly;

  @override
  ConsumerState<StockListPage> createState() => _StockListPageState();
}

class _StockListPageState extends ConsumerState<StockListPage> {
  final _searchController = TextEditingController();
  bool _lowStockOnly = false;
  int _page = 1;
  String? _selectedBranchId;
  SocketEventCallback? _socketListener;
  SocketService? _socket;

  StockListParams _params() {
    if (widget.fixedBranchId != null) {
      return StockListParams(
        branchId: widget.fixedBranchId,
        lowStockOnly: _lowStockOnly,
        page: _page,
        locationCode: widget.locationCode,
        sellableOnly: widget.sellableOnly,
      );
    }
    final tenantWide = ref.read(isTenantWideStockProvider);
    final needsPicker = ref.read(needsStockBranchPickerProvider);
    final user = ref.read(authProvider).user;
    final rawBranchId = needsPicker
        ? _selectedBranchId
        : ref.read(effectiveBranchIdProvider);
    final branchId =
        user == null ? rawBranchId : resolveStockBranchId(user, rawBranchId);
    return StockListParams(
      branchId: branchId,
      lowStockOnly: _lowStockOnly,
      page: _page,
      tenantWide: tenantWide && branchId == null,
      locationCode: widget.locationCode,
      sellableOnly: widget.sellableOnly,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.fixedBranchId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null &&
          widget.fixedBranchId == null &&
          !user.isTenantWideStock) {
        final resolved = resolveStockBranchId(user, _selectedBranchId);
        if (resolved != null && resolved != _selectedBranchId) {
          setState(() => _selectedBranchId = resolved);
        }
      }
      _setupSocket();
    });
  }

  void _setupSocket() {
    _socket = ref.read(socketServiceProvider);
    final params = _params();

    _socketListener = (payload) {
      ref.read(stockListProvider(params).notifier).applyRealtimeUpdate(payload);
    };
    _socket!.onStockUpdate(_socketListener!);
  }

  void _rebindSocket() {
    if (_socketListener != null && _socket != null) {
      _socket!.offStockUpdate(_socketListener!);
    }
    _setupSocket();
  }

  @override
  void dispose() {
    if (_socketListener != null && _socket != null) {
      _socket!.offStockUpdate(_socketListener!);
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAdjustDialog(StockItem item) async {
    final qtyController = TextEditingController(text: '${item.quantity}');
    final rackController = TextEditingController(text: item.rackPosition ?? '');
    int? newQty;
    var newRack = item.rackPosition ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kelola Stok\n${item.medicineName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty sistem (baru)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: rackController,
                decoration: const InputDecoration(
                  labelText: 'Posisi rak',
                  hintText: 'Contoh: A-12, Rak 3 baris 2',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(qtyController.text);
              if (v != null && v >= 0) {
                newQty = v;
                newRack = rackController.text.trim();
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    qtyController.dispose();
    rackController.dispose();

    if (saved != true || !mounted || newQty == null) return;
    final qty = newQty!;
    final rackChanged = newRack != (item.rackPosition ?? '');

    try {
      if (qty != item.quantity || rackChanged) {
        await ref.read(stockRepositoryProvider).updateStock(
              stockId: item.id,
              quantity: qty,
              rackPosition: newRack,
            );
      }
      ref.invalidate(stockListProvider(_params()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stok diperbarui'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response == null) {
        await ref.read(syncManagerProvider).enqueueAdjustStock(
              medicineId: item.medicineId,
              quantity: qty,
              branchId: item.branchId,
              batchId: item.batchId,
              notes: 'Manual adjustment',
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: penyesuaian stok di-queue'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  String _formatExp(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  bool _canManageStock() {
    final user = ref.read(authProvider).user;
    if (user == null) return false;
    return user.isOwner || user.isManager || user.isWarehouse;
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManageStock();
    final fixed = widget.fixedBranchId;
    final tenantWide =
        fixed == null && ref.watch(isTenantWideStockProvider);
    final needsPicker =
        fixed == null && ref.watch(needsStockBranchPickerProvider);
    final user = ref.watch(authProvider).user;
    final rawBranchId = fixed ??
        (needsPicker
            ? _selectedBranchId
            : ref.watch(effectiveBranchIdProvider));
    final branchId = user == null
        ? rawBranchId
        : resolveStockBranchId(user, rawBranchId);
    final params = _params();
    final stocksAsync = ref.watch(stockListProvider(params));

    if (!tenantWide && branchId == null) {
      return const AppScaffold(
        title: 'Stok Cabang',
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Cabang aktif belum dipilih.\nGunakan menu ganti cabang di profil, '
              'atau login dengan akun yang terikat cabang.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!tenantWide && needsPicker && branchId == null) {
      return AppScaffold(
        title: tenantWide ? 'Stok Tenant' : 'Stok',
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ref.watch(stockBranchPickerOptionsProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal memuat cabang: $e')),
                data: (branches) {
                  if (branches.isEmpty) {
                    return const Center(
                      child: Text('Tidak ada cabang tersedia.'),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pilih cabang untuk melihat stok.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...branches.map(
                        (b) => Card(
                          child: ListTile(
                            title: Text(b['name']?.toString() ?? '-'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              setState(() {
                                _selectedBranchId = b['id']?.toString();
                                _page = 1;
                              });
                              _rebindSocket();
                              ref.invalidate(stockListProvider(_params()));
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ),
      );
    }

    String? branchTitle;
    final branchUser = user;
    if (branchUser?.isBranchManager == true && branchId != null) {
      final u = branchUser!;
      if (u.branchId == branchId && u.branchName != null) {
        branchTitle = u.branchName;
      } else {
        for (final b in u.branches) {
          if (b.id == branchId) {
            branchTitle = b.name;
            break;
          }
        }
      }
    }

    return AppScaffold(
      title: widget.title ??
          (tenantWide
              ? 'Stok Tenant'
              : branchTitle != null && branchTitle.isNotEmpty
                  ? 'Stok $branchTitle'
                  : 'Stok Cabang'),
      actions: [
        if (canManage) ...[
          Semantics(
            label: 'Terima stok baru',
            button: true,
            child: IconButton(
              tooltip: 'Terima stok',
              onPressed: () => context.push(
                '/stocks/receive',
                extra: branchId,
              ),
              icon: const Icon(Icons.add_box_outlined),
            ),
          ),
          Semantics(
            label: 'Riwayat mutasi stok',
            button: true,
            child: IconButton(
              tooltip: 'Riwayat mutasi',
              onPressed: () => context.push(
                '/stock-movements',
                extra: branchId,
              ),
              icon: const Icon(Icons.history),
            ),
          ),
        ],
      ],
      floatingActionButton: canManage
          ? Semantics(
              label: 'Terima stok',
              button: true,
              child: FloatingActionButton.extended(
                onPressed: () => context.push(
                  '/stocks/receive',
                  extra: branchId,
                ),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Terima stok'),
              ),
            )
          : null,
      body: Column(
        children: [
          if (needsPicker && fixed == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: ref.watch(stockBranchPickerOptionsProvider).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, unused) => const SizedBox.shrink(),
                    data: (branches) {
                      return DropdownButtonFormField<String?>(
                        key: ValueKey(_selectedBranchId),
                        initialValue: _selectedBranchId,
                        decoration: InputDecoration(
                          labelText: tenantWide ? 'Filter cabang' : 'Cabang',
                          isDense: true,
                        ),
                        items: [
                          if (tenantWide)
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Semua cabang (tenant)'),
                            ),
                          ...branches.map(
                            (b) => DropdownMenuItem<String?>(
                              value: b['id']?.toString(),
                              child: Text(b['name']?.toString() ?? '-'),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          final u = ref.read(authProvider).user;
                          final safe = u == null
                              ? v
                              : resolveStockBranchId(u, v);
                          setState(() {
                            _selectedBranchId = safe;
                            _page = 1;
                          });
                          _rebindSocket();
                          ref.invalidate(stockListProvider(_params()));
                        },
                      );
                    },
                  ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: BarcodeSearchField(
                    controller: _searchController,
                    hintText: 'Cari obat...',
                    isDense: true,
                    onSubmitted: (v) => ref
                        .read(stockListProvider(params).notifier)
                        .load(search: v),
                    onBarcode: (barcode) async {
                      await ref
                          .read(stockListProvider(params).notifier)
                          .load(search: barcode);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  label: 'Filter stok rendah',
                  toggled: _lowStockOnly,
                  child: FilterChip(
                    label: const Text('Stok rendah'),
                    selected: _lowStockOnly,
                    onSelected: (v) {
                      setState(() {
                        _lowStockOnly = v;
                        _page = 1;
                      });
                      ref.invalidate(stockListProvider(_params()));
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: (_socket?.isConnected ?? false)
                      ? AppColors.success
                      : AppColors.danger,
                ),
                const SizedBox(width: 6),
                Text(
                  (_socket?.isConnected ?? false)
                      ? 'Realtime aktif'
                      : 'Realtime terputus',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: stocksAsync.when(
              loading: () => const AsyncLoadingView(message: 'Memuat stok…'),
              error: (e, _) => AsyncErrorView.fromError(
                e,
                onRetry: () => ref.read(stockListProvider(params).notifier).load(),
              ),
              data: (state) {
                final items = state.items;
                if (items.isEmpty) {
                  return EmptyStateView(
                    title: 'Tidak ada data stok',
                    subtitle: _lowStockOnly
                        ? 'Tidak ada item dengan stok rendah.'
                        : 'Coba ubah filter atau terima stok baru.',
                    icon: Icons.inventory_2_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(stockListProvider(params).notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return PaginationBar(
                          meta: state.meta,
                          onPageChanged: (p) {
                            setState(() => _page = p);
                            ref
                                .read(stockListProvider(_params()).notifier)
                                .load(page: p);
                          },
                        );
                      }
                      final item = items[index];
                      return Semantics(
                        label:
                            '${item.medicineName}, stok ${item.quantity} ${item.unit ?? ''}',
                        button: canManage,
                        child: Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          title: Text(
                            item.medicineName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((tenantWide || needsPicker) &&
                                  item.branchName != null)
                                Text(
                                  'Cabang: ${item.branchName}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (item.locationName != null &&
                                  item.locationName!.isNotEmpty)
                                Text(
                                  'Lokasi: ${item.locationName}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              if (item.rackPosition != null &&
                                  item.rackPosition!.isNotEmpty)
                                Text(
                                  'Rak: ${item.rackPosition}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (item.batchNumber != null)
                                Text('Batch: ${item.batchNumber}'),
                              if (item.expiredDate != null)
                                Text(
                                  'Exp: ${_formatExp(item.expiredDate!)}',
                                  style: TextStyle(
                                    color: item.expiredDate!.isBefore(DateTime.now())
                                        ? AppColors.danger
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              Text(
                                'Total: ${item.quantity} · ${item.unit ?? '-'}',
                              ),
                            ],
                          ),
                          trailing: StockBadge(item: item),
                          onTap: canManage ? () => _showAdjustDialog(item) : null,
                        ),
                      ),
                      );
                    },
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
