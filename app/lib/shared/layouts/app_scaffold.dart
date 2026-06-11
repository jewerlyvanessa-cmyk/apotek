import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/providers/notification_providers.dart';
import '../widgets/app_brand_logo.dart';

/// Tab utama tanpa tombol back (gunakan bottom nav).
const _rootShellPaths = {'/home', '/platform', '/login'};

class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.leading,
    this.showBack,
    this.showNotifications = true,
    this.showLogout = true,
    this.showTitleLogo = true,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? leading;
  /// null = otomatis (pop stack atau kembali ke /home dari tab shell).
  final bool? showBack;
  final bool showNotifications;
  final bool showLogout;
  final bool showTitleLogo;

  /// Aman saat router sedang rebuild (mis. ganti role / logout).
  String? _safeMatchedLocation(BuildContext context) {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return GoRouter.maybeOf(context)
          ?.routerDelegate
          .currentConfiguration
          .uri
          .path;
    }
  }

  bool _resolveShowBack(BuildContext context) {
    if (showBack != null) return showBack!;
    if (Navigator.of(context).canPop()) return true;
    if (context.canPop()) return true;
    final path = _safeMatchedLocation(context);
    if (path == null || path.isEmpty) return false;
    return !_rootShellPaths.contains(path);
  }

  void _handleBack(BuildContext context, WidgetRef ref) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    final path = _safeMatchedLocation(context);
    if (path == null || !_rootShellPaths.contains(path)) {
      final role = ref.read(authProvider).user?.role;
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.go(role == 'SUPER_ADMIN' ? '/platform' : '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: title != null ? _buildAppBar(context, ref) : null,
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(unreadCountProvider);
    final shouldShowBack = _resolveShowBack(context);

    final barActions = <Widget>[
      ...?actions,
      if (user != null && user.role != 'SUPER_ADMIN')
        Semantics(
          label: 'Pencarian global',
          button: true,
          child: IconButton(
            tooltip: 'Cari',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ),
      if (showNotifications && user != null)
        Semantics(
          label: unread > 0
              ? 'Notifikasi, $unread belum dibaca'
              : 'Notifikasi',
          button: true,
          child: IconButton(
            tooltip: 'Notifikasi',
            icon: unread > 0
                ? Badge.count(
                    count: unread,
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ),
      if (showLogout && user != null)
        Semantics(
          label: 'Keluar dari akun',
          button: true,
          child: IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ),
    ];

    return AppBar(
      title: showTitleLogo
          ? Row(
              children: [
                const AppBrandLogo.dalam(height: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : Text(title!),
      automaticallyImplyLeading: false,
      leading: leading ??
          (shouldShowBack
              ? Semantics(
                  label: 'Kembali',
                  button: true,
                  child: IconButton(
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.textPrimary,
                    onPressed: () => _handleBack(context, ref),
                  ),
                )
              : null),
      actions: barActions.isEmpty ? null : barActions,
    );
  }
}
