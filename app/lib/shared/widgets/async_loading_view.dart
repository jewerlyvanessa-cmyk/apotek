import 'package:flutter/material.dart';
import '../../app/theme/app_spacing.dart';

class AsyncLoadingView extends StatelessWidget {
  const AsyncLoadingView({
    super.key,
    this.message,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final String? message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                style: const TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
