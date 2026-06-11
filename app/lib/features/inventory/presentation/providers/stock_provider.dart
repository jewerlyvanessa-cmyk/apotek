import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/stock_repository.dart';
import '../../domain/entities/stock_item.dart';
import '../../../../core/network/paginated_result.dart';

class StockListState {
  const StockListState({required this.items, required this.meta});

  final List<StockItem> items;
  final PaginatedMeta meta;
}

class StockListNotifier extends StateNotifier<AsyncValue<StockListState>> {
  StockListNotifier(this._repo, this._params)
      : super(const AsyncValue.loading()) {
    load();
  }

  final StockRepository _repo;
  final StockListParams _params;
  String? _search;

  Future<void> load({String? search, int? page}) async {
    _search = search ?? _search;
    final targetPage = page ?? _params.page;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repo.getStocks(
        branchId: _params.branchId,
        search: _search,
        lowStock: _params.lowStockOnly,
        page: targetPage,
        limit: _params.limit,
        tenantWide: _params.tenantWide,
        locationCode: _params.locationCode,
        sellableOnly: _params.sellableOnly,
      );
      return StockListState(items: result.items, meta: result.meta);
    });
  }

  void applyRealtimeUpdate(Map<String, dynamic> payload) {
    final medicineId = payload['medicine_id'] as String?;
    if (medicineId == null) return;

    state.whenData((current) {
      final payloadBranchId = payload['branch_id'] as String?;
      final updated = current.items.map((item) {
        if (item.medicineId != medicineId) return item;
        if (payloadBranchId != null && item.branchId != payloadBranchId) {
          return item;
        }
        if (item.batchId != null &&
            payload['batch_id'] != null &&
            item.batchId != payload['batch_id']) {
          return item;
        }
        return item.copyWithRealtime(
          quantity: payload['quantity'] as int? ?? item.quantity,
          reservedQuantity:
              payload['reserved_quantity'] as int? ?? item.reservedQuantity,
          availableQuantity:
              payload['available_quantity'] as int? ?? item.availableQuantity,
        );
      }).toList();
      state = AsyncValue.data(
        StockListState(items: updated, meta: current.meta),
      );
    });
  }
}

final stockListProvider = StateNotifierProvider.autoDispose
    .family<StockListNotifier, AsyncValue<StockListState>, StockListParams>(
  (ref, params) {
    return StockListNotifier(
      ref.watch(stockRepositoryProvider),
      params,
    );
  },
);

class StockListParams {
  const StockListParams({
    this.branchId,
    this.lowStockOnly = false,
    this.page = 1,
    this.limit = 20,
    this.tenantWide = false,
    this.locationCode,
    this.sellableOnly,
  });

  final String? branchId;
  final bool lowStockOnly;
  final int page;
  final int limit;
  final bool tenantWide;
  final String? locationCode;
  final bool? sellableOnly;

  StockListParams copyWith({
    String? branchId,
    bool? lowStockOnly,
    int? page,
    int? limit,
    bool? tenantWide,
    String? locationCode,
    bool? sellableOnly,
  }) {
    return StockListParams(
      branchId: branchId ?? this.branchId,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      tenantWide: tenantWide ?? this.tenantWide,
      locationCode: locationCode ?? this.locationCode,
      sellableOnly: sellableOnly ?? this.sellableOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StockListParams &&
      branchId == other.branchId &&
      lowStockOnly == other.lowStockOnly &&
      page == other.page &&
      limit == other.limit &&
      tenantWide == other.tenantWide &&
      locationCode == other.locationCode &&
      sellableOnly == other.sellableOnly;

  @override
  int get hashCode => Object.hash(
        branchId,
        lowStockOnly,
        page,
        limit,
        tenantWide,
        locationCode,
        sellableOnly,
      );
}

bool isBranchActive(Map<String, dynamic> branch) =>
    branch['isActive'] == true || branch['is_active'] == true;

List<Map<String, dynamic>> filterActiveBranches(
  List<Map<String, dynamic>> branches,
) =>
    branches.where(isBranchActive).toList();

/// Map branchId → stock_mode dari cabang aktif.
final branchStockModesProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final user = ref.watch(authProvider).user;
  final branches = filterActiveBranches(
    await ref.watch(adminRepositoryProvider).listBranches(),
  );
  final scoped = user != null && !user.isTenantWideStock
      ? branches
          .where((b) => b['id']?.toString() == user.branchId)
          .toList()
      : branches;
  return {
    for (final b in scoped)
      b['id']?.toString() ?? '': b['stockMode']?.toString() ??
          b['stock_mode']?.toString() ??
          'SIMPLE',
  };
});

bool isWarehouseEtalaseMode(String? stockMode) =>
    stockMode == 'WAREHOUSE_ETALASE';

/// Tampilkan menu gudang cabang / etalase / isi etalase.
bool showWarehouseEtalaseMenus(
  AuthUser user,
  Map<String, String> branchModes,
) {
  if (user.isTenantWideManager) {
    return branchModes.values.any(isWarehouseEtalaseMode);
  }
  final allowed = user.stockScopeBranchIds;
  return allowed.any(
    (id) => isWarehouseEtalaseMode(branchModes[id]),
  );
}

const warehouseEtalaseMenuPaths = {
  '/stocks/locations/back',
  '/stocks/locations/front',
  '/stocks/replenish',
};

/// Null = stok seluruh tenant (owner / manajer pusat).
final effectiveBranchIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return null;
  if (user.isTenantWideStock) return null;
  return resolveStockBranchId(user, null);
});

/// Cabang efektif untuk query stok — non tenant-wide selalu cabang login.
String? resolveStockBranchId(AuthUser user, String? candidate) {
  if (user.isTenantWideStock) return candidate;
  final loginBranch = user.branchId;
  if (loginBranch != null && loginBranch.isNotEmpty) return loginBranch;
  final allowed = user.stockScopeBranchIds;
  if (allowed.length == 1) return allowed.first;
  if (candidate != null && allowed.contains(candidate)) return candidate;
  return null;
}

final isTenantWideStockProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  return user?.isTenantWideManager == true;
});

/// Perlu pilih cabang: hanya owner / manajer pusat (filter cabang aktif).
final needsStockBranchPickerProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;
  return user.isTenantWideStock;
});

final stockBranchPickerOptionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null || !user.isTenantWideStock) return [];
  return ref.watch(adminRepositoryProvider).listBranches();
});
