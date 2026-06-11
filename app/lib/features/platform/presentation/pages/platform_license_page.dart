import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../data/platform_repository.dart';

final _licenseTenantsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final result = await ref.watch(platformRepositoryProvider).listTenants(
        limit: 100,
      );
  return result.items;
});

final _licensePlansProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(platformRepositoryProvider).listLicensePlans();
});

class PlatformLicensePage extends ConsumerStatefulWidget {
  const PlatformLicensePage({super.key});

  @override
  ConsumerState<PlatformLicensePage> createState() =>
      _PlatformLicensePageState();
}

class _PlatformLicensePageState extends ConsumerState<PlatformLicensePage> {
  final _customerCtrl = TextEditingController();
  final _maxBranchesCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();

  String _type = 'perpetual';
  String? _tenantId;
  String _planId = 'single';
  bool _lockToTenant = true;
  bool _generating = false;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _plans = [];

  @override
  void dispose() {
    _customerCtrl.dispose();
    _maxBranchesCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _tenants = [];

  bool get _isSubscription => _type == 'subscription';

  bool get _isCustomPlan => _planId == 'custom';

  List<Map<String, dynamic>> _plansForType(Map<String, dynamic> catalog) {
    final key = _isSubscription ? 'subscription_plans' : 'perpetual_plans';
    final raw = catalog[key] as List<dynamic>? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Map<String, dynamic>? _planById(String id) {
    for (final p in _plans) {
      if (p['id']?.toString() == id) return p;
    }
    return null;
  }

  void _applyPlan(String planId) {
    final plan = _planById(planId);
    if (plan == null || planId == 'custom') return;
    final maxBranches = plan['max_branches'];
    final days = plan['days'];
    if (maxBranches != null) {
      _maxBranchesCtrl.text = maxBranches.toString();
    }
    if (_isSubscription && days != null) {
      _daysCtrl.text = days.toString();
    } else if (!_isSubscription) {
      _daysCtrl.clear();
    }
  }

  String? _tenantCodeFor(String? tenantId) {
    if (tenantId == null) return null;
    for (final t in _tenants) {
      if (t['id']?.toString() == tenantId) {
        return t['code']?.toString();
      }
    }
    return null;
  }

  List<Widget> _payloadSummaryRows(Map<String, dynamic> payload) {
    String fmt(String key) {
      final labels = {
        'type': 'Tipe',
        'customer': 'Pelanggan',
        'plan': 'Paket',
        'tenant_locked': 'Kunci tenant',
        'tenant_code': 'Kode tenant',
        'max_branches': 'Maks. cabang',
        'issued_at': 'Diterbitkan',
        'expires_at': 'Berlaku hingga',
      };
      return labels[key] ?? key;
    }

    String val(String key, dynamic raw) {
      if (raw == null) return '—';
      if (key == 'type') {
        return raw == 'subscription' ? 'Berlangganan' : 'Beli putus';
      }
      if (key == 'plan') {
        final plan = _planById(raw.toString());
        return plan?['label']?.toString() ?? raw.toString();
      }
      if (key == 'tenant_locked') return raw == true ? 'Ya' : 'Tidak';
      if (key == 'issued_at' || key == 'expires_at') {
        final dt = DateTime.tryParse(raw.toString());
        if (dt != null) {
          return '${dt.day.toString().padLeft(2, '0')}/'
              '${dt.month.toString().padLeft(2, '0')}/'
              '${dt.year}';
        }
      }
      return raw.toString();
    }

    final rows = <Widget>[];
    for (final e in payload.entries) {
      if (e.value == null) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('${fmt(e.key)}: ${val(e.key, e.value)}'),
        ),
      );
    }
    if (payload['tenant_locked'] != true) {
      rows.add(
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Lisensi berlaku untuk semua tenant (tidak dikunci).',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    return rows;
  }

  Future<void> _generate() async {
    final customer = _customerCtrl.text.trim();
    if (customer.length < 2) {
      _showError('Nama pelanggan wajib diisi');
      return;
    }
    if (_lockToTenant && (_tenantId == null || _tenantId!.isEmpty)) {
      _showError('Pilih tenant untuk mengunci lisensi');
      return;
    }
    if (_isCustomPlan) {
      final maxBranches = int.tryParse(_maxBranchesCtrl.text.trim());
      if (maxBranches == null || maxBranches < 1) {
        _showError('Maks. cabang wajib diisi untuk paket kustom');
        return;
      }
      if (_isSubscription) {
        final days = int.tryParse(_daysCtrl.text.trim());
        if (days == null || days < 1) {
          _showError('Masa berlaku (hari) wajib diisi untuk paket kustom');
          return;
        }
      }
    }

    setState(() {
      _generating = true;
      _result = null;
    });

    try {
      final maxBranches = int.tryParse(_maxBranchesCtrl.text.trim());
      final days = _isSubscription ? int.tryParse(_daysCtrl.text.trim()) : null;
      final data = await ref.read(platformRepositoryProvider).generateLicense(
            customer: customer,
            type: _type,
            plan: _isCustomPlan ? null : _planId,
            tenantId: _lockToTenant ? _tenantId : null,
            maxBranches: maxBranches,
            days: days,
          );
      if (mounted) setState(() => _result = data);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  Future<void> _copyKey() async {
    final key = _result?['license_key']?.toString();
    if (key == null || key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode lisensi disalin'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _planSelector(List<Map<String, dynamic>> plans) {
    _plans = plans;
    if (_planId != 'custom' && !_plans.any((p) => p['id'] == _planId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _planId = plans.first['id']?.toString() ??
                (_isSubscription ? 'starter' : 'single');
            _applyPlan(_planId);
          });
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSubscription ? 'Paket berlangganan' : 'Paket beli putus',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...plans.map((plan) {
          final id = plan['id']?.toString() ?? '';
          final selected = _planId == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  _planId = id;
                  _applyPlan(id);
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan['label']?.toString() ?? id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (plan['description'] != null)
                              Text(
                                plan['description'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(_licenseTenantsProvider);
    final plansAsync = ref.watch(_licensePlansProvider);

    return AppScaffold(
      title: 'Buat Kode Lisensi',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Generate lisensi on-prem untuk pelanggan. '
            'Beli putus = tanpa kedaluwarsa. Berlangganan = masa berlaku terisi dari paket. '
            'Kirim kode ke pembeli untuk diaktifkan di halaman Aktivasi Lisensi.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _customerCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama pelanggan / perusahaan *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Tipe lisensi',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'perpetual',
                child: Text('Beli putus (perpetual)'),
              ),
              DropdownMenuItem(
                value: 'subscription',
                child: Text('Berlangganan (on-prem)'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _type = v;
                _planId = v == 'subscription' ? 'starter' : 'single';
                _maxBranchesCtrl.clear();
                _daysCtrl.clear();
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          plansAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Gagal memuat paket: $e'),
            data: (catalog) => _planSelector(_plansForType(catalog)),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kunci ke tenant tertentu'),
            subtitle: const Text(
              'Aktifkan dan pilih tenant agar kode tenant terisi di lisensi',
            ),
            value: _lockToTenant,
            onChanged: (v) => setState(() {
              _lockToTenant = v;
              if (!v) _tenantId = null;
            }),
          ),
          if (_lockToTenant) ...[
            tenantsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Gagal memuat tenant: $e'),
              data: (tenants) {
                if (tenants.isEmpty) {
                  return const Text('Belum ada tenant');
                }
                _tenants = tenants;
                if (_tenantId == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(
                        () => _tenantId = tenants.first['id']?.toString(),
                      );
                    }
                  });
                }
                final selectedCode = _tenantCodeFor(_tenantId);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey(_tenantId),
                      initialValue: _tenantId,
                  decoration: const InputDecoration(
                    labelText: 'Tenant',
                    border: OutlineInputBorder(),
                  ),
                  items: tenants
                      .map(
                        (t) => DropdownMenuItem(
                          value: t['id']?.toString(),
                          child: Text(
                            '${t['name']} (${t['code']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                      onChanged: (id) => setState(() => _tenantId = id),
                    ),
                    if (selectedCode != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kode tenant: $selectedCode',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_isCustomPlan) ...[
            TextField(
              controller: _maxBranchesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maks. cabang *',
                border: OutlineInputBorder(),
              ),
            ),
            if (_isSubscription) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Masa berlaku (hari) *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ] else ...[
            Builder(
              builder: (context) {
                final plan = _planById(_planId);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ringkasan paket ${plan?['label'] ?? _planId}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Maks. cabang: ${plan?['max_branches'] ?? 'Tidak dibatasi'}',
                        ),
                        Text(
                          _isSubscription
                              ? 'Masa berlaku: ${plan?['days'] ?? '—'} hari'
                              : 'Masa berlaku: Selamanya',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _generating ? 'Membuat...' : 'Generate Kode Lisensi',
            isLoading: _generating,
            onPressed: _generating ? null : _generate,
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kode lisensi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      _result!['license_key']?.toString() ?? '-',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_result!['payload'] is Map) ...[
                      ..._payloadSummaryRows(
                        Map<String, dynamic>.from(
                          _result!['payload'] as Map,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _copyKey,
                      icon: const Icon(Icons.copy),
                      label: const Text('Salin kode'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
