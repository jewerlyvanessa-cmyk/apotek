import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import '../core/storage/server_url_storage.dart';
import 'router/app_router.dart';
import '../core/auth/session_guard.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import 'theme/app_theme.dart';
import '../core/network/dio_client.dart';
import '../core/network/network_online_provider.dart';
import '../shared/widgets/offline_status_banner.dart';
import '../core/offline/offline_providers.dart';
import '../core/offline/pending_actions_storage.dart';
import '../core/printing/printer_providers.dart';
import '../core/storage/token_storage.dart';
import '../core/websocket/socket_service.dart';
import '../core/notifications/push_notification_service.dart';
import '../features/notifications/presentation/providers/notification_providers.dart';

AppConfig _resolveConfig(AppFlavor flavor, SharedPreferences prefs) {
  final base = AppConfig.of(flavor);
  final custom = ServerUrlStorage(prefs).savedApiBaseUrl;
  if (custom == null || custom.isEmpty) return base;
  final apiBase = normalizeApiBaseUrl(custom);
  return AppConfig(
    flavor: base.flavor,
    apiBaseUrl: apiBase,
    wsBaseUrl: wsBaseUrlFromApi(apiBase),
    appName: base.appName,
  );
}

Future<void> bootstrap(AppFlavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  final localNotifications = FlutterLocalNotificationsPlugin();
  final pushService = PushNotificationService(localNotifications);
  await pushService.initialize();

  final prefs = await SharedPreferences.getInstance();
  const secure = FlutterSecureStorage();
  final config = _resolveConfig(flavor, prefs);
  final tokenStorage = TokenStorage(secure, prefs);
  final socketService = SocketService(config, tokenStorage);
  final pendingStorage = PendingActionsStorage(prefs);

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith((_) => config),
        tokenStorageProvider.overrideWithValue(tokenStorage),
        socketServiceProvider.overrideWithValue(socketService),
        pendingActionsStorageProvider.overrideWithValue(pendingStorage),
        prefsProvider.overrideWithValue(prefs),
        flutterLocalNotificationsProvider
            .overrideWithValue(localNotifications),
        pushNotificationServiceProvider.overrideWithValue(pushService),
      ],
      child: const ApotikFlowApp(),
    ),
  );
}

class ApotikFlowApp extends ConsumerWidget {
  const ApotikFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Attach listeners once app is running (notifications inbox)
    ref.watch(notificationListenerProvider);
    ref.watch(networkHealthWatchProvider);
    final router = ref.watch(routerProvider);
    final config = ref.watch(appConfigProvider);
    final user = ref.watch(authProvider).user;
    /// Tab browser / judul OS: cabang → tenant → nama app per lingkungan.
    final appTitle = user?.contextTitle ?? config.appName;

    SessionGuard.instance.onSessionExpired =
        () => ref.read(authProvider.notifier).sessionExpired();

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        router.go('/login');
        return;
      }
      final prevRole = previous?.user?.role;
      final nextRole = next.user?.role;
      if (next.isAuthenticated &&
          prevRole != null &&
          nextRole != null &&
          prevRole != nextRole) {
        router.go(nextRole == 'SUPER_ADMIN' ? '/platform' : '/home');
      }
    });

    final pendingOffline = ref.watch(pendingActionsCountProvider);
    final isOnline = ref.watch(networkOnlineProvider);

    return MaterialApp.router(
      title: appTitle,
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: config.flavor != AppFlavor.production,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final showOffline = !isOnline;
        final showPending = pendingOffline > 0;
        if (!showOffline && !showPending) return child ?? const SizedBox.shrink();
        return Column(
          children: [
            if (showOffline)
              OfflineStatusBanner(pendingCount: pendingOffline),
            if (showPending && isOnline)
              PendingSyncBanner(pendingCount: pendingOffline),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
