import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../warehouse/presentation/providers/central_warehouse_provider.dart';
import 'stock_list_page.dart';

class CentralStockPage extends ConsumerWidget {
  const CentralStockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centralAsync = ref.watch(centralWarehouseProvider);
    return centralAsync.when(
      loading: () => const AppScaffold(
        title: 'Stok Gudang Pusat',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Stok Gudang Pusat',
        body: Center(child: Text('$e')),
      ),
      data: (central) => StockListPage(
        fixedBranchId: central['id']?.toString(),
        title: 'Stok Gudang Pusat',
      ),
    );
  }
}
