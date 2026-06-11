import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/offline/pending_action.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';

class PendingActionsPage extends ConsumerStatefulWidget {
  const PendingActionsPage({super.key});

  @override
  ConsumerState<PendingActionsPage> createState() => _PendingActionsPageState();
}

class _PendingActionsPageState extends ConsumerState<PendingActionsPage> {
  bool _busy = false;

  Future<void> _syncAll() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(syncManagerProvider).processQueue(max: 50);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync: ${result.succeeded} sukses, ${result.failed} gagal, ${result.conflicts} konflik, sisa ${result.remaining}',
            ),
          ),
        );
      }
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryOne(String id) async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(syncManagerProvider).processOne(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Retry sukses' : 'Retry gagal (cek koneksi / server)'),
          ),
        );
      }
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(pendingActionsStorageProvider);
    final items = storage.getAll();

    return AppScaffold(
      title: 'Pending Sync',
      actions: [
        TextButton(
          onPressed: _busy || items.isEmpty ? null : _syncAll,
          child: _busy ? const Text('...') : const Text('Sync all'),
        ),
      ],
      body: items.isEmpty
          ? const Center(child: Text('Tidak ada pending actions'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final a = items[index];
                final statusColor = switch (a.status) {
                  'CONFLICT' => AppColors.danger,
                  'FAILED' => Colors.orange,
                  _ => AppColors.primary,
                };
                return Card(
                  child: ListTile(
                    leading: AppIcon3D.list(
                      icon: a.type == 'PAY_ORDER'
                          ? Icons.payments_outlined
                          : Icons.receipt_long_outlined,
                      accentKey: a.id,
                      accent: statusColor,
                    ),
                    title: Text(_titleOf(a)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.createdAtIso),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _StatusChip(status: a.status, color: statusColor),
                            if (a.attempts > 0)
                              Chip(
                                label: Text('attempt ${a.attempts}'),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (a.lastHttpStatus != null)
                              Chip(
                                label: Text('HTTP ${a.lastHttpStatus}'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        if (a.lastError != null && a.lastError!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              a.lastError!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'retry') {
                          await _retryOne(a.id);
                        } else if (v == 'delete') {
                          await storage.removeById(a.id);
                          setState(() {});
                        } else if (v == 'done') {
                          await storage.removeById(a.id);
                          setState(() {});
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'retry', child: Text('Retry')),
                        if (a.status != 'QUEUED')
                          const PopupMenuItem(
                            value: 'done',
                            child: Text('Tandai selesai'),
                          ),
                        const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _titleOf(PendingAction a) {
    switch (a.type) {
      case 'CREATE_ORDER':
        return 'Create order (${(a.payload['items'] as List?)?.length ?? 0} item)';
      case 'PAY_ORDER':
        return 'Pay order (${a.payload['order_id'] ?? '-'})';
      case 'ADJUST_STOCK':
        return 'Adjust stock (${a.payload['medicine_id'] ?? '-'})';
      case 'STOCK_MUTATION':
        return 'Stock mutation (${a.payload['movement_type'] ?? '-'})';
      default:
        return a.type;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'CONFLICT' => 'KONFLIK',
      'FAILED' => 'GAGAL',
      _ => 'ANTRI',
    };
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

