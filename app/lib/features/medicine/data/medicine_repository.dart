import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/medicine.dart';

class MedicineRepository {
  MedicineRepository(this._dio);

  final Dio _dio;

  Future<List<Medicine>> getMedicines({
    String? search,
    String? categoryId,
    String? barcode,
    String? productTypeId,
    String? productTypeCode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/medicines',
      queryParameters: {
        ...?search != null && search.isNotEmpty ? {'search': search} : null,
        ...?categoryId != null ? {'category_id': categoryId} : null,
        ...?barcode != null && barcode.isNotEmpty ? {'barcode': barcode} : null,
        ...?productTypeId != null ? {'product_type_id': productTypeId} : null,
        ...?productTypeCode != null ? {'product_type': productTypeCode} : null,
        'limit': 50,
      },
    );

    final api = ApiResponse<List<dynamic>>.fromJson(
      response.data!,
      (d) => d as List<dynamic>,
    );

    if (!api.success || api.data == null) {
      throw Exception(api.message);
    }

    return api.data!
        .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Medicine?> findByBarcode(String barcode) async {
    final items = await getMedicines(barcode: barcode);
    if (items.isEmpty) return null;
    return items.first;
  }

  Future<Medicine> getMedicine(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/medicines/$id');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return Medicine.fromJson(api.data!);
  }

  Future<Medicine> createMedicine(Map<String, dynamic> data) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/medicines',
      data: data,
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return Medicine.fromJson(api.data!);
  }

  Future<Medicine> updateMedicine(String id, Map<String, dynamic> data) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/medicines/$id',
      data: data,
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return Medicine.fromJson(api.data!);
  }

  Future<void> deleteMedicine(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>('/medicines/$id');
    final api = ApiResponse<dynamic>.fromJson(response.data!, null);
    if (!api.success) throw Exception(api.message);
  }

  Future<Medicine> uploadImage({
    required String medicineId,
    required XFile file,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.name,
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/medicines/$medicineId/image',
      data: form,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return Medicine.fromJson(api.data!);
  }
}

final medicineRepositoryProvider = Provider<MedicineRepository>((ref) {
  return MedicineRepository(ref.watch(dioProvider));
});
