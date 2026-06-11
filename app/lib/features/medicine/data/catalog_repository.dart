import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/catalog_entities.dart';

class CatalogRepository {
  CatalogRepository(this._dio);

  final Dio _dio;

  Future<List<ProductTypeDef>> getProductTypes() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/product-types',
      queryParameters: {'limit': 100},
    );
    return _parseList(response.data, ProductTypeDef.fromJson);
  }

  Future<ProductTypeDef> createProductType(Map<String, dynamic> data) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/product-types',
      data: data,
    );
    return _parseOne(response.data, ProductTypeDef.fromJson);
  }

  Future<ProductTypeDef> updateProductType(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/product-types/$id',
      data: data,
    );
    return _parseOne(response.data, ProductTypeDef.fromJson);
  }

  Future<void> deleteProductType(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/product-types/$id',
    );
    final api = ApiResponse<dynamic>.fromJson(response.data!, null);
    if (!api.success) throw Exception(api.message);
  }

  Future<List<MedicineCategory>> getCategories() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/categories',
      queryParameters: {'limit': 100},
    );
    return _parseList(response.data, MedicineCategory.fromJson);
  }

  Future<MedicineCategory> createCategory(String name) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/categories',
      data: {'name': name},
    );
    return _parseOne(response.data, MedicineCategory.fromJson);
  }

  Future<MedicineCategory> updateCategory(String id, String name) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/categories/$id',
      data: {'name': name},
    );
    return _parseOne(response.data, MedicineCategory.fromJson);
  }

  Future<void> deleteCategory(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/categories/$id',
    );
    final api = ApiResponse<dynamic>.fromJson(response.data!, null);
    if (!api.success) throw Exception(api.message);
  }

  Future<List<Supplier>> getSuppliers() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/suppliers',
      queryParameters: {'limit': 100},
    );
    return _parseList(response.data, Supplier.fromJson);
  }

  Future<Supplier> createSupplier(Map<String, dynamic> data) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/suppliers',
      data: data,
    );
    return _parseOne(response.data, Supplier.fromJson);
  }

  Future<Supplier> updateSupplier(String id, Map<String, dynamic> data) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/suppliers/$id',
      data: data,
    );
    return _parseOne(response.data, Supplier.fromJson);
  }

  Future<void> deleteSupplier(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>('/suppliers/$id');
    final api = ApiResponse<dynamic>.fromJson(response.data!, null);
    if (!api.success) throw Exception(api.message);
  }

  List<T> _parseList<T>(
    Map<String, dynamic>? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final api = ApiResponse<List<dynamic>>.fromJson(
      raw!,
      (d) => d as List<dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  }

  T _parseOne<T>(
    Map<String, dynamic>? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      raw!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return fromJson(api.data!);
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(dioProvider));
});
