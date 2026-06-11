import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/utils/api_asset_url.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../order/data/order_repository.dart';
import '../../domain/entities/payment_summary.dart';
import '../providers/payment_providers.dart';

class PaymentDetailPage extends ConsumerStatefulWidget {
  const PaymentDetailPage({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends ConsumerState<PaymentDetailPage> {
  bool _refunding = false;

  Future<void> _refund(PaymentSummary payment) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retur transaksi'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Alasan retur (opsional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proses retur'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _refunding = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .refundOrder(payment.orderId, reason: reasonCtrl.text.trim());
      ref.invalidate(paymentDetailProvider(widget.paymentId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retur berhasil — stok dikembalikan'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      reasonCtrl.dispose();
      if (mounted) setState(() => _refunding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(paymentDetailProvider(widget.paymentId));
    final user = ref.watch(authProvider).user;
    final canRefund =
        user != null && (user.isCashier || user.isManager || user.isOwner);
    final apiBase = ref.watch(appConfigProvider).apiBaseUrl;
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return AppScaffold(
      title: 'Detail Pembayaran',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Gagal memuat: $e'),
          ),
        ),
        data: (payment) {
          final order = payment.order;
          final items = order?.items ?? [];

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.orderNumber,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              payment.customerName ?? 'Walk-in',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order?.status == 'REFUNDED' ? 'Retur' : 'Lunas',
                              style: TextStyle(
                                color: order?.status == 'REFUNDED'
                                    ? AppColors.danger
                                    : AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (payment.paidAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateFmt.format(payment.paidAt!.toLocal()),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Pembayaran',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Metode',
                      value: paymentMethodLabel(payment.paymentMethod),
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      label: 'Jumlah',
                      value: formatRupiah(payment.amount),
                      valueStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    if (payment.referenceNumber != null &&
                        payment.referenceNumber!.isNotEmpty) ...[
                      const Divider(height: 1),
                      _InfoRow(
                        label: 'Referensi',
                        value: payment.referenceNumber!,
                      ),
                    ],
                    if (payment.paidByName != null) ...[
                      const Divider(height: 1),
                      _InfoRow(label: 'Kasir', value: payment.paidByName!),
                    ],
                    if (payment.paymentMethod.toUpperCase() == 'CASH' &&
                        payment.amountReceived != null) ...[
                      const Divider(height: 1),
                      _InfoRow(
                        label: 'Diterima',
                        value: formatRupiah(payment.amountReceived!),
                      ),
                      if (payment.changeAmount != null &&
                          payment.changeAmount! > 0) ...[
                        const Divider(height: 1),
                        _InfoRow(
                          label: 'Kembalian',
                          value: formatRupiah(payment.changeAmount!),
                          valueStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (payment.proofImageUrl != null &&
                  payment.proofImageUrl!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Bukti pembayaran',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      final url = resolveApiAssetUrl(
                        apiBase,
                        payment.proofImageUrl!,
                      );
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(url, fit: BoxFit.contain),
                          ),
                        ),
                      );
                    },
                    child: Image.network(
                      resolveApiAssetUrl(apiBase, payment.proofImageUrl!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Text('Gagal memuat gambar bukti'),
                          ),
                    ),
                  ),
                ),
              ],
              if (items.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Item (${items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(
                            items[i].medicineName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${items[i].quantity}${items[i].unit != null ? ' ${items[i].unit}' : ''} × ${formatRupiah(items[i].price)}',
                          ),
                          trailing: Text(
                            formatRupiah(items[i].subtotal),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total dibayar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        formatRupiah(payment.amount),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (canRefund && order != null && order.status == 'PAID') ...[
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  label: 'Proses retur transaksi',
                  button: true,
                  child: FilledButton.icon(
                    onPressed: _refunding ? null : () => _refund(payment),
                    icon: _refunding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo),
                    label: const Text('Proses retur'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
