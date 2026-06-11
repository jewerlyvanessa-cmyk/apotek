import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/utils/role_labels.dart';

/// Returns selected role or null if cancelled.
Future<String?> showRolePickerDialog(
  BuildContext context, {
  required List<String> roles,
  String? currentRole,
  String? branchId,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Pilih peran aktif'),
      children: [
        ...roles.map(
          (r) {
            final roleLabel = RoleLabels.label(r, branchId: branchId);
            return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, r),
            child: Row(
              children: [
                if (r == (currentRole ?? roles.first))
                  const Icon(Icons.check, size: 18, color: AppColors.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roleLabel,
                        style: TextStyle(
                          fontWeight: r == (currentRole ?? roles.first)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (roleLabel != r)
                        Text(
                          r,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ],
    ),
  );
}
