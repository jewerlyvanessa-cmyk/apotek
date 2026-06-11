import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/catalog_repository.dart';
import '../../domain/entities/catalog_entities.dart';

final productTypesProvider =
    FutureProvider.autoDispose<List<ProductTypeDef>>((ref) async {
  return ref.watch(catalogRepositoryProvider).getProductTypes();
});

final categoriesProvider =
    FutureProvider.autoDispose<List<MedicineCategory>>((ref) async {
  return ref.watch(catalogRepositoryProvider).getCategories();
});

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) async {
  return ref.watch(catalogRepositoryProvider).getSuppliers();
});
