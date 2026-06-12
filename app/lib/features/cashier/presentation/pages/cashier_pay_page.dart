import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/printing/printer_providers.dart';
import '../../../../core/printing/thermal_printer_settings.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../order/data/order_repository.dart';
import '../../../order/presentation/providers/order_list_provider.dart';
import '../../../payment/data/payment_repository.dart';
import '../../../payment/presentation/providers/payment_providers.dart';

class CashierPayPage extends ConsumerStatefulWidget {
  const CashierPayPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<CashierPayPage> createState() => _CashierPayPageState();
}

const _cashDenominations = <int>[
  100000,
  50000,
  20000,
  10000,
  5000,
  2000,
  1000,
  500,
];

class _CashierPayPageState extends ConsumerState<CashierPayPage> {
  String? _method;
  String? _method2;
  bool _splitMode = false;
  bool _splitAmount2Manual = false;
  final _receivedController = TextEditingController();
  final _splitAmount1Ctrl = TextEditingController();
  final _splitAmount2Ctrl = TextEditingController();
  XFile? _proofFile;
  String? _proofUrl;
  bool _paying = false;
  bool _uploadingProof = false;

  @override
  void dispose() {
    _receivedController.dispose();
    _splitAmount1Ctrl.dispose();
    _splitAmount2Ctrl.dispose();
    super.dispose();
  }

