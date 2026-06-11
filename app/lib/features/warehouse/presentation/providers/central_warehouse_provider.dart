import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';

final centralWarehouseProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>('/branches/central');
  final data = res.data?['data'];
  if (data is! Map) throw Exception('Gudang pusat belum dikonfigurasi');
  return Map<String, dynamic>.from(data);
});
