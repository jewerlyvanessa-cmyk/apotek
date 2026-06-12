import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/cash_entry_repository.dart';
import '../../domain/entities/cash_entry.dart';
import '../../../../core/network/paginated_result.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/pagination_bar.dart';

final _ledgerDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final _ledgerBranchIdProvider = StateProvider<String?>((ref) {
  return ref.watch(authProvider).user?.branchId;
});

final _ledgerBranchesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null || (!user.isOwner && !user.isTenantWideManager)) return [];
  return ref.watch(adminRepositoryProvider).listBranches();
});

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final cashierLedgerSummaryProvider =
    FutureProvider.autoDispose<CashLedgerSummary>((ref) async {
  final branchId = ref.watch(_ledgerBranchIdProvider);
  if (branchId == null) throw Exception('Pilih cabang terlebih dahulu');
  final date = ref.watch(_ledgerDateProvider);
  final iso = _isoDate(date);
  return ref.watch(cashEntryRepositoryProvider).summary(
        branchId: branchId,
        dateFrom: iso,
        dateTo: iso,
      );
});

final _ledgerPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final cashierLedgerEntriesProvider =
    FutureProvider.autoDispose<PaginatedResult<CashEntry>>((ref) async {
  final branchId = ref.watch(_ledgerBranchIdProvider);
  if (branchId == null) throw Exception('Pilih cabang terlebih dahulu');
  final date = ref.watch(_ledgerDateProvider);
  final page = ref.watch(_ledgerPageProvider);
  final iso = _isoDate(date);
  return ref.watch(cashEntryRepositoryProvider).list(
        branchId: branchId,
        dateFrom: iso,
        dateTo: iso,
        page: page,
      );
});

class CashierLedgerPage extends ConsumerWidget {
  const CashierLedgerPage({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final current = ref.read(_ledgerDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      ref.read(_ledgerDateProvider.notifier).state = DateTime(
        picked.year,
        picked.month,
        picked.day,
      );
      ref.read(_ledgerPageProvider.notifier).state = 1;
    }
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    required String type,
  }) async {
    final user = ref.read(authProvider).user;
    final branchId = ref.read(_ledgerBranchIdProvider);
    if (user == null || branchId == null) return;

    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final categories =
        type == 'CASH_IN' ? cashInCategories : cashOutCategories;
    var category = categories.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            type == 'CASH_IN' ? 'Catat uang masuk' : 'Catat uang keluar',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah (Rp)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setLocal(() => category = v);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) {
      amountCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final notes = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah harus lebih dari 0'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final iso = _isoDate(ref.read(_ledgerDateProvider));
    try {
      await ref.read(cashEntryRepositoryProvider).create(
            type: type,
            amount: amount,
            category: category,
            notes: notes.isEmpty ? null : notes,
            entryDate: iso,
            branchId: branchId,
          );
      ref.invalidate(cashierLedgerSummaryProvider);
      ref.invalidate(cashierLedgerEntriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pencatatan disimpan'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response == null) {
        await ref.read(syncManagerProvider).enqueueCashEntry(
              type: type,
              amount: amount,
              branchId: branchId,
              category: category,
              notes: notes.isEmpty ? null : notes,
              entryDate: iso,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline — pencatatan masuk antrian sinkronisasi'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _deleteEntry(BuildContext context, WidgetRef ref, CashEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pencatatan?'),
        content: Text(
          '${cashEntryTypeLabel(e.type)} ${formatRupiah(e.amount)} akan dihapus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(cashEntryRepositoryProvider).delete(e.id);
      ref.invalidate(cashierLedgerSummaryProvider);
      ref.invalidate(cashierLedgerEntriesProvider);
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(err)), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final branchId = ref.watch(_ledgerBranchIdProvider);
    final branchesAsync = ref.watch(_ledgerBranchesProvider);
    final date = ref.watch(_ledgerDateProvider);
    final summaryAsync = ref.watch(cashierLedgerSummaryProvider);
    final entriesAsync = ref.watch(cashierLedgerEntriesProvider);
    final dateLabel = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);
    final needsBranchPicker = user != null && user.branchId == null &&
        (user.isOwner || user.isTenantWideManager);

    if (user == null) {
      return const AppScaffold(
        title: 'Kas Cabang',
        body: Center(child: Text('Silakan login terlebih dahulu')),
      );
    }

    if (!needsBranchPicker && branchId == null) {
      return const AppScaffold(
        title: 'Kas Cabang',
        body: Center(child: Text('Akun harus terikat cabang')),
      );
    }

    return AppScaffold(
      title: 'Kas Cabang',
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: () => _pickDate(context, ref),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cashierLedgerSummaryProvider);
          ref.invalidate(cashierLedgerEntriesProvider);
          await ref.read(cashierLedgerSummaryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            if (needsBranchPicker)
              branchesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => AsyncErrorView.fromError(e),
                data: (branches) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: DropdownButtonFormField<String?>(
                      initialValue: branchId,
                      decoration: const InputDecoration(
                        labelText: 'Cabang',
                        border: OutlineInputBorder(),
                      ),
                      items: branches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b['id']?.toString(),
                              child: Text(b['name']?.toString() ?? '-'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        ref.read(_ledgerBranchIdProvider.notifier).state = v;
                        ref.read(_ledgerPageProvider.notifier).state = 1;
                        ref.invalidate(cashierLedgerSummaryProvider);
                        ref.invalidate(cashierLedgerEntriesProvider);
                      },
                    ),
                  );
                },
              ),
            if (branchId == null && needsBranchPicker)
              const Text('Pilih cabang untuk melihat kas.'),
            if (branchId != null) ...[
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            summaryAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
              data: (s) => _SummaryGrid(
                salesTotal: s.salesTotal,
                salesOrders: s.salesOrders,
                cashIn: s.cashIn,
                cashOut: s.cashOut,
                netTotal: s.netTotal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openForm(context, ref, type: 'CASH_IN'),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Masuk'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openForm(context, ref, type: 'CASH_OUT'),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Keluar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Riwayat pencatatan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            entriesAsync.when(
              loading: () => const AsyncLoadingView(),
              error: (e, _) => AsyncErrorView.fromError(
                e,
                onRetry: () => ref.invalidate(cashierLedgerEntriesProvider),
              ),
              data: (result) {
                if (result.items.isEmpty) {
                  return const EmptyStateView(
                    title: 'Belum ada pencatatan manual',
                    subtitle: 'Gunakan tombol Masuk/Keluar untuk mencatat kas.',
                    icon: Icons.account_balance_wallet_outlined,
                  );
                }
                return Column(
                  children: [
                    ...result.items.map((e) => _entryTile(context, ref, e)),
                    PaginationBar(
                      meta: result.meta,
                      onPageChanged: (p) =>
                          ref.read(_ledgerPageProvider.notifier).state = p,
                    ),
                  ],
                );
              },
            ),
            ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryTile(BuildContext context, WidgetRef ref, CashEntry e) {
    final color = e.isIn ? AppColors.success : AppColors.danger;
    final sign = e.isIn ? '+' : '−';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: AppIcon3D.list(
          icon: e.isIn ? Icons.arrow_downward : Icons.arrow_upward,
          accentKey: e.id,
          accent: color,
        ),
        title: Text(
          '${e.category ?? cashEntryTypeLabel(e.type)} · $sign${formatRupiah(e.amount)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (e.notes != null && e.notes!.isNotEmpty) e.notes!,
            if (e.createdByName != null) 'Oleh ${e.createdByName}',
          ].join('\n'),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: () => _deleteEntry(context, ref, e),
        ),
      ),
    );
  }
}

