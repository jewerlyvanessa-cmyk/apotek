import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../data/platform_repository.dart';

class TenantFormPage extends ConsumerStatefulWidget {
  const TenantFormPage({super.key, this.tenantId});

  final String? tenantId;

  bool get isEdit => tenantId != null;

  @override
  ConsumerState<TenantFormPage> createState() => _TenantFormPageState();
}

const _saasPlanIds = {'starter', 'professional', 'enterprise'};

const _saasPlanLabels = {
  'starter': 'Starter',
  'professional': 'Professional',
  'enterprise': 'Enterprise',
};

class _TenantFormPageState extends ConsumerState<TenantFormPage> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerEmailCtrl = TextEditingController();
  final _ownerPasswordCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _centralNameCtrl = TextEditingController(text: 'Gudang Pusat');
  final _centralCodeCtrl = TextEditingController(text: 'PUSAT');
  bool _isActive = true;
  bool _createCentral = true;
  bool _loading = false;
  bool _loaded = false;
  bool _showProvisionOwner = false;
  int _userCount = 0;
  String _extendPlanId = 'starter';
  Map<String, dynamic>? _owner;
  bool _canDeletePermanently = false;
  List<String> _deleteBlockers = const [];

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _planCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _ownerPasswordCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _centralNameCtrl.dispose();
    _centralCodeCtrl.dispose();
    super.dispose();
  }

  String _normalizeSaasPlanId(String? raw) {
    final id = raw?.trim() ?? '';
    if (_saasPlanIds.contains(id)) return id;
    return 'starter';
  }

  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await ref
          .read(platformRepositoryProvider)
          .getTenant(widget.tenantId!);
      _nameCtrl.text = t['name']?.toString() ?? '';
      _codeCtrl.text = t['code']?.toString() ?? '';
      _phoneCtrl.text = t['phone']?.toString() ?? '';
      _emailCtrl.text = t['email']?.toString() ?? '';
      _addressCtrl.text = t['address']?.toString() ?? '';
      final plan = t['subscriptionPlan']?.toString() ??
          t['subscription_plan']?.toString() ??
          '';
      _planCtrl.text = plan;
      _extendPlanId = _normalizeSaasPlanId(plan);
      _isActive = t['isActive'] == true || t['is_active'] == true;
      _userCount = (t['_count'] as Map?)?['users'] as int? ?? 0;
      _owner = _parseOwner(t);
      _canDeletePermanently =
          t['canDeletePermanently'] == true || t['can_delete_permanently'] == true;
      final blockers = t['deleteBlockers'] ?? t['delete_blockers'];
      _deleteBlockers = blockers is List
          ? blockers.map((e) => e.toString()).toList()
          : const [];
      _loaded = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _extendSubscription() async {
    if (!widget.isEdit) return;
    setState(() => _loading = true);
    try {
      await ref.read(platformRepositoryProvider).extendTenantSubscription(
            tenantId: widget.tenantId!,
            plan: _extendPlanId,
            extendDays: 365,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Langganan diperpanjang 1 tahun'),
            backgroundColor: AppColors.success,
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTenant() async {
    if (!widget.isEdit || widget.tenantId == null) return;
    final name = _nameCtrl.text.trim().isEmpty ? 'tenant ini' : _nameCtrl.text.trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus tenant?'),
        content: Text(
          _canDeletePermanently
              ? 'Tenant "$name" tidak memiliki cabang, user, obat, order, atau stok. '
                  'Akan dihapus permanen dari database (termasuk tipe produk default). '
                  'Tindakan ini tidak dapat dibatalkan.'
              : 'Tenant "$name" masih memiliki ${_deleteBlockers.join(', ')}. '
                  '${_isActive ? 'Tenant akan dinonaktifkan beserta user dan cabangnya. ' : ''}'
                  'Data bisnis tetap tersimpan'
                  '${_isActive ? ' dan dapat diaktifkan kembali lewat switch "Tenant aktif"' : ''}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final result =
          await ref.read(platformRepositoryProvider).deleteTenant(widget.tenantId!);
      if (mounted) {
        final msg = result['_apiMessage']?.toString() ??
            (result['permanent'] == true
                ? 'Tenant dihapus permanen'
                : 'Tenant dinonaktifkan');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _provisionOwner() async {
    final fullName = _ownerNameCtrl.text.trim();
    final email = _ownerEmailCtrl.text.trim();
    final password = _ownerPasswordCtrl.text;
    if (fullName.isEmpty || !email.contains('@') || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama, email valid, dan password min. 6 karakter'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(platformRepositoryProvider).provisionOwner(
            tenantId: widget.tenantId!,
            fullName: fullName,
            email: email,
            password: password,
            phone: _ownerPhoneCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun owner dibuat'),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
      if (!mounted) return;
      setState(() => _showProvisionOwner = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (name.isEmpty || (!widget.isEdit && code.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama dan kode wajib diisi'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!widget.isEdit) {
      final ownerName = _ownerNameCtrl.text.trim();
      final ownerEmail = _ownerEmailCtrl.text.trim();
      final ownerPassword = _ownerPasswordCtrl.text;
      if (ownerName.isEmpty || !ownerEmail.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data owner wajib diisi (nama & email)'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (ownerPassword.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password owner minimal 6 karakter'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final repo = ref.read(platformRepositoryProvider);
      if (widget.isEdit) {
        await repo.updateTenant(
          id: widget.tenantId!,
          name: name,
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          subscriptionPlan: _extendPlanId,
          isActive: _isActive,
        );
      } else {
        await repo.createTenant(
          name: name,
          code: code,
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          subscriptionPlan: _extendPlanId,
          createCentralWarehouse: _createCentral,
          centralBranchName: _centralNameCtrl.text.trim(),
          centralBranchCode: _centralCodeCtrl.text.trim(),
          ownerFullName: _ownerNameCtrl.text.trim(),
          ownerEmail: _ownerEmailCtrl.text.trim(),
          ownerPassword: _ownerPasswordCtrl.text,
          ownerPhone: _ownerPhoneCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Tenant diperbarui'
                : 'Tenant, gudang pusat, dan owner dibuat',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _parseOwner(Map<String, dynamic> tenant) {
    final owner = tenant['owner'];
    if (owner is Map) return Map<String, dynamic>.from(owner);
    final owners = tenant['owners'];
    if (owners is List && owners.isNotEmpty && owners.first is Map) {
      return Map<String, dynamic>.from(owners.first as Map);
    }
    return null;
  }

  Widget _ownerInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit && !_loaded && _loading) {
      return const AppScaffold(
        title: 'Edit Tenant',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: widget.isEdit ? 'Edit Tenant' : 'Tenant Baru',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _sectionTitle('Data tenant'),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nama tenant'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _codeCtrl,
            readOnly: widget.isEdit,
            decoration: const InputDecoration(labelText: 'Kode tenant'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Telepon'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email tenant'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Alamat'),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _extendPlanId,
            decoration: const InputDecoration(labelText: 'Paket langganan'),
            items: _saasPlanIds
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(_saasPlanLabels[id] ?? id),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _extendPlanId = v;
                _planCtrl.text = v;
              });
            },
          ),
          if (!widget.isEdit) ...[
            const SizedBox(height: AppSpacing.lg),
            _sectionTitle('Gudang pusat'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Buat gudang pusat otomatis'),
              subtitle: const Text(
                'Diperlukan untuk pengadaan & distribusi stok',
                style: TextStyle(fontSize: 12),
              ),
              value: _createCentral,
              onChanged: (v) => setState(() => _createCentral = v),
            ),
            if (_createCentral) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _centralNameCtrl,
                decoration: const InputDecoration(labelText: 'Nama gudang'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _centralCodeCtrl,
                decoration: const InputDecoration(labelText: 'Kode cabang'),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _sectionTitle('Akun owner (wajib)'),
            const Text(
              'Owner mengelola tenant & menambah user/cabang lain.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _ownerNameCtrl,
              decoration: const InputDecoration(labelText: 'Nama lengkap owner'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _ownerEmailCtrl,
              decoration: const InputDecoration(labelText: 'Email login owner'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _ownerPasswordCtrl,
              decoration: const InputDecoration(labelText: 'Password awal'),
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _ownerPhoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Telepon owner (opsional)',
              ),
            ),
          ],
          if (widget.isEdit) ...[
            const SizedBox(height: AppSpacing.lg),
            _sectionTitle('Akun owner'),
            if (_owner != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ownerInfoRow(
                        'Nama',
                        _owner!['fullName']?.toString() ??
                            _owner!['full_name']?.toString() ??
                            '—',
                      ),
                      _ownerInfoRow(
                        'Email',
                        _owner!['email']?.toString() ?? '—',
                      ),
                      if ((_owner!['phone']?.toString() ?? '').isNotEmpty)
                        _ownerInfoRow(
                          'Telepon',
                          _owner!['phone']!.toString(),
                        ),
                      _ownerInfoRow(
                        'Status',
                        _owner!['isActive'] == true ||
                                _owner!['is_active'] == true
                            ? 'Aktif'
                            : 'Nonaktif',
                        valueColor:
                            _owner!['isActive'] == true ||
                                    _owner!['is_active'] == true
                                ? AppColors.success
                                : AppColors.danger,
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              const Text(
                'Belum ada akun owner untuk tenant ini.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: AppSpacing.lg),
            _sectionTitle('Langganan SaaS'),
            if (_planCtrl.text.isNotEmpty &&
                !_saasPlanIds.contains(_planCtrl.text.trim()))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Paket saat ini di database: ${_planCtrl.text.trim()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _normalizeSaasPlanId(_extendPlanId),
              decoration: const InputDecoration(
                labelText: 'Paket berlangganan',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'starter', child: Text('Starter')),
                DropdownMenuItem(
                  value: 'professional',
                  child: Text('Profesional'),
                ),
                DropdownMenuItem(
                  value: 'enterprise',
                  child: Text('Enterprise'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _extendPlanId = v);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _loading ? null : _extendSubscription,
              icon: const Icon(Icons.update),
              label: const Text('Perpanjang 1 tahun'),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tenant aktif'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                final name = Uri.encodeComponent(_nameCtrl.text.trim());
                context.push(
                  '/platform/tenants/${widget.tenantId}/branches?name=$name',
                );
              },
              icon: const Icon(Icons.store),
              label: const Text('Kelola cabang (Super Admin)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _sectionTitle('Akses user'),
            Text(
              'User terdaftar: $_userCount',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_owner == null && _showProvisionOwner) ...[
              TextField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(labelText: 'Nama owner'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _ownerEmailCtrl,
                decoration: const InputDecoration(labelText: 'Email owner'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _ownerPasswordCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _showProvisionOwner = false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : _provisionOwner,
                      child: const Text('Buat owner'),
                    ),
                  ),
                ],
              ),
            ] else if (_owner == null)
              OutlinedButton.icon(
                onPressed: () => setState(() => _showProvisionOwner = true),
                icon: const Icon(Icons.person_add),
                label: const Text('Tambah akun owner'),
              ),
          ],
          if (widget.isEdit && (_isActive || _canDeletePermanently)) ...[
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Zona berbahaya',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _loading ? null : _deleteTenant,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus tenant'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: widget.isEdit ? 'Simpan' : 'Buat tenant & owner',
            isLoading: _loading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
