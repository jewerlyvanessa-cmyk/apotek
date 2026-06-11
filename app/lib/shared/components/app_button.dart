import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(label);

    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    );

    if (variant == AppButtonVariant.outline) {
      return Semantics(
        label: label,
        button: true,
        enabled: !isLoading && onPressed != null,
        child: OutlinedButton(
          style: buttonStyle,
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      );
    }

    return Semantics(
      label: label,
      button: true,
      enabled: !isLoading && onPressed != null,
      child: ElevatedButton(
        style: buttonStyle,
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}

enum AppButtonVariant { primary, outline }
