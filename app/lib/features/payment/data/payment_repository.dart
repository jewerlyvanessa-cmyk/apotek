import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_result.dart';
import '../domain/entities/payment_summary.dart';

class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  Future<PaginatedResult<PaymentSummary>> getPayments({
    String? branchId,
    String? dateFrom,
    String? dateTo,
    String? paymentMethod,
    bool mine = false,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/payments',
      queryParameters: {
        ...?branchId != null ? {'branch_id': branchId} : null,
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        ...?paymentMethod != null && paymentMethod.isNotEmpty
            ? {'payment_method': paymentMethod}
            : null,
        ...?mine ? {'mine': true} : null,
        'limit': limit,
        'page': page,
      },
    );
    final api = ApiResponse<List<dynamic>>.fromJson(
      response.data!,
      (d) => d as List<dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return PaginatedResult(
      items: api.data!
          .map((e) => PaymentSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: PaginatedMeta.fromJson(api.meta),
    );
  }

  Future<PaymentSummary> getPayment(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/payments/$id');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return PaymentSummary.fromJson(api.data!);
  }

  String _proofFilename(XFile file) {
    if (file.name.isNotEmpty) return file.name;
    return 'bukti-pembayaran.jpg';
  }

  DioMediaType? _proofContentType(XFile file, String filename) {
    final mime = file.mimeType;
    if (mime != null && mime.isNotEmpty) {
      return DioMediaType.parse(mime);
    }
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return DioMediaType('image', 'png');
    if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
    return DioMediaType('image', 'jpeg');
  }

  Future<MultipartFile> _proofMultipart(XFile file) async {
    final filename = _proofFilename(file);
    final contentType = _proofContentType(file, filename);
    if (kIsWeb) {
      return MultipartFile.fromBytes(
        await file.readAsBytes(),
        filename: filename,
        contentType: contentType,
      );
    }
    return MultipartFile.fromFile(
      file.path,
      filename: filename,
      contentType: contentType,
    );
  }

  Future<String> uploadProof(XFile file) async {
    final form = FormData.fromMap({
      'file': await _proofMultipart(file),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/upload-proof',
      data: form,
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    final url = api.data!['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('URL bukti pembayaran tidak diterima');
    }
    return url;
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(dioProvider));
});
