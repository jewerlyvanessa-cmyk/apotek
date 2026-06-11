import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/auth/biometric_auth_service.dart';
import '../../../../core/config/server_setup_visibility.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/printing/printer_providers.dart';
import '../../../../core/auth/biometric_credential_storage.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/app_text_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_brand_logo.dart';
import '../../domain/entities/auth_user.dart';
import '../../../license/presentation/providers/license_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/session_context_picker_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _biometricAvailable = false;
  bool _biometricLoggingIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBiometric());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    if (kIsWeb) return;
    final storage = ref.read(biometricCredentialStorageProvider);
    final bio = ref.read(biometricAuthServiceProvider);
    final enabled = storage.isEnabled;
    final canUse = enabled && await bio.canAuthenticate;
    if (mounted) setState(() => _biometricAvailable = canUse);
  }

  Future<void> _goHome(AuthUser user) async {
    if (!mounted) return;
    if (user.mustChangePassword) {
      context.go('/change-password');
      return;
    }
    if (user.isSuperAdmin) {
      context.go('/platform');
    } else {
      context.go('/home');
    }
  }

  Future<void> _afterLogin(AuthUser user, String email, String password) async {
    if (user.canSwitchSession) {
      final pick = await showSessionContextPickerDialog(
        context,
        user: user,
        requireChange: false,
      );
      if (!mounted) return;
      if (pick != null && pick.changedFrom(user)) {
        final ok = await ref.read(authProvider.notifier).switchSession(
              role: pick.role,
              branchId: pick.branchId,
            );
        if (!ok || !mounted) return;
        final updated = ref.read(authProvider).user;
        if (updated != null) {
          await _offerBiometricSetup(email, password);
          await _goHome(updated);
        }
        return;
      }
    }

    await _offerBiometricSetup(email, password);
    await _goHome(user);
  }

  Future<void> _offerBiometricSetup(String email, String password) async {
    if (kIsWeb) return;
    final storage = ref.read(biometricCredentialStorageProvider);
    if (storage.isEnabled) return;

    final bio = ref.read(biometricAuthServiceProvider);
    if (!await bio.canAuthenticate || !mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login biometrik'),
        content: const Text(
          'Aktifkan login dengan sidik jari / Face ID untuk masuk lebih cepat di perangkat ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
    if (enable != true) return;

    final ok = await bio.authenticate(
      reason: 'Verifikasi untuk menyimpan login biometrik',
    );
    if (!ok) return;

    await storage.enable(email: email, password: password);
    if (mounted) setState(() => _biometricAvailable = true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final user = await ref.read(authProvider.notifier).login(email, password);
    if (user == null || !mounted) return;
    await _afterLogin(user, email, password);
  }

  Future<void> _biometricLogin() async {
    if (_biometricLoggingIn) return;
    final storage = ref.read(biometricCredentialStorageProvider);
    final creds = await storage.readCredentials();
    if (creds == null) return;

    final bio = ref.read(biometricAuthServiceProvider);
    final ok = await bio.authenticate();
    if (!ok || !mounted) return;

    setState(() => _biometricLoggingIn = true);
    try {
      final user = await ref.read(authProvider.notifier).login(
            creds.email,
            creds.password,
          );
      if (user == null || !mounted) return;
      await _afterLogin(user, creds.email, creds.password);
    } finally {
      if (mounted) setState(() => _biometricLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final config = ref.watch(appConfigProvider);
    final licenseAsync = ref.watch(licenseStatusProvider);
    final showActivateLicense = licenseAsync.maybeWhen(
      data: (status) => status.needsLicenseActivation,
      orElse: () => false,
    );
    final showServerSetup = showServerSetupOnLogin(
      flavor: config.flavor,
      prefs: ref.watch(prefsProvider),
      license: licenseAsync.valueOrNull,
      licenseLoading: licenseAsync.isLoading,
    );

    return AppScaffold(
      showTitleLogo: false,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: const AppBrandLogo.login(height: 120),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Masuk ke akun apotik Anda',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Email wajib diisi' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Min. 6 karakter' : null,
                  ),
                  if (showServerSetup)
                    TextButton(
                      onPressed: () => context.push('/platform/server'),
                      child: const Text('Atur alamat server'),
                    ),
                  if (showActivateLicense)
                    TextButton(
                      onPressed: () => context.push('/activate-license'),
                      child: const Text('Aktivasi lisensi on-prem'),
                    ),
                  if (auth.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      auth.error!,
                      style: const TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    label: 'Tombol login',
                    button: true,
                    child: AppButton(
                      label: 'Login',
                      isLoading: auth.isLoading,
                      onPressed: _submit,
                    ),
                  ),
                  if (_biometricAvailable) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      label: 'Login biometrik',
                      button: true,
                      child: OutlinedButton.icon(
                      onPressed: _biometricLoggingIn || auth.isLoading
                          ? null
                          : _biometricLogin,
                      icon: _biometricLoggingIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: const Text('Login biometrik'),
                    ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
