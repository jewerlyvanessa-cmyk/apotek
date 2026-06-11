import 'dev_api_host.dart';

enum AppFlavor { dev, staging, production }

class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.appName,
  });

  final AppFlavor flavor;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String appName;

  static AppConfig of(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.dev:
        return AppConfig(
          flavor: AppFlavor.dev,
          apiBaseUrl: devApiBaseUrl(),
          wsBaseUrl: devWsBaseUrl(),
          appName: 'ApotikFlow Dev',
        );
      case AppFlavor.staging:
        return const AppConfig(
          flavor: AppFlavor.staging,
          apiBaseUrl: 'https://staging-api.apotikflow.com/api/v1',
          wsBaseUrl: 'https://staging-api.apotikflow.com',
          appName: 'ApotikFlow Staging',
        );
      case AppFlavor.production:
        return const AppConfig(
          flavor: AppFlavor.production,
          apiBaseUrl: 'https://api.apotikflow.com/api/v1',
          wsBaseUrl: 'https://api.apotikflow.com',
          appName: 'ApotikFlow',
        );
    }
  }
}
