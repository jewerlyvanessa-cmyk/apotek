import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../providers/license_provider.dart';

class LicenseStatusBanner extends ConsumerWidget {
  const LicenseStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(licenseStatusProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) {
        final message = status.bannerMessage;
        if (message == null) return const SizedBox.shrink();

        final isDanger = !status.isOperational;
        final color = isDanger ? AppColors.danger : AppColors.warning;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Material(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: status.isOnPrem && !status.isOperational
                  ? () => context.push('/activate-license')
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      isDanger ? Icons.error_outline : Icons.info_outline,
                      color: color,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (status.isOnPrem && !status.isOperational)
                      Icon(Icons.chevron_right, color: color),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
