import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/websocket/socket_events.dart';
import '../../../../core/websocket/socket_service.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../order/data/order_repository.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/presentation/providers/order_list_provider.dart';
import '../../../payment/presentation/providers/payment_providers.dart';

class CashierPage extends ConsumerStatefulWidget {
  const CashierPage({super.key});

  @override
  ConsumerState<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends ConsumerState<CashierPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SocketService? _socket;
  void Function(Map<String, dynamic>)? _orderListener;

  @override
  void dispose() {
    _searchController.dispose();
    if (_socket != null && _orderListener != null) {
      _socket!.off(SocketEvents.orderCreated, _orderListener!);
      _socket!.off(SocketEvents.orderUpdated, _orderListener!);
      _socket!.off(SocketEvents.paymentCompleted, _orderListener!);
    }
    super.dispose();
  }

  List<OrderSummary> _filterOrders(List<OrderSummary> orders) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return orders;
    return orders
        .where(
          (o) =>
              o.orderNumber.toLowerCase().contains(q) ||
              (o.customerName?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  void _openOrder(String orderId) {
    context.push('/cashier/orders/$orderId');
  }

  Future<void> _applySearch(String raw) async {
    final q = raw.trim();
    if (!mounted) return;
    setState(() => _searchQuery = q);
    if (q.isEmpty) return;

    final orders = ref.read(waitingOrdersProvider).valueOrNull;
    if (orders == null) return;

    OrderSummary? pick;
    for (final o in orders) {
      if (o.orderNumber.toLowerCase() == q.toLowerCase()) {
        pick = o;
        break;
      }
    }
    final filtered = _filterOrders(orders);
    pick ??= filtered.length == 1 ? filtered.first : null;

    if (pick != null) {
      _openOrder(pick.id);
      return;
    }

    if (q.length < 3) return;

    try {
      final remote = await ref.read(orderRepositoryProvider).getOrders(
            status: 'WAITING_PAYMENT',
            search: q,
            limit: 10,
          );
      if (!mounted) return;

      OrderSummary? remotePick;
      for (final o in remote) {
        if (o.orderNumber.toLowerCase() == q.toLowerCase()) {
          remotePick = o;
          break;
        }
      }
      remotePick ??= remote.length == 1 ? remote.first : null;

      if (remotePick != null && remotePick.status == 'WAITING_PAYMENT') {
        _openOrder(remotePick.id);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remote.isEmpty
                ? 'Order "$q" tidak ditemukan atau sudah lunas'
                : 'Beberapa order cocok — pilih dari daftar',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencari: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupSocket());
  }

  void _setupSocket() {
    _socket = ref.read(socketServiceProvider);
    _orderListener = (_) {
      ref.invalidate(waitingOrdersProvider);
      ref.invalidate(cashierTodayPaymentsProvider);
    };
    _socket!.on(SocketEvents.orderCreated, _orderListener!);
    _socket!.on(SocketEvents.orderUpdated, _orderListener!);
    _socket!.on(SocketEvents.paymentCompleted, _orderListener!);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final ordersAsync = ref.watch(waitingOrdersProvider);

    if (user?.branchId == null) {
      return const AppScaffold(
        title: 'Kasir',
        body: Center(child: Text('Login sebagai kasir dengan cabang aktif')),
      );
    }

    return AppScaffold(
      title: 'Kasir',
      actions: [
        Semantics(
          label: 'Kas cabang',
          button: true,
          child: IconButton(
            tooltip: 'Kas cabang',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push('/cashier/ledger'),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: BarcodeSearchField(
              controller: _searchController,
              hintText: 'Nomor order / nama pelanggan',
              labelText: 'Cari order menunggu bayar',
              isDense: true,
              autofocus: true,
              onChanged: (v) => setState(() => _searchQuery = v),
              onSubmitted: _applySearch,
              onBarcode: _applySearch,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (orders) {
                final filtered = _filterOrders(orders);

                if (orders.isEmpty) {
                  if (_searchQuery.trim().isEmpty) {
                    return const Center(
                      child: Text('Belum ada order menunggu pembayaran'),
                    );
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Tidak ada order yang cocok. Scan QR nomor order atau tekan Enter untuk mencari.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Tidak ada order yang cocok dengan "${_searchQuery.trim()}"',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(waitingOrdersProvider);
                    await ref.read(waitingOrdersProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final o = filtered[index];
                      return Semantics(
                        label:
                            'Order ${o.orderNumber}, ${o.customerName ?? 'Walk-in'}, total ${formatRupiah(o.total)}',
                        button: true,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            title: Text(
                              o.orderNumber,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(o.customerName ?? 'Walk-in'),
                            trailing: Text(formatRupiah(o.total)),
                            onTap: () => _openOrder(o.id),
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
