import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pharmacy/presentation/pages/pharmacy_reviews_page.dart';
import '../../data/order_repository.dart';
import '../providers/order_list_provider.dart';
import '../utils/order_permissions.dart';
import '../utils/order_status_ui.dart';
import '../widgets/prescription_info_card.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool _cancelling = false;
  bool _approving = false;

  Future<void> _approvePharmacy() async {
    final notesCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Setujui telaah apoteker?'),
          content: TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Catatan apoteker (opsional)',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Setujui'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      setState(() => _approving = true);
      try {
        await ref.read(orderRepositoryProvider).approvePharmacy(
              orderId: widget.orderId,
              pharmacistNotes: notesCtrl.text.trim(),
            );
        ref.invalidate(orderDetailProvider(widget.orderId));
        ref.invalidate(pendingPharmacyOrdersProvider);
        ref.invalidate(pendingPharmacyOrdersHomeProvider);
        ref.invalidate(pharmacistTodayReviewsProvider);
        ref.invalidate(waitingOrdersProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order disetujui — siap dibayar di kasir'),
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
        if (mounted) setState(() => _approving = false);
      }
    } finally {
      notesCtrl.dispose();
    }
  }

  Future<void> _cancelOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan order?'),
        content: const Text(
          'Stok yang di-reserve akan dikembalikan. Pembatalan hanya untuk order yang belum lunas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(orderRepositoryProvider).cancelOrder(widget.orderId);
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(staffTodayOrdersProvider);
      ref.invalidate(waitingOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order dibatalkan'),
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
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderId));
    final user = ref.watch(authProvider).user;
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return AppScaffold(
      title: 'Detail Order',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Gagal memuat: $e'),
          ),
        ),
        data: (order) {
          final statusColor = orderStatusColor(order.status);
          final showEdit = canEditOrder(user, order);
          final showCancel = canCancelOrder(user, order);
          final showApprove = canApprovePharmacy(user, order);
          final canPay = canPayOrder(order);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNumber,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              order.customerName ?? 'Walk-in',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (order.createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                dateFmt.format(order.createdAt!.toLocal()),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
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
                            if (order.pharmacistNotes != null &&
                                order.pharmacistNotes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Catatan apoteker: ${order.pharmacistNotes}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (!canPay && order.status == 'PENDING_PHARMACY') ...[
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                'Menunggu persetujuan apoteker sebelum pembayaran.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      QrImageView(
                        data: order.orderNumber,
                        version: QrVersions.auto,
                        size: 88,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                ),
              ),
              if (order.prescription != null) ...[
                const SizedBox(height: AppSpacing.md),
                PrescriptionInfoCard(prescription: order.prescription!),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Item (${order.items.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < order.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(
                          order.items[i].medicineName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${order.items[i].quantity}${order.items[i].unit != null ? ' ${order.items[i].unit}' : ''} × ${formatRupiah(order.items[i].price)}',
                            ),
                            if (order.items[i].usageInstructions != null &&
                                order
                                    .items[i].usageInstructions!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Petunjuk: ${order.items[i].usageInstructions}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: order.items[i].usageInstructions != null &&
                            order.items[i].usageInstructions!.isNotEmpty,
                        trailing: Text(
                          formatRupiah(order.items[i].subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        formatRupiah(order.total),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showApprove) ...[
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  label: 'Setujui telaah apoteker',
                  button: true,
                  child: AppButton(
                    label: _approving
                        ? 'Memproses...'
                        : 'Setujui Telaah Apoteker',
                    onPressed: _approving ? null : _approvePharmacy,
                  ),
                ),
              ],
              if (showEdit) ...[
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  label: 'Edit order',
                  button: true,
                  child: AppButton(
                    label: 'Edit Order',
                    onPressed: () =>
                        context.push('/orders/${widget.orderId}/edit'),
                  ),
                ),
              ],
              if (showCancel) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  label: 'Batalkan order',
                  button: true,
                  child: OutlinedButton(
                    onPressed: _cancelling ? null : _cancelOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _cancelling
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Batalkan Order'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
