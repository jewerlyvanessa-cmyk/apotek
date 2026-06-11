import 'package:dio/dio.dart';

String dioErrorMessage(Object error, {String fallback = 'Terjadi kesalahan'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString();
      final errs = data['errors'];
      if (errs is List && errs.isNotEmpty) {
        return '${msg ?? fallback}: ${errs.join(', ')}';
      }
      if (msg != null && msg.isNotEmpty) return msg;
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Tidak dapat terhubung ke server';
    }
  }
  return error.toString().replaceFirst('Exception: ', '');
}
