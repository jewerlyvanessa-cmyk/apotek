import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../data/admin_repository.dart';

class BranchStockModePage extends ConsumerStatefulWidget {
  const BranchStockModePage({
    super.key,
    required this.branchId,
    required this.branchName,
    this.initialMode,
    this.isCentralWarehouse = false,
  });

  final String branchId;
  final String branchName;
  final String? initialMode;
  final bool isCentralWarehouse;

  @override
  ConsumerState<BranchStockModePage> createState() =>
      _BranchStockModePageState();
}

class _BranchStockModePageState extends ConsumerState<BranchStockModePage> {
  late String _mode;
  String _moveExistingTo = 'BACK';
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode ?? 'SIMPLE';
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).updateBranchStockMode(
            branchId: widget.branchId,
            stockMode: _mode,
            moveExistingTo:
                _mode == 'WAREHOUSE_ETALASE' ? _moveExistingTo : null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mode stok cabang disimpan')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final central = widget.isCentralWarehouse;
    final enabled = !central;

    return AppScaffold(
      title: 'Mode Stok',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            widget.branchName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Pilih bagaimana stok di cabang ini dikelola. Gudang pusat selalu mode sederhana.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Mode stok cabang',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'SIMPLE',
                label: Text('Sederhana'),
                icon: Icon(Icons.storefront_outlined),
              ),
              ButtonSegment(
                value: 'WAREHOUSE_ETALASE',
                label: Text('Gudang + Etalase'),
                icon: Icon(Icons.warehouse_outlined),
              ),
            ],
            selected: {_mode},
            emptySelectionAllowed: false,
            onSelectionChanged: enabled
                ? (v) => setState(() => _mode = v.first)
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _mode == 'SIMPLE'
                ? 'Satu pool stok cabang — langsung bisa dijual di kasir.'
                : 'Barang masuk gudang cabang; penjualan hanya dari etalase.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (_mode == 'WAREHOUSE_ETALASE' && enabled) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Stok existing dipindah ke',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'BACK',
                  label: Text('Gudang cabang'),
                ),
                ButtonSegment(
                  value: 'FRONT',
                  label: Text('Etalase'),
                ),
              ],
              selected: {_moveExistingTo},
              emptySelectionAllowed: false,
              onSelectionChanged: (v) =>
                  setState(() => _moveExistingTo = v.first),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving || central ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
