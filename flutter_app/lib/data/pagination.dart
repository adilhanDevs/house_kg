class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.results,
    this.nextCursor,
    this.previousCursor,
  });

  final List<T> results;
  final String? nextCursor;
  final String? previousCursor;

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
    );
  }

  static String? _extractCursor(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.queryParameters.containsKey('cursor')) {
      return uri.queryParameters['cursor'];
    }
    return null;
  }
}
