import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/utils/medicine_barcode_lookup.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../medicine/data/medicine_repository.dart';
import '../../../medicine/domain/entities/medicine.dart';
import '../../../customer/data/customer_repository.dart';
import '../../data/order_repository.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/prescription_info.dart';
import '../providers/cart_provider.dart';
import '../../../medicine/presentation/widgets/drug_classification_chip.dart';
import '../../../medicine/presentation/widgets/product_type_chip.dart';
import '../widgets/prescription_form_section.dart';
import '../../../pharmacy/presentation/pages/pharmacy_reviews_page.dart';
import '../providers/order_list_provider.dart';

final customerSearchProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.trim().length < 2) return [];
  final result = await ref
      .watch(customerRepositoryProvider)
      .searchCustomers(search: query, limit: 20);
  return result.items;
});

final medicinesSearchProvider =
    FutureProvider.autoDispose.family<List<Medicine>, String>((ref, search) {
  return ref
      .watch(medicineRepositoryProvider)
      .getMedicines(search: search.isEmpty ? null : search);
});

final stockRealtimeProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, medicineId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get<Map<String, dynamic>>(
    '/stocks/realtime/$medicineId',
  );
  final data = response.data!;
  if (data['success'] == true) {
    return data['data'] as Map<String, dynamic>;
  }
  throw Exception(data['message']);
});

class CreateOrderPage extends ConsumerStatefulWidget {
  const CreateOrderPage({super.key, this.orderId});

  final String? orderId;

  bool get isEdit => orderId != null;

