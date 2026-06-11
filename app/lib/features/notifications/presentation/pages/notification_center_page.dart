import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../providers/notification_providers.dart';

class NotificationCenterPage extends ConsumerWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationInboxProvider);
    final notifier = ref.read(notificationInboxProvider.notifier);

    return AppScaffold(
      title: 'Notifikasi',
      actions: [
        TextButton(
          onPressed: items.isEmpty ? null : () => notifier.clear(),
          child: const Text('Clear'),
        ),
      ],
      body: items.isEmpty
          ? const Center(child: Text('Belum ada notifikasi'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final n = items[index];
                final dt = DateTime.tryParse(n.createdAtIso);
                final when = dt != null
                    ? DateFormat('dd MMM, HH:mm').format(dt.toLocal())
                    : n.createdAtIso;
                return Card(
                  child: ListTile(
                    leading: AppIcon3D.list(
                      icon: n.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      accentKey: n.id,
                      accent: n.isRead ? AppColors.textSecondary : null,
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.body),
                        const SizedBox(height: 4),
                        Text(
                          when,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'toggle') {
                          await notifier.markRead(n.id, !n.isRead);
                        } else if (v == 'delete') {
                          await notifier.remove(n.id);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(n.isRead ? 'Mark unread' : 'Mark read'),
                        ),
                        const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                    onTap: () => notifier.markRead(n.id, true),
                  ),
                );
              },
            ),
    );
  }
}

