import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/app_text_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../providers/auth_provider.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentCtrl.text,
          newPassword: _newCtrl.text,
        );

    if (!mounted) return;

    if (ok) {
      final user = ref.read(authProvider).user;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diperbarui'),
          backgroundColor: AppColors.success,
        ),
      );
      if (user?.isSuperAdmin == true) {
        context.go('/platform');
      } else {
        context.go('/home');
      }
      return;
    }

    setState(() {
      _busy = false;
      _error = ref.read(authProvider).error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return AppScaffold(
      title: 'Ganti Password',
      showLogout: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                user?.mustChangePassword == true
                    ? 'Untuk keamanan, ganti password default sebelum melanjutkan.'
                    : 'Perbarui password akun Anda.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (user?.email != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  user!.email,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _currentCtrl,
                label: 'Password saat ini',
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _newCtrl,
                label: 'Password baru',
                obscureText: true,
                prefixIcon: Icons.lock_reset_outlined,
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'Min. 8 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _confirmCtrl,
                label: 'Ulangi password baru',
                obscureText: true,
                prefixIcon: Icons.lock_reset_outlined,
                validator: (v) {
                  if (v != _newCtrl.text) return 'Password tidak sama';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Simpan password baru',
                isLoading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
