class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.meta,
    this.code,
    this.errors,
  });

  final bool success;
  final String message;
  final T? data;
  final Map<String, dynamic>? meta;
  final String? code;
  final List<dynamic>? errors;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      meta: json['meta'] as Map<String, dynamic>?,
      code: json['code'] as String?,
      errors: json['errors'] as List<dynamic>?,
    );
  }
}
