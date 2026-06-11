import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../data/billing_repository.dart';
import '../../domain/entities/billing_plan.dart';
import '../../domain/entities/renewal_intent.dart';

class SaasRenewalSection extends ConsumerStatefulWidget {
  const SaasRenewalSection({
    super.key,
    required this.currentPlan,
  });

  final String? currentPlan;

  @override
  ConsumerState<SaasRenewalSection> createState() => _SaasRenewalSectionState();
}

class _SaasRenewalSectionState extends ConsumerState<SaasRenewalSection> {
  String? _selectedPlan;
  bool _loadingPlans = true;
  bool _submitting = false;
  String? _plansError;
  List<BillingPlan> _plans = const [];

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.currentPlan;
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loadingPlans = true;
      _plansError = null;
    });
    try {
      final plans = await ref.read(billingRepositoryProvider).listPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loadingPlans = false;
        if (_selectedPlan == null && plans.isNotEmpty) {
          _selectedPlan = plans.first.id;
        } else if (_selectedPlan != null &&
            plans.every((p) => p.id != _selectedPlan)) {
          _selectedPlan = plans.isNotEmpty ? plans.first.id : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plansError = e.toString();
        _loadingPlans = false;
      });
    }
  }

  Future<void> _createIntent() async {
    if (_selectedPlan == null) return;
    setState(() => _submitting = true);
    try {
      final intent = await ref
          .read(billingRepositoryProvider)
          .createRenewalIntent(plan: _selectedPlan);
      if (!mounted) return;
      await _showIntentDialog(intent);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat referensi: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showIntentDialog(RenewalIntent intent) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Referensi perpanjangan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogRow('Referensi', intent.reference),
              _dialogRow('Paket', intent.planLabel),
              _dialogRow('Perpanjangan', '${intent.extendDays} hari'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                intent.instructions,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: intent.reference));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Referensi disalin')),
              );
            },
            child: const Text('Salin referensi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPlans) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_plansError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Billing tidak tersedia: $_plansError',
            style: const TextStyle(color: AppColors.danger),
          ),
          TextButton(onPressed: _loadPlans, child: const Text('Coba lagi')),
        ],
      );
    }

    if (_plans.isEmpty) {
      return const Text('Tidak ada paket langganan tersedia.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedPlan),
          initialValue: _selectedPlan,
          decoration: const InputDecoration(
            labelText: 'Paket perpanjangan',
            border: OutlineInputBorder(),
          ),
          items: _plans
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.label} — ${p.description}'),
                ),
              )
              .toList(),
          onChanged: _submitting
              ? null
              : (v) => setState(() => _selectedPlan = v),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _submitting || _selectedPlan == null ? null : _createIntent,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.payment_outlined),
          label: Text(_submitting ? 'Memproses…' : 'Buat referensi pembayaran'),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Setelah pembayaran berhasil, gateway memanggil webhook API '
          'dan langganan diperpanjang otomatis.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
