import 'package:flutter/material.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/paginated_result.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.meta,
    required this.onPageChanged,
    this.isLoading = false,
  });

  final PaginatedMeta meta;
  final ValueChanged<int> onPageChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (meta.total <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Halaman sebelumnya',
            onPressed: isLoading || !meta.hasPrev
                ? null
                : () => onPageChanged(meta.page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Halaman ${meta.page} / ${meta.lastPage} · ${meta.total} item',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            tooltip: 'Halaman berikutnya',
            onPressed: isLoading || !meta.hasNext
                ? null
                : () => onPageChanged(meta.page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
