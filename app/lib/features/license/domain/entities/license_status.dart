class LicenseStatus {
  const LicenseStatus({
    required this.deploymentMode,
    this.installationValid,
    this.installationMessage,
    this.installationCustomer,
    this.installationType,
    this.installationPlan,
    this.installationMaxBranches,
    this.installationExpiresAt,
    this.tenantValid,
    this.tenantPlan,
    this.tenantExpiresAt,
    this.tenantDaysRemaining,
    this.tenantInGracePeriod = false,
    this.tenantMessage,
  });

  final String deploymentMode;
  final bool? installationValid;
  final String? installationMessage;
  final String? installationCustomer;
  final String? installationType;
  final String? installationPlan;
  final int? installationMaxBranches;
  final String? installationExpiresAt;
  final bool? tenantValid;
  final String? tenantPlan;
  final String? tenantExpiresAt;
  final int? tenantDaysRemaining;
  final bool tenantInGracePeriod;
  final String? tenantMessage;

  bool get isOnPrem => deploymentMode == 'on_prem';
  bool get isSaas => !isOnPrem;

  /// Tampilkan tautan/halaman aktivasi (on-prem, lisensi belum aktif).
  bool get needsLicenseActivation =>
      isOnPrem && installationValid != true;

  bool get isOperational {
    if (isOnPrem) return installationValid ?? false;
    if (tenantValid != null) return tenantValid!;
    return true;
  }

  bool get shouldWarn {
    if (isOnPrem) return installationValid == false;
    if (tenantInGracePeriod) return true;
    if (tenantDaysRemaining != null &&
        tenantValid == true &&
        tenantDaysRemaining! <= 14) {
      return true;
    }
    return tenantValid == false;
  }

  String? get bannerMessage {
    if (isOnPrem) {
      if (installationValid == false) {
        return installationMessage ?? 'Lisensi instalasi belum aktif';
      }
      return null;
    }
    if (tenantValid == false) {
      return tenantMessage ?? 'Langganan tidak aktif';
    }
    if (tenantInGracePeriod) {
      return tenantMessage ?? 'Langganan dalam masa tenggang';
    }
    if (tenantDaysRemaining != null && tenantDaysRemaining! <= 14) {
      return 'Langganan berakhir dalam ${tenantDaysRemaining!} hari';
    }
    return null;
  }

  factory LicenseStatus.fromJson(Map<String, dynamic> json) {
    final install = json['installation'] as Map<String, dynamic>?;
    final tenant = json['tenant'] as Map<String, dynamic>?;
    return LicenseStatus(
      deploymentMode: json['deployment_mode']?.toString() ?? 'saas',
      installationValid: install?['valid'] as bool?,
      installationMessage: install?['message']?.toString(),
      installationCustomer: install?['customer']?.toString(),
      installationType: install?['type']?.toString(),
      installationPlan: install?['plan']?.toString(),
      installationMaxBranches: (install?['max_branches'] as num?)?.toInt(),
      installationExpiresAt: install?['expires_at']?.toString(),
      tenantValid: tenant?['valid'] as bool?,
      tenantPlan: tenant?['plan']?.toString(),
      tenantExpiresAt: tenant?['expires_at']?.toString(),
      tenantDaysRemaining: (tenant?['days_remaining'] as num?)?.toInt(),
      tenantInGracePeriod: tenant?['in_grace_period'] == true,
      tenantMessage: tenant?['message']?.toString(),
    );
  }
}
