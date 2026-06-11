import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../../../order/data/order_repository.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/presentation/utils/order_status_ui.dart';

class PharmacyReviewQuery {
  const PharmacyReviewQuery({this.branchId});

  final String? branchId;

  @override
  bool operator ==(Object other) =>
      other is PharmacyReviewQuery && branchId == other.branchId;

  @override
  int get hashCode => branchId.hashCode;
}

final pendingPharmacyOrdersProvider = FutureProvider.autoDispose
    .family<List<OrderSummary>, PharmacyReviewQuery>((ref, query) async {
  return ref.watch(orderRepositoryProvider).getOrders(
        status: 'PENDING_PHARMACY',
        branchId: query.branchId,
        limit: 50,
      );
});

class PharmacyReviewsPage extends ConsumerStatefulWidget {
  const PharmacyReviewsPage({super.key});

  @override
  ConsumerState<PharmacyReviewsPage> createState() =>
      _PharmacyReviewsPageState();
}

class _PharmacyReviewsPageState extends ConsumerState<PharmacyReviewsPage> {
  String? _branchFilter;

  PharmacyReviewQuery get _query => PharmacyReviewQuery(branchId: _branchFilter);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final tenantWide = user?.isTenantWideManager == true;
    final async = ref.watch(pendingPharmacyOrdersProvider(_query));
    final timeFmt = DateFormat('dd MMM yyyy, HH:mm');

    return AppScaffold(
      title: 'Telaah Apoteker',
      body: Column(
        children: [
          if (tenantWide)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: ref.watch(stockBranchPickerOptionsProvider).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, unused) => const SizedBox.shrink(),
                    data: (branches) {
                      return DropdownButtonFormField<String?>(
                        key: ValueKey(_branchFilter),
                        initialValue: _branchFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter cabang',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua cabang'),
                          ),
                          ...branches.map(
                            (b) => DropdownMenuItem<String?>(
                              value: b['id']?.toString(),
                              child: Text(b['name']?.toString() ?? '-'),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _branchFilter = v);
                          ref.invalidate(
                            pendingPharmacyOrdersProvider(
                              PharmacyReviewQuery(branchId: v),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('$e', textAlign: TextAlign.center),
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(
                    child: Text(
                      'Tidak ada order menunggu telaah.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(pendingPharmacyOrdersProvider(_query));
                    await ref.read(pendingPharmacyOrdersProvider(_query).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final o = orders[index];
                      return Card(
                        child: ListTile(
                          onTap: () => context.push('/orders/${o.id}'),
                          leading: AppIcon3D.list(
                            icon: Icons.medical_services_outlined,
                            accentKey: o.orderNumber,
                            accent: orderStatusColor(o.status),
                          ),
                          title: Text(
                            o.orderNumber,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (tenantWide &&
                                  o.branchName != null &&
                                  o.branchName!.isNotEmpty)
                                o.branchName,
                              o.customerName ?? 'Walk-in',
                              orderStatusLabel(o.status),
                              if (o.createdAt != null)
                                timeFmt.format(o.createdAt!.toLocal()),
                            ].join(' · '),
                          ),
                          trailing: Text(
                            formatRupiah(o.total),
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
