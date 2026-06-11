import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../order/presentation/providers/order_list_provider.dart';
import '../../../order/presentation/utils/order_status_ui.dart';

class CashierOrderPage extends ConsumerWidget {
  const CashierOrderPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));

    return AppScaffold(
      title: 'Bayar Order',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Gagal memuat: $e'),
          ),
        ),
        data: (order) {
          if (order.status != 'WAITING_PAYMENT') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Order ${order.orderNumber} sudah tidak menunggu pembayaran.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final statusColor = orderStatusColor(order.status);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      order.customerName ?? 'Walk-in',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        orderStatusLabel(order.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Divider(height: AppSpacing.xl),
                    ...order.items.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.medicineName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${item.quantity} x ${formatRupiah(item.price)}',
                        ),
                        trailing: Text(
                          formatRupiah(item.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total: ${formatRupiah(order.total)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Bayar Sekarang',
                      onPressed: () =>
                          context.push('/cashier/orders/$orderId/pay'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
