class PaginatedMeta {
  const PaginatedMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.lastPage,
  });

  final int page;
  final int limit;
  final int total;
  final int lastPage;

  bool get hasNext => page < lastPage;
  bool get hasPrev => page > 1;

  factory PaginatedMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PaginatedMeta(page: 1, limit: 20, total: 0, lastPage: 1);
    }
    return PaginatedMeta(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}

class PaginatedResult<T> {
  const PaginatedResult({required this.items, required this.meta});

  final List<T> items;
  final PaginatedMeta meta;
}