  int _parseRupiah(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _addCashDenomination(int amount) {
    if (_paying) return;
    final next = _parseRupiah(_receivedController.text) + amount;
    _receivedController.text = next.toString();
    setState(() {});
  }

  void _resetReceived() {
    if (_paying) return;
    _receivedController.clear();
    setState(() {});
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() {
      _proofFile = file;
      _proofUrl = null;
      _uploadingProof = true;
    });

    try {
      final url = await ref.read(paymentRepositoryProvider).uploadProof(file);
      if (!mounted) return;
      setState(() {
        _proofUrl = url;
        _uploadingProof = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _proofFile = null;
        _uploadingProof = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal unggah bukti: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _submitPay() async {
    final order = ref.read(orderDetailProvider(widget.orderId)).valueOrNull;
    if (order == null || _paying) return;
    if (!_splitMode && _method == null) return;
    if (_splitMode && (_method == null || _method2 == null)) return;

    final total = order.total.round();
    double? amountReceived;
    String? proofImageUrl;
    List<Map<String, dynamic>>? splits;

    if (_splitMode) {
      final a1 = _parseRupiah(_splitAmount1Ctrl.text);
      final a2 = _parseRupiah(_splitAmount2Ctrl.text);
      if (a1 <= 0 || a2 <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Isi nominal kedua metode pembayaran'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (a1 + a2 != total) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Total campuran (${formatRupiah((a1 + a2).toDouble())}) harus ${formatRupiah(order.total)}',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (_method == 'CASH') {
        amountReceived = _parseRupiah(_receivedController.text).toDouble();
        if (amountReceived < a1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uang tunai kurang dari nominal baris tunai'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      }
      final needsProof = _method == 'QRIS' ||
          _method == 'TRANSFER' ||
          _method2 == 'QRIS' ||
          _method2 == 'TRANSFER';
      if (needsProof && (_proofUrl == null || _proofUrl!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unggah bukti untuk metode QRIS/transfer'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      splits = [
        _splitLine(
          method: _method!,
          amount: a1,
          amountReceived: _method == 'CASH' ? amountReceived?.round() : null,
          proofUrl: _proofUrl,
        ),
        _splitLine(
          method: _method2!,
          amount: a2,
          amountReceived: _method2 == 'CASH' && _method != 'CASH' ? a2 : null,
          proofUrl: _proofUrl,
        ),
      ];
    } else if (_method == 'CASH') {
      amountReceived = _parseRupiah(_receivedController.text).toDouble();
      if (amountReceived < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uang diterima harus minimal sama dengan total'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    } else if (_method == 'QRIS' || _method == 'TRANSFER') {
      if (_proofUrl == null || _proofUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unggah foto bukti pembayaran terlebih dahulu'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      proofImageUrl = _proofUrl;
    }

    setState(() => _paying = true);
    try {
      await ref.read(orderRepositoryProvider).payOrder(
            orderId: order.id,
            paymentMethod: _method ?? 'CASH',
            amount: order.total,
            amountReceived: amountReceived,
            proofImageUrl: proofImageUrl,
            splits: splits,
          );
      ref.invalidate(waitingOrdersProvider);
      ref.invalidate(cashierTodayPaymentsProvider);
      ref.invalidate(orderDetailProvider(widget.orderId));

      if (!mounted) return;
      final cashPaid = _splitMode && _method == 'CASH'
          ? _parseRupiah(_splitAmount1Ctrl.text).toDouble()
          : total.toDouble();
      final change =
          amountReceived != null ? amountReceived - cashPaid : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            change != null && change > 0
                ? '${order.orderNumber} — Lunas (kembalian ${formatRupiah(change)})'
                : '${order.orderNumber} — Lunas',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      final shouldPrint = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cetak struk?'),
          content: const Text('Ingin cetak struk ke thermal printer?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tidak'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cetak'),
            ),
          ],
        ),
      );

      if (shouldPrint == true && mounted) {
        final prefs = ref.read(prefsProvider);
        final settings = await ThermalPrinterSettings.load(prefs);
        final cfg = ref.read(appConfigProvider);
        final user = ref.read(authProvider).user;
        try {
          await ref.read(thermalPrinterServiceProvider).printReceipt(
                settings: settings,
                appName: cfg.appName,
                branchName: user?.branchName,
                order: order,
                paymentMethod: _method!,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Struk terkirim ke printer'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal print: $e'),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        }
      }

      if (mounted) context.go('/cashier');
    } on DioException catch (e) {
      if (e.response == null) {
        final order = ref.read(orderDetailProvider(widget.orderId)).valueOrNull;
        if (order != null) {
          await ref.read(syncManagerProvider).enqueuePayOrder(
                orderId: order.id,
                paymentMethod: _method ?? 'CASH',
                amount: order.total,
                amountReceived: amountReceived,
                proofImageUrl: proofImageUrl,
                splits: splits,
              );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                order != null
                    ? '${order.orderNumber} — offline, pembayaran di-queue'
                    : 'Pembayaran di-queue (offline)',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          context.go('/cashier');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_paymentErrorMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Map<String, dynamic> _splitLine({
    required String method,
    required int amount,
    int? amountReceived,
    String? proofUrl,
  }) {
    return {
      'payment_method': method,
      'amount': amount,
      if (method == 'CASH' && amountReceived != null)
        'amount_received': amountReceived,
      if ((method == 'QRIS' || method == 'TRANSFER') &&
          proofUrl != null &&
          proofUrl.isNotEmpty)
        'proof_image_url': proofUrl,
    };
  }

  String _paymentErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        return errors.map((x) => x.toString()).join('\n');
      }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return e.message ?? e.toString();
  }

  void _selectMethod(String method) {
    final wasCash = _method == 'CASH';
    setState(() {
      _method = method;
      if (method == 'CASH' && !wasCash) {
        _receivedController.clear();
      }
    });
  }

  void _syncSplitAmount2(int orderTotal) {
    if (!_splitMode || _splitAmount2Manual) return;
    final a1 = _parseRupiah(_splitAmount1Ctrl.text);
    final a2 = (orderTotal - a1).clamp(0, orderTotal);
    final next = a2 > 0 ? a2.toString() : '';
    if (_splitAmount2Ctrl.text != next) {
      _splitAmount2Ctrl.text = next;
    }
  }

  void _onSplitAmount1Changed(int orderTotal) {
    _syncSplitAmount2(orderTotal);
    setState(() {});
  }

  void _onSplitAmount2Changed() {
    _splitAmount2Manual = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderId));

    return AppScaffold(
      title: 'Pembayaran',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (order) {
          final total = order.total.round();
          final splitCashDue = _splitMode && _method == 'CASH'
              ? _parseRupiah(_splitAmount1Ctrl.text)
              : total;
          final cashDue = _method == 'CASH' ? splitCashDue : 0;
          final received = _method == 'CASH' ? _parseRupiah(_receivedController.text) : 0;
          final change = received > cashDue ? received - cashDue : 0;
          final splitNeedsProof = _splitMode &&
              (_method == 'QRIS' ||
                  _method == 'TRANSFER' ||
                  _method2 == 'QRIS' ||
                  _method2 == 'TRANSFER');
          final splitOk = !_splitMode ||
              (_method != null &&
                  _method2 != null &&
                  _method != _method2 &&
                  _parseRupiah(_splitAmount1Ctrl.text) +
                          _parseRupiah(_splitAmount2Ctrl.text) ==
                      total &&
                  (!_splitMode ||
                      _method != 'CASH' ||
                      received >= _parseRupiah(_splitAmount1Ctrl.text)) &&
                  (!splitNeedsProof || _proofUrl != null));
          final canSubmit = (_splitMode ? splitOk : _method != null) &&
              !_paying &&
              !_uploadingProof &&
              (_splitMode ||
                  _method != 'CASH' ||
                  received >= total) &&
              (_splitMode ||
                  _method == 'CASH' ||
                  ((_method == 'QRIS' || _method == 'TRANSFER') &&
                      _proofUrl != null));

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (order.customerName != null) ...[
                        const SizedBox(height: 4),
                        Text(order.customerName!),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Total: ${formatRupiah(order.total)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bayar campuran'),
                subtitle: const Text('Contoh: sebagian tunai + QRIS'),
                value: _splitMode,
                onChanged: _paying
                    ? null
                    : (v) => setState(() {
                          _splitMode = v;
                          if (v) {
                            _splitAmount2Manual = false;
                            _splitAmount1Ctrl.clear();
                            _splitAmount2Ctrl.clear();
                          }
                        }),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _splitMode ? 'Metode 1' : 'Metode pembayaran',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MethodChip(
                label: 'Tunai',
                icon: Icons.payments,
                selected: _method == 'CASH',
                onTap: _paying ? null : () => _selectMethod('CASH'),
              ),
              _MethodChip(
                label: 'QRIS',
                icon: Icons.qr_code,
                selected: _method == 'QRIS',
                onTap: _paying ? null : () => _selectMethod('QRIS'),
              ),
              _MethodChip(
                label: 'Transfer',
                icon: Icons.account_balance,
                selected: _method == 'TRANSFER',
                onTap: _paying ? null : () => _selectMethod('TRANSFER'),
              ),
              if (_splitMode) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _splitAmount1Ctrl,
                  enabled: !_paying,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Nominal metode 1 (Rp)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _onSplitAmount1Changed(total),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Metode 2', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _MethodChip(
                  label: 'Tunai',
                  icon: Icons.payments,
                  selected: _method2 == 'CASH',
                  onTap: _paying
                      ? null
                      : () => setState(() => _method2 = 'CASH'),
                ),
                _MethodChip(
                  label: 'QRIS',
                  icon: Icons.qr_code,
                  selected: _method2 == 'QRIS',
                  onTap: _paying
                      ? null
                      : () => setState(() => _method2 = 'QRIS'),
                ),
                _MethodChip(
                  label: 'Transfer',
                  icon: Icons.account_balance,
                  selected: _method2 == 'TRANSFER',
                  onTap: _paying
                      ? null
                      : () => setState(() => _method2 = 'TRANSFER'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _splitAmount2Ctrl,
                  enabled: !_paying,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Nominal metode 2 (Rp)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _onSplitAmount2Changed(),
                ),
                const SizedBox(height: AppSpacing.md),
                _SplitShortfallCard(
                  total: total,
                  amount1: _parseRupiah(_splitAmount1Ctrl.text),
                  amount2: _parseRupiah(_splitAmount2Ctrl.text),
                ),
              ],
              if (_method == 'CASH') ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _splitMode ? 'Pembayaran tunai (metode 1)' : 'Pembayaran tunai',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_splitMode) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tagihan tunai: ${formatRupiah(cashDue.toDouble())}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _receivedController,
                  enabled: !_paying,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: _splitMode
                        ? 'Uang diterima — bagian tunai (Rp)'
                        : 'Uang diterima (Rp)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.money),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      'Pecahan uang',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _paying ? null : _resetReceived,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _CashDenominationChips(
                  enabled: !_paying,
                  onTap: _addCashDenomination,
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kembalian',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          formatRupiah(change.toDouble()),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: received >= cashDue
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (cashDue > 0 && received > 0 && received < cashDue)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'Kurang ${formatRupiah((cashDue - received).toDouble())}',
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
              ],
              if (_method == 'QRIS' ||
                  _method == 'TRANSFER' ||
                  (_splitMode &&
                      (_method2 == 'QRIS' || _method2 == 'TRANSFER'))) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Bukti pembayaran',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _method == 'QRIS'
                      ? 'Unggah screenshot pembayaran QRIS'
                      : 'Unggah screenshot bukti transfer',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_proofFile != null && !kIsWeb)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_proofFile!.path),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_uploadingProof) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  const Text('Mengunggah...', style: TextStyle(fontSize: 12)),
                ],
                if (_proofUrl != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Bukti berhasil diunggah',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _paying || _uploadingProof ? null : _pickProof,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_proofUrl != null ? 'Ganti foto' : 'Pilih foto bukti'),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: canSubmit ? _submitPay : null,
                child: _paying
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Konfirmasi pembayaran'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplitShortfallCard extends StatelessWidget {
  const _SplitShortfallCard({
    required this.total,
    required this.amount1,
    required this.amount2,
  });

  final int total;
  final int amount1;
  final int amount2;

  @override
  Widget build(BuildContext context) {
    final shortfall = total - amount1 - amount2;
    final isBalanced = shortfall == 0;
    final isOver = shortfall < 0;

    return Card(
      color: isBalanced
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kekurangan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  formatRupiah(shortfall.clamp(0, total).toDouble()),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isBalanced
                        ? AppColors.success
                        : shortfall > 0
                            ? AppColors.danger
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (isOver)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Lebih ${formatRupiah((-shortfall).toDouble())}',
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            if (isBalanced && amount1 > 0 && amount2 > 0)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Nominal metode 1 + metode 2 sudah sesuai total',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CashDenominationChips extends StatelessWidget {
  const _CashDenominationChips({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final amount in _cashDenominations)
          ActionChip(
            label: Text(_denomLabel(amount)),
            onPressed: enabled ? () => onTap(amount) : null,
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }

  static String _denomLabel(int value) {
    return formatRupiah(value).replaceFirst('Rp ', '');
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
      child: ListTile(
        enabled: onTap != null,
        leading: AppIcon3D.list(
          icon: icon,
          accentKey: label,
          accent: selected ? null : AppColors.textSecondary,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : null,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
