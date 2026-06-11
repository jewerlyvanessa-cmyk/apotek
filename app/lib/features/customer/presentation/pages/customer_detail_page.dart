import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/paginated_result.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../order/presentation/utils/order_status_ui.dart';
import '../../../reports/presentation/providers/report_date_filter.dart';
import '../../../reports/presentation/widgets/report_date_filter_bar.dart';
import '../../data/customer_repository.dart';
import '../../domain/entities/customer_transactions.dart';

class _CustomerTxQuery {
  const _CustomerTxQuery({
    required this.customerId,
    required this.filter,
    required this.page,
  });

  final String customerId;
  final ReportDateFilter filter;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is _CustomerTxQuery &&
      other.customerId == customerId &&
      other.filter.mode == filter.mode &&
      other.filter.from == filter.from &&
      other.filter.to == filter.to &&
      other.page == page;

  @override
  int get hashCode => Object.hash(
        customerId,
        filter.mode,
        filter.from,
        filter.to,
        page,
      );
}

final _customerTransactionsProvider = FutureProvider.autoDispose
    .family<CustomerTransactionsResult, _CustomerTxQuery>((ref, q) async {
  return ref.watch(customerRepositoryProvider).getTransactions(
        customerId: q.customerId,
        dateFrom: q.filter.dateFromIso,
        dateTo: q.filter.dateToIso,
        page: q.page,
      );
});

class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  int _page = 1;
  ReportDateFilter _filter = ReportDateFilter.today();

  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final query = _CustomerTxQuery(
      customerId: widget.customerId,
      filter: _filter,
      page: _page,
    );
    final async = ref.watch(_customerTransactionsProvider(query));
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return AppScaffold(
      title: 'Detail Pelanggan',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportDateFilterBar(
            filter: _filter,
            onFilterChanged: (f) => setState(() {
              _filter = f;
              _page = 1;
            }),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(_err(e), textAlign: TextAlign.center),
                ),
              ),
              data: (result) {
                final customer = result.customer;
                final name = customer['name']?.toString() ?? 'Pelanggan';
                final phone = customer['phone']?.toString();
                final email = customer['email']?.toString();

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(_customerTransactionsProvider(query));
                    await ref.read(_customerTransactionsProvider(query).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (phone != null && phone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Tel: $phone'),
                              ],
                              if (email != null && email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Email: $email'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ringkasan periode',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _filter.label(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SummaryTile(
                                      label: 'Transaksi',
                                      value: '${result.summary.transactionCount}',
                                    ),
                                  ),
                                  Expanded(
                                    child: _SummaryTile(
                                      label: 'Lunas',
                                      value: '${result.summary.paidCount}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _SummaryTile(
                                label: 'Total belanja (lunas)',
                                value: formatRupiah(result.summary.totalSpent),
                                emphasize: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Riwayat transaksi',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (result.orders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                          child: Center(
                            child: Text(
                              'Belum ada transaksi pada periode ini.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...result.orders.map((order) {
                          final statusColor = orderStatusColor(order.status);
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ListTile(
                              title: Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (order.createdAt != null)
                                    Text(dateFmt.format(order.createdAt!.toLocal())),
                                  Text(
                                    orderStatusLabel(order.status),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                formatRupiah(order.total),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              onTap: () => context.push('/orders/${order.id}'),
                            ),
                          );
                        }),
                      PaginationBar(
                        meta: PaginatedMeta.fromJson(result.meta),
                        onPageChanged: (p) => setState(() => _page = p),
                      ),
                    ],
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: emphasize ? 18 : 16,
            color: emphasize ? AppColors.primary : null,
          ),
        ),
      ],
    );
  }
}

