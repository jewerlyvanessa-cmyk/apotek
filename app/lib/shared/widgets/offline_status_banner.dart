import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({
    super.key,
    this.pendingCount = 0,
  });

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade100,
      child: SafeArea(
        bottom: false,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.wifi_off, size: 20),
          title: Text(
            pendingCount > 0
                ? 'Tidak terhubung — $pendingCount aksi menunggu sinkronisasi'
                : 'Tidak terhubung ke server',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: pendingCount > 0 ? const Icon(Icons.chevron_right, size: 20) : null,
          onTap: pendingCount > 0 ? () => context.push('/pending-actions') : null,
        ),
      ),
    );
  }
}

class PendingSyncBanner extends StatelessWidget {
  const PendingSyncBanner({super.key, required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber.shade100,
      child: SafeArea(
        bottom: false,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.cloud_upload_outlined, size: 20),
          title: Text(
            'Antrian offline — $pendingCount aksi menunggu sinkronisasi',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/pending-actions'),
        ),
      ),
    );
  }
}
