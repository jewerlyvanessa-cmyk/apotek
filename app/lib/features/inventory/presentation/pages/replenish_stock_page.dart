import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/stock_repository.dart';

class ReplenishStockPage extends ConsumerStatefulWidget {
  const ReplenishStockPage({super.key, this.initialBranchId});

  final String? initialBranchId;

  @override
  ConsumerState<ReplenishStockPage> createState() => _ReplenishStockPageState();
}

class _ReplenishStockPageState extends ConsumerState<ReplenishStockPage> {
  final _medicineIdController = TextEditingController();
  final _batchIdController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _medicineIdController.dispose();
    _batchIdController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final medicineId = _medicineIdController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (medicineId.isEmpty || qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine ID dan jumlah wajib diisi')),
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final branchId = widget.initialBranchId ?? user?.branchId;

    setState(() => _saving = true);
    try {
      await ref.read(stockRepositoryProvider).replenishEtalase(
            medicineId: medicineId,
            quantity: qty,
            branchId: branchId,
            batchId: _batchIdController.text.trim().isEmpty
                ? null
                : _batchIdController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etalase berhasil diisi')),
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
    return AppScaffold(
      title: 'Isi Etalase',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Pindahkan stok dari gudang cabang ke etalase agar bisa dijual di kasir.',
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _medicineIdController,
            decoration: const InputDecoration(
              labelText: 'Medicine ID *',
              hintText: 'UUID obat',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _batchIdController,
            decoration: const InputDecoration(
              labelText: 'Batch ID (opsional)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah *'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Catatan'),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Pindah ke Etalase'),
          ),
        ],
      ),
    );
  }
}
