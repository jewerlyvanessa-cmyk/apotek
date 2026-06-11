import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/medicine_repository.dart';
import '../../domain/entities/medicine.dart';
import 'medicine_list_query.dart';

export 'catalog_provider.dart';

final medicineListProvider =
    FutureProvider.autoDispose.family<List<Medicine>, MedicineListQuery>(
        (ref, query) async {
  final repo = ref.watch(medicineRepositoryProvider);
  return repo.getMedicines(
    search: query.search,
    productTypeId: query.productTypeId,
    productTypeCode: query.productTypeCode,
  );
});

final medicineDetailProvider =
    FutureProvider.autoDispose.family<Medicine, String>((ref, id) async {
  return ref.watch(medicineRepositoryProvider).getMedicine(id);
});
