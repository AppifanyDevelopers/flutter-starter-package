/// The backend's success envelope: `{status, message, data, meta?}`.
///
/// `data` is an object, an array, an empty array or null depending on the
/// endpoint; `meta` is present only on paginated endpoints.
class ApiEnvelope {
  const ApiEnvelope({required this.status, this.message, this.data, this.meta});

  factory ApiEnvelope.fromJson(Map<String, dynamic> json) => ApiEnvelope(
        status: json['status'] as int? ?? 200,
        message: json['message'] as String?,
        data: json['data'],
        meta: json['meta'] is Map<String, dynamic>
            ? PaginationMeta.fromJson(json['meta'] as Map<String, dynamic>)
            : null,
      );

  final int status;
  final String? message;
  final dynamic data;
  final PaginationMeta? meta;

  /// `data` as an object, or null when it is null / a list.
  Map<String, dynamic>? get dataMap => data is Map<String, dynamic> ? data as Map<String, dynamic> : null;

  /// `data` as a list of objects; empty when it is null or not a list.
  List<Map<String, dynamic>> get dataList =>
      data is List ? [for (final e in data as List) if (e is Map<String, dynamic>) e] : const [];
}

class PaginationMeta {
  const PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.from,
    this.to,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) => PaginationMeta(
        currentPage: json['current_page'] as int? ?? 1,
        lastPage: json['last_page'] as int? ?? 1,
        perPage: json['per_page'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
        from: json['from'] as int?,
        to: json['to'] as int?,
      );

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int? from;
  final int? to;

  /// No more pages when `current_page == last_page`.
  bool get hasMore => currentPage < lastPage;
}
