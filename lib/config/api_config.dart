class ApiConfig {
  static const String scheme = 'https';
  static const String host = 'api.beatnow.app';
  static const String apiPrefix = '/v1/api';

  static Uri buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri(
      scheme: scheme,
      host: host,
      path: '$apiPrefix$normalizedPath',
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  static Uri buildAuthUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri(
      scheme: scheme,
      host: host,
      path: '$apiPrefix/users$normalizedPath',
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }
}
