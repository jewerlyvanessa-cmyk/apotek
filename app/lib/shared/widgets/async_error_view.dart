import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

String friendlyErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    final status = error.response?.statusCode;
    if (status != null) {
      return 'Permintaan gagal (HTTP $status). Periksa koneksi atau coba lagi.';
    }
  }
  final raw = error.toString();
  return raw
      .replaceFirst('Exception: ', '')
      .replaceFirst('DioException [bad response]: ', '')
      .trim();
}

class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  factory AsyncErrorView.fromError(
    Object error, {
    Key? key,
    VoidCallback? onRetry,
    EdgeInsetsGeometry? padding,
  }) {
    return AsyncErrorView(
      key: key,
      message: friendlyErrorMessage(error),
      onRetry: onRetry,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
    );
  }

  final String message;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