  @override
  ConsumerState<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends ConsumerState<CreateOrderPage> {
  final _searchController = TextEditingController();
  final _customerController = TextEditingController();
  final _rxNumberController = TextEditingController();
  final _rxDoctorController = TextEditingController();
  final _rxPatientController = TextEditingController();
  final _rxAgeController = TextEditingController();
  final _rxNotesController = TextEditingController();
  DateTime? _rxDate;
  bool _orderWithPrescription = false;
  String _search = '';
  String? _selectedCustomerId;
  bool _submitting = false;
  bool _loadingOrder = false;
  bool _orderLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrderForEdit());
    }
  }

  Future<void> _loadOrderForEdit() async {
    if (_orderLoaded || widget.orderId == null) return;
    setState(() => _loadingOrder = true);
    try {
      final order =
          await ref.read(orderRepositoryProvider).getOrder(widget.orderId!);
      if (!mounted) return;
      _customerController.text = order.customerName ?? '';
      _selectedCustomerId = order.customerId;
      final merged = <String, CartItem>{};
      for (final i in order.items) {
        var maxQty = i.quantity;
        try {
          final stockData =
              await ref.read(stockRealtimeProvider(i.medicineId).future);
          final available = stockData['available_quantity'] as int? ?? 0;
          maxQty = available + i.quantity;
        } catch (_) {
          // Tanpa stok riil: batasi ke qty order saat ini (tidak bisa tambah).
        }
        final existing = merged[i.medicineId];
        if (existing != null) {
          merged[i.medicineId] = existing.copyWith(
            quantity: existing.quantity + i.quantity,
            availableStock: maxQty < 1 ? 1 : maxQty,
            usageInstructions:
                existing.usageInstructions ?? i.usageInstructions,
          );
        } else {
          merged[i.medicineId] = CartItem(
            medicineId: i.medicineId,
            name: i.medicineName,
            sellPrice: i.price,
            quantity: i.quantity,
            availableStock: maxQty < 1 ? 1 : maxQty,
            unit: i.unit,
            productType: i.productType,
            drugClassification: i.drugClassification,
            requiresPrescription: i.requiresPrescription,
            usageInstructions: i.usageInstructions,
          );
        }
      }
      final cartItems = merged.values.toList();
      ref.read(cartProvider.notifier).setItems(cartItems);
      _orderLoaded = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOrder = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    _rxNumberController.dispose();
    _rxDoctorController.dispose();
    _rxPatientController.dispose();
    _rxAgeController.dispose();
    _rxNotesController.dispose();
    super.dispose();
  }

  bool _cartNeedsPrescription(List<CartItem> cart) => cart.any(
        (c) => c.displayDrugClassification?.requiresPrescription == true,
      );

  bool _showPrescriptionForm(List<CartItem> cart) =>
      !widget.isEdit && _orderWithPrescription;

  bool _prescriptionRequired(List<CartItem> cart) => _orderWithPrescription;

  PrescriptionInfo _buildPrescriptionInfo() {
    return PrescriptionInfo(
      number: _rxNumberController.text,
      date: _rxDate,
      doctorName: _rxDoctorController.text,
      patientName: _rxPatientController.text,
      patientAge: _rxAgeController.text,
      notes: _rxNotesController.text,
    );
  }

  void _clearPrescriptionForm() {
    _rxNumberController.clear();
    _rxDoctorController.clear();
    _rxPatientController.clear();
    _rxAgeController.clear();
    _rxNotesController.clear();
    _rxDate = null;
    _orderWithPrescription = false;
  }

  void _syncPatientFromCustomer() {
    final name = _customerController.text.trim();
    if (name.length >= 2) {
      _rxPatientController.text = name;
      setState(() {});
    }
  }

  void _selectCustomer(Map<String, dynamic> c) {
    setState(() {
      _selectedCustomerId = c['id'] as String?;
      _customerController.text = c['name']?.toString() ?? '';
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomerId = null;
      _customerController.clear();
    });
  }

  String _customerError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _createAndSelectCustomer({
    required String name,
    String? phone,
  }) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nama pelanggan minimal 2 karakter'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }
    try {
      final created = await ref.read(customerRepositoryProvider).createCustomer(
            name: trimmed,
            phone: phone?.trim(),
          );
      if (!mounted) return;
      _selectCustomer(created);
      ref.invalidate(customerSearchProvider(trimmed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pelanggan "$trimmed" tersimpan'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_customerError(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _openNewCustomerDialog() async {
    final nameCtrl = TextEditingController(text: _customerController.text);
    final phoneCtrl = TextEditingController();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pelanggan baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telepon',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.length < 2) return;
              Navigator.pop(ctx);
              await _createAndSelectCustomer(
                name: name,
                phone: phoneCtrl.text,
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _loadStockAndAdd(Medicine medicine) async {
    try {
      final stockData = await ref.read(stockRealtimeProvider(medicine.id).future);
      final available = stockData['available_quantity'] as int? ?? 0;
      if (available <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stok tidak tersedia'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }
      final cart = ref.read(cartProvider);
      final existing = cart.where((c) => c.medicineId == medicine.id).firstOrNull;
      final maxStock = existing != null
          ? available + existing.quantity
          : available;

      final rack = stockData['rack_position'] as String? ??
          stockData['rackPosition'] as String?;

      ref.read(cartProvider.notifier).addItem(
            medicineId: medicine.id,
            name: medicine.name,
            sellPrice: medicine.sellPrice,
            availableStock: maxStock < 1 ? 1 : maxStock,
            unit: medicine.unit,
            rackPosition: rack?.trim().isNotEmpty == true ? rack!.trim() : null,
            productType: medicine.productType,
            drugClassification: medicine.drugClassification,
            requiresPrescription: medicine.requiresPrescription,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat stok riil: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  String? _rackFromStock(Map<String, dynamic> stockData) {
    final rack = stockData['rack_position'] as String? ??
        stockData['rackPosition'] as String?;
    final trimmed = rack?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : null;
  }

  Widget _rackChip(String? rack, {bool compact = false}) {
    final label = rack != null && rack.isNotEmpty ? rack : 'Belum diisi';
    final isSet = rack != null && rack.isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isSet
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shelves,
            size: compact ? 14 : 16,
            color: isSet ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            'Rak $label',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: isSet ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel(
    BuildContext context,
    List<CartItem> cart,
    CartNotifier cartNotifier,
    bool rxOrder,
  ) {
    final maxPanelHeight = MediaQuery.sizeOf(context).height * 0.48;

    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxPanelHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Keranjang · ${cart.length} jenis',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (rxOrder)
                      Text(
                        'Isi petunjuk',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: cart.length,
                  separatorBuilder: (_, unused) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    final atMax = item.quantity >= item.availableStock;
                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          ProductTypeChip(
                                            type: item.productType,
                                            compact: true,
                                          ),
                                          if (item.displayDrugClassification !=
                                              null) ...[
                                            const SizedBox(width: 4),
                                            DrugClassificationChip(
                                              classification:
                                                  item.displayDrugClassification!,
                                              compact: true,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _rackChip(item.rackPosition, compact: true),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${formatRupiah(item.sellPrice)}${item.unit != null ? ' / ${item.unit}' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        formatRupiah(item.subtotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => ref
                                          .read(cartProvider.notifier)
                                          .decrementQty(item.medicineId),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: atMax
                                          ? null
                                          : () => _onIncrementQty(item),
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        color: atMax
                                            ? AppColors.textSecondary
                                            : AppColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => ref
                                          .read(cartProvider.notifier)
                                          .removeItem(item.medicineId),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (rxOrder) ...[
                              const SizedBox(height: AppSpacing.sm),
                              TextFormField(
                                key: ValueKey('usage-${item.medicineId}'),
                                initialValue: item.usageInstructions,
                                decoration: const InputDecoration(
                                  labelText: 'Petunjuk penggunaan *',
                                  hintText: '3x1 sesudah makan, 7 hari',
                                ),
                                maxLines: 2,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (v) => ref
                                    .read(cartProvider.notifier)
                                    .updateUsageInstructions(
                                      item.medicineId,
                                      v,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${cartNotifier.itemCount} item',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          formatRupiah(cartNotifier.total),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      label: widget.isEdit
                          ? 'Simpan perubahan order'
                          : 'Submit order',
                      button: true,
                      child: AppButton(
                        label: widget.isEdit
                            ? 'Simpan Perubahan'
                            : 'Submit Order',
                        isLoading: _submitting,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onIncrementQty(CartItem item) {
    if (item.quantity >= item.availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok maksimum: ${item.availableStock}'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    ref.read(cartProvider.notifier).incrementQty(item.medicineId);
  }

  Future<void> _submit() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keranjang kosong — tambah minimal 1 item'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_showPrescriptionForm(cart) && _prescriptionRequired(cart)) {
      final rxErr = _buildPrescriptionInfo().validateRequired();
      if (rxErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(rxErr), backgroundColor: AppColors.danger),
        );
        return;
      }
    }

    if (_prescriptionRequired(cart)) {
      for (final item in cart) {
        if (item.usageInstructions == null ||
            item.usageInstructions!.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Isi petunjuk penggunaan untuk: ${item.name}',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      }
    }

    setState(() => _submitting = true);
    try {
      final customerName = _customerController.text.trim();
      final items = cart
          .map((c) => {
                'medicine_id': c.medicineId,
                'quantity': c.quantity,
                if (c.usageInstructions != null &&
                    c.usageInstructions!.trim().isNotEmpty)
                  'usage_instructions': c.usageInstructions!.trim(),
              })
          .toList();

      if (widget.isEdit) {
        final result = await ref.read(orderRepositoryProvider).updateOrder(
              orderId: widget.orderId!,
              customerId: _selectedCustomerId,
              customerName: customerName.isEmpty ? null : customerName,
              items: items,
            );
        ref.read(cartProvider.notifier).clear();
        ref.invalidate(waitingOrdersProvider);
        ref.invalidate(staffTodayOrdersProvider);
        ref.invalidate(orderDetailProvider(widget.orderId!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${result['order_number'] ?? ''} diperbarui',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } else {
        final rxPayload = _showPrescriptionForm(cart)
            ? _buildPrescriptionInfo().toApiJson()
            : null;
        final result = await ref.read(orderRepositoryProvider).createOrder(
              customerId: _selectedCustomerId,
              customerName: customerName.isEmpty ? null : customerName,
              prescription: rxPayload?.isNotEmpty == true ? rxPayload : null,
              hasPrescription: _prescriptionRequired(cart),
              items: items,
            );
        ref.read(cartProvider.notifier).clear();
        _clearPrescriptionForm();
        ref.invalidate(waitingOrdersProvider);
        ref.invalidate(staffTodayOrdersProvider);
        ref.invalidate(pendingPharmacyOrdersProvider);
        ref.invalidate(pendingPharmacyOrdersHomeProvider);
        if (mounted) {
          final status = result['status']?.toString() ?? 'WAITING_PAYMENT';
          final msg = status == 'PENDING_PHARMACY'
              ? 'Order ${result['order_number']} — menunggu telaah apoteker'
              : 'Order ${result['order_number']} — menunggu pembayaran';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (e.response == null) {
        await ref.read(syncManagerProvider).enqueueCreateOrder(
              customerId: _selectedCustomerId,
              customerName: _customerController.text.trim(),
              items: cart
                  .map((c) => {
                        'medicine_id': c.medicineId,
                        'quantity': c.quantity,
                      })
                  .toList(),
            );
        ref.read(cartProvider.notifier).clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: order disimpan, akan di-sync saat online'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final cart = ref.watch(cartProvider);
    final medicinesAsync = ref.watch(medicinesSearchProvider(_search));
    final customerQuery = _customerController.text.trim();
    final customersAsync = ref.watch(customerSearchProvider(customerQuery));
    final cartNotifier = ref.read(cartProvider.notifier);

    final pageTitle = widget.isEdit ? 'Edit Order' : 'Buat Order';

    if (user?.branchId == null) {
      return AppScaffold(
        title: pageTitle,
        body: Center(
          child: Text(
            widget.isEdit
                ? 'Login dengan cabang aktif untuk mengedit order'
                : 'Login sebagai asisten dengan cabang aktif',
          ),
        ),
      );
    }

    if (widget.isEdit && _loadingOrder) {
      return AppScaffold(
        title: pageTitle,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final rxOrder = _prescriptionRequired(cart);

    return AppScaffold(
      title: pageTitle,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Semantics(
                              label: 'Cari atau isi nama pelanggan',
                              textField: true,
                              child: TextField(
                              controller: _customerController,
                              decoration: InputDecoration(
                                labelText: 'Cari / nama pelanggan',
                                prefixIcon: const Icon(Icons.person_outline),
                                suffixIcon: _selectedCustomerId != null ||
                                        _customerController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: _clearCustomer,
                                      )
                                    : null,
                              ),
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) {
                                setState(() => _selectedCustomerId = null);
                              },
                            ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              label: 'Tambah pelanggan baru',
                              button: true,
                              child: IconButton.filledTonal(
                                tooltip: 'Pelanggan baru',
                                onPressed: _openNewCustomerDialog,
                                icon: const Icon(Icons.person_add_alt_1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedCustomerId != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: const Icon(Icons.check_circle, size: 18),
                            label: Text(
                              'Terpilih: ${_customerController.text}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            onDeleted: _clearCustomer,
                          ),
                        ),
                      ],
                      if (!widget.isEdit) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: CheckboxListTile(
                            value: _orderWithPrescription,
                            onChanged: (v) => setState(
                              () => _orderWithPrescription = v ?? false,
                            ),
                            title: const Text(
                              'Order dengan resep dokter',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              _cartNeedsPrescription(cart)
                                  ? 'Ada obat keras/narkotika di keranjang. Centang hanya jika pelanggan membawa resep fisik.'
                                  : 'Centang jika pelanggan membawa resep fisik',
                              style: const TextStyle(fontSize: 12),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                        ),
                      ],
                      if (_showPrescriptionForm(cart)) ...[
                        const SizedBox(height: AppSpacing.sm),
                        PrescriptionFormSection(
                          numberController: _rxNumberController,
                          doctorController: _rxDoctorController,
                          patientController: _rxPatientController,
                          ageController: _rxAgeController,
                          notesController: _rxNotesController,
                          prescriptionDate: _rxDate,
                          onDateChanged: (d) => setState(() => _rxDate = d),
                          requiredFields: rxOrder,
                          customerName: _customerController.text.trim(),
                          onSyncPatientFromCustomer: _syncPatientFromCustomer,
                        ),
                      ],
                      if (customerQuery.length >= 2)
                        customersAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.sm),
                            child: LinearProgressIndicator(),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (customers) {
                            return Card(
                              margin: const EdgeInsets.only(top: AppSpacing.sm),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...customers.take(5).map((c) {
                                    final name = c['name']?.toString() ?? '-';
                                    final phone = c['phone']?.toString();
                                    return ListTile(
                                      dense: true,
                                      leading:
                                          const Icon(Icons.person, size: 20),
                                      title: Text(name),
                                      subtitle:
                                          phone != null ? Text(phone) : null,
                                      onTap: () => _selectCustomer(c),
                                    );
                                  }),
                                  const Divider(height: 1),
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.person_add,
                                      color: AppColors.primary,
                                    ),
                                    title: Text(
                                      customers.isEmpty
                                          ? 'Simpan "$customerQuery" sebagai pelanggan baru'
                                          : 'Tambah pelanggan baru',
                                    ),
                                    onTap: () => _createAndSelectCustomer(
                                      name: customerQuery,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      BarcodeSearchField(
                        controller: _searchController,
                        hintText: 'Cari produk...',
                        onSubmitted: (v) => setState(() => _search = v),
                        onChanged: (v) {
                          if (v.isEmpty) setState(() => _search = '');
                        },
                        onBarcode: (barcode) async {
                          final med = await findMedicineByBarcodeWithFeedback(
                            context,
                            ref,
                            barcode,
                          );
                          if (med == null) return;
                          await _loadStockAndAdd(med);
                          if (!context.mounted) return;
                          final added = ref
                              .read(cartProvider)
                              .where((c) => c.medicineId == med.id)
                              .firstOrNull;
                          final rackHint = added?.rackPosition != null
                              ? ' · Rak ${added!.rackPosition}'
                              : '';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Ditambahkan: ${med.name}$rackHint'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
                medicinesAsync.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('$e')),
                  ),
                  data: (medicines) {
                    if (medicines.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('Cari produk untuk mulai order'),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final m = medicines[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Consumer(
                                builder: (context, ref, _) {
                                  final stockAsync =
                                      ref.watch(stockRealtimeProvider(m.id));
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                      side: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Semantics(
                                      label:
                                          '${m.name}, harga ${formatRupiah(m.sellPrice)}',
                                      button: true,
                                      child: ListTile(
                                      title: Row(
                                        children: [
                                          Expanded(child: Text(m.name)),
                                ProductTypeChip(
                                  type: m.productType,
                                  compact: true,
                                ),
                                if (m.displayDrugClassification != null) ...[
                                  const SizedBox(width: 4),
                                  DrugClassificationChip(
                                    classification:
                                        m.displayDrugClassification!,
                                    compact: true,
                                  ),
                                ],
                                        ],
                                      ),
                                      subtitle: stockAsync.when(
                                        loading: () =>
                                            Text(formatRupiah(m.sellPrice)),
                                        error: (_, unused) =>
                                            Text(formatRupiah(m.sellPrice)),
                                        data: (stock) {
                                          final qty = stock[
                                                  'available_quantity']
                                              as int? ??
                                              0;
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${formatRupiah(m.sellPrice)} · Stok: $qty',
                                              ),
                                              const SizedBox(height: 4),
                                              _rackChip(
                                                _rackFromStock(stock),
                                                compact: true,
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      isThreeLine: true,
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: () => _loadStockAndAdd(m),
                                      ),
                                    ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: medicines.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (cart.isNotEmpty) _buildCartPanel(context, cart, cartNotifier, rxOrder),
        ],
      ),
    );
  }
}
