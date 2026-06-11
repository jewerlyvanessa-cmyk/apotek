import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/widgets/app_nav_list_tile.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/warehouse_branch_provider.dart';
import 'opname_page.dart';
import 'transfer_page.dart';

final _branchesForWarehouseProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminRepositoryProvider).listBranches();
});

class WarehousePage extends ConsumerWidget {
  const WarehousePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final needsPicker = ref.watch(warehouseNeedsBranchPickerProvider);
    final branchId = ref.watch(warehouseBranchIdProvider);

    if (user == null) {
      return const AppScaffold(
        title: 'Gudang',
        body: Center(child: Text('Silakan login')),
      );
    }

    if (!needsPicker && user.branchId == null) {
      return const AppScaffold(
        title: 'Gudang',
        body: Center(child: Text('Login dengan akun yang terikat cabang')),
      );
    }

    if (needsPicker && branchId == null) {
      return AppScaffold(
        title: 'Gudang',
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pilih cabang untuk stock opname dan transfer stok.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              ref.watch(_branchesForWarehouseProvider).when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (branches) {
                      if (branches.isEmpty) {
                        return const Text('Belum ada cabang');
                      }
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Cabang *',
                        ),
                        items: branches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b['id'] as String?,
                                child: Text(b['name']?.toString() ?? '-'),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id != null) {
                            ref.read(warehouseBranchIdProvider.notifier).state = id;
                          }
                        },
                      );
                    },
                  ),
            ],
          ),
        ),
      );
    }

    String? branchLabel = user.branchName;
    if (needsPicker) {
      branchLabel = ref.watch(_branchesForWarehouseProvider).maybeWhen(
        data: (list) {
          for (final b in list) {
            if (b['id']?.toString() == branchId) {
              return b['name']?.toString();
            }
          }
          return null;
        },
        orElse: () => null,
      );
    }

    final isTenantWide = user.isTenantWideManager;
    final isWarehouse = user.role == 'WAREHOUSE';

    return AppScaffold(
      title: 'Gudang',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (isTenantWide) ...[
            AppNavListTile(
              icon: Icons.local_shipping_outlined,
              title: 'Pengadaan Gudang Pusat',
              subtitle: 'Beli dari supplier → stok masuk gudang pusat',
              onTap: () => context.push('/procurements'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (isTenantWide) ...[
            AppNavListTile(
              icon: Icons.call_split,
              title: 'Distribusi ke Cabang',
              subtitle: 'Kirim stok dari gudang pusat ke cabang',
              onTap: () => context.push('/distributions'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppNavListTile(
              icon: Icons.warehouse_outlined,
              title: 'Stok Gudang Pusat',
              subtitle: 'Lihat stok di gudang pusat tenant',
              onTap: () => context.push('/stocks/central'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!isTenantWide && (user.isBranchManager || isWarehouse)) ...[
            AppNavListTile(
              icon: Icons.call_split,
              title: 'Terima Distribusi',
              subtitle: 'Konfirmasi stok masuk dari gudang pusat',
              onTap: () => context.push('/distributions'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (needsPicker && branchId != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cabang: ${branchLabel ?? branchId}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(warehouseBranchIdProvider.notifier).state = null;
                  },
                  child: const Text('Ganti'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppNavListTile(
            icon: Icons.inventory_2_outlined,
            title: 'Terima Stok',
            subtitle: 'Batch, tanggal expired, qty masuk',
            onTap: () => context.push(
              '/stocks/receive',
              extra: branchId ?? user.branchId,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _MenuCard(
            icon: Icons.fact_check_outlined,
            title: 'Stock Opname',
            subtitle: 'Input stok aktual lalu submit',
            child: OpnamePage(),
          ),
          const SizedBox(height: AppSpacing.md),
          const _MenuCard(
            icon: Icons.swap_horiz,
            title: 'Transfer Stok',
            subtitle: 'Pindah stok antar cabang',
            child: TransferPage(),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatefulWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: _open,
        onExpansionChanged: (v) => setState(() => _open = v),
        leading: AppIcon3D.list(
          icon: widget.icon,
          accentKey: widget.title,
        ),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(widget.subtitle),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
