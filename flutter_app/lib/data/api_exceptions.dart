class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class NetworkException implements Exception {
  NetworkException([this.message = 'Network error']);
  final String message;
  
  @override
  String toString() => 'NetworkException: $message';
}