Widget _ledgerSummaryTile(
  String label,
  double value, {
  String? subtitle,
  Color? color,
}) {
  return Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatRupiah(value),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.salesTotal,
    required this.salesOrders,
    required this.cashIn,
    required this.cashOut,
    required this.netTotal,
  });

  final double salesTotal;
  final int salesOrders;
  final double cashIn;
  final double cashOut;
  final double netTotal;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gap = AppSpacing.sm;

        Widget tile(
          String label,
          double value, {
          String? subtitle,
          Color? color,
        }) {
          return _ledgerSummaryTile(
            label,
            value,
            subtitle: subtitle,
            color: color,
          );
        }

        final sales = tile(
          'Total penjualan',
          salesTotal,
          subtitle: '$salesOrders transaksi lunas',
          color: AppColors.primary,
        );
        final income = tile('Uang masuk', cashIn, color: AppColors.success);
        final expense = tile('Uang keluar', cashOut, color: AppColors.danger);
        final balance = tile(
          'Saldo kas hari ini',
          netTotal,
          subtitle: 'Penjualan + masuk − keluar',
          color: AppColors.primary,
        );

        if (w >= 720) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: sales),
                SizedBox(width: gap),
                Expanded(child: income),
                SizedBox(width: gap),
                Expanded(child: expense),
                SizedBox(width: gap),
                Expanded(child: balance),
              ],
            ),
          );
        }

        if (w >= 480) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: sales),
                    SizedBox(width: gap),
                    Expanded(child: income),
                  ],
                ),
              ),
              SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: expense),
                    SizedBox(width: gap),
                    Expanded(child: balance),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            sales,
            SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: income),
                  SizedBox(width: gap),
                  Expanded(child: expense),
                ],
              ),
            ),
            SizedBox(height: gap),
            balance,
          ],
        );
      },
    );
  }
}
