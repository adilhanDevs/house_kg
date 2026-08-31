class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.results,
    this.nextCursor,
    this.previousCursor,
    this.count,
  });

  final List<T> results;
  final String? nextCursor;
  final String? previousCursor;

  /// Общее количество записей в выборке (приходит в поле `count`).
  final int? count;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse<T>(
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => fromJsonT(e as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: _extractCursor(json['next'] as String?),
      previousCursor: _extractCursor(json['previous'] as String?),
      count: json['count'] as int?,
    );
  }

  static String? extractCursor(String? url) => _extractCursor(url);

  static String? _extractCursor(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.queryParameters.containsKey('cursor')) {
      return uri.queryParameters['cursor'];
    }
    return null;
  }
}
