import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/barcode_search_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../providers/medicine_list_query.dart';
import '../providers/medicine_provider.dart';
import '../widgets/medicine_card.dart';

class MedicineListPage extends ConsumerStatefulWidget {
  const MedicineListPage({super.key});

  @override
  ConsumerState<MedicineListPage> createState() => _MedicineListPageState();
}

class _MedicineListPageState extends ConsumerState<MedicineListPage> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _typeFilterId;

  MedicineListQuery get _query => MedicineListQuery(
        search: _search.isEmpty ? null : _search,
        productTypeId: _typeFilterId,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshList() {
    ref.invalidate(medicineListProvider(_query));
  }

  void _onSearch(String value) {
    setState(() => _search = value);
    _refreshList();
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicineListProvider(_query));
    final typesAsync = ref.watch(productTypesProvider);

    return AppScaffold(
      title: 'Katalog Produk',
      actions: [
        IconButton(
          tooltip: 'Master katalog',
          icon: const Icon(Icons.tune),
          onPressed: () => context.push('/medicines/master'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/medicines/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BarcodeSearchField(
                  controller: _searchController,
                  hintText: 'Cari nama, barcode, SKU...',
                  onSubmitted: _onSearch,
                  onChanged: (v) {
                    if (v.isEmpty) _onSearch('');
                  },
                  onBarcode: (code) async => _onSearch(code),
                ),
                const SizedBox(height: AppSpacing.sm),
                typesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, unused) => const SizedBox.shrink(),
                  data: (types) {
                    final active = types.where((t) => t.isActive).toList();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Semua'),
                            selected: _typeFilterId == null,
                            onSelected: (_) {
                              setState(() => _typeFilterId = null);
                              _refreshList();
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ...active.map((t) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.xs),
                              child: FilterChip(
                                avatar: Icon(t.legacyType.icon, size: 18),
                                label: Text(t.name),
                                selected: _typeFilterId == t.id,
                                onSelected: (selected) {
                                  setState(
                                    () => _typeFilterId =
                                        selected ? t.id : null,
                                  );
                                  _refreshList();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: medicinesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Gagal memuat: $e'),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: _refreshList,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (medicines) {
                if (medicines.isEmpty) {
                  return const Center(child: Text('Belum ada produk'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(medicineListProvider(_query));
                    await ref.read(medicineListProvider(_query).future);
                  },
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: medicines.length,
                    itemBuilder: (context, index) {
                      final med = medicines[index];
                      return MedicineCard(
                        medicine: med,
                        onTap: () => context.push('/medicines/${med.id}/edit'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
