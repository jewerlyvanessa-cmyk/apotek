import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_error_message.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../data/license_repository.dart';
import '../providers/license_provider.dart';

class ActivateLicensePage extends ConsumerStatefulWidget {
  const ActivateLicensePage({super.key});

  @override
  ConsumerState<ActivateLicensePage> createState() =>
      _ActivateLicensePageState();
}

class _ActivateLicensePageState extends ConsumerState<ActivateLicensePage> {
  final _keyCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final key = _keyCtrl.text.trim();
    if (key.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kode lisensi yang valid'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(licenseRepositoryProvider).activateLicense(key);
      ref.invalidate(licenseStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lisensi berhasil diaktifkan'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _error = dioErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Aktivasi Lisensi',
      showLogout: false,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masukkan kode lisensi on-prem yang Anda terima dari vendor. '
              'Setelah aktif, Anda dapat login ke aplikasi.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Kode lisensi',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Material(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Aktifkan',
              isLoading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
