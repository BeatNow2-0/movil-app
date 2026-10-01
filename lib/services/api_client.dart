import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:BeatNow/config/api_config.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.retryAfter,
    this.failure,
  });

  final String message;
  final int? statusCode;
  final String? responseBody;
  final int? retryAfter;
  final ApiFailure? failure;

  String get userMessage {
    if (failure == ApiFailure.timeout) {
      return 'La solicitud tardó demasiado. Inténtalo de nuevo.';
    }
    if (failure == ApiFailure.connection) {
      return 'No hay conexión. Comprueba tu conexión a internet e inténtalo de nuevo.';
    }

    switch (statusCode) {
      case 400:
        return 'No se pudo completar la solicitud. Revisa los datos e inténtalo de nuevo.';
      case 401:
        return 'No se pudo iniciar sesión o la sesión ha caducado.';
      case 403:
        return 'No tienes permiso para realizar esta acción.';
      case 404:
        return 'No se encontró el contenido solicitado.';
      case 409:
        return 'Esta acción entra en conflicto con el estado actual.';
      case 422:
        return 'Algunos datos no son válidos. Revísalos e inténtalo de nuevo.';
      case 429:
        final seconds = retryAfter;
        return seconds != null && seconds > 0
            ? 'Demasiados intentos. Vuelve a probar en $seconds segundos.'
            : 'Demasiados intentos. Espera un momento y vuelve a probar.';
      case 500:
        return 'El servidor tuvo un problema. Inténtalo de nuevo más tarde.';
      case 503:
        return 'El servicio no está disponible ahora. Inténtalo de nuevo más tarde.';
      default:
        return 'No se pudo completar la solicitud. Inténtalo de nuevo.';
    }
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, failure: $failure)';
}

enum ApiFailure { timeout, connection }

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? secureStorage})
      : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _accessTokenStorageKey = 'access_token';
  static const String _refreshTokenStorageKey = 'refresh_token';
  static const String _verificationTokenStorageKey = 'verification_token';

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  Future<bool>? _refreshFuture;
  Future<void>? _tokenMigrationFuture;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _send(
      () async => _client.get(
        ApiConfig.buildUri(path, queryParameters),
        headers: await _buildHeaders(requiresAuth: requiresAuth),
      ),
      requiresAuth: requiresAuth,
      retryTransient: true,
    );

    return _decodeMap(response);
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _send(
      () async => _client.get(
        ApiConfig.buildUri(path, queryParameters),
        headers: await _buildHeaders(requiresAuth: requiresAuth),
      ),
      requiresAuth: requiresAuth,
      retryTransient: true,
    );

    return _decodeList(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    Map<String, String>? headers,
    String? bearerToken,
    bool allowRefresh = true,
  }) async {
    final response = await _send(
      () async => _client.post(
        ApiConfig.buildUri(path, queryParameters),
        headers: {
          ...await _buildHeaders(
            requiresAuth: requiresAuth,
            bearerToken: bearerToken,
          ),
          ...?headers,
        },
        body: body == null ? null : jsonEncode(body),
      ),
      requiresAuth: requiresAuth,
      allowRefresh: allowRefresh,
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    final response = await _send(
      () async => _client.put(
        ApiConfig.buildUri(path),
        headers: await _buildHeaders(requiresAuth: requiresAuth),
        body: body == null ? null : jsonEncode(body),
      ),
      requiresAuth: requiresAuth,
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool requiresAuth = true,
  }) async {
    final response = await _send(
      () async => _client.delete(
        ApiConfig.buildUri(path),
        headers: await _buildHeaders(requiresAuth: requiresAuth),
      ),
      requiresAuth: requiresAuth,
    );

    return _decodeMap(response, allowEmpty: true);
  }

  Future<Map<String, dynamic>> postForm(
    Uri uri, {
    required Map<String, String> formData,
  }) async {
    final response = await _sendNetworkRequest(
      () => _client.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: formData,
      ),
    );
    _ensureSuccess(response);
    return _decodeMap(response);
  }

  Future<void> persistTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _ensureTokenMigration();
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _accessTokenStorageKey, value: accessToken);
    await prefs.remove(_verificationTokenStorageKey);
    UserSingleton().token = accessToken;

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(
        key: _refreshTokenStorageKey,
        value: refreshToken,
      );
    }
  }

  Future<void> clearTokens() async {
    try {
      await _ensureTokenMigration();
    } catch (_) {
      // Continue clearing both stores if legacy migration failed.
    }
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _accessTokenStorageKey);
    await _secureStorage.delete(key: _refreshTokenStorageKey);
    await prefs.remove(_accessTokenStorageKey);
    await prefs.remove(_refreshTokenStorageKey);
    await prefs.remove(_verificationTokenStorageKey);
    UserSingleton().token = '';
  }

  Future<void> persistVerificationToken(String verificationToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_verificationTokenStorageKey, verificationToken);
    UserSingleton().token = verificationToken;
  }

  Future<void> clearVerificationToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_verificationTokenStorageKey);
  }

  Future<String?> readAccessToken() async {
    await _ensureTokenMigration();
    return _secureStorage.read(key: _accessTokenStorageKey);
  }

  Future<String?> readRefreshToken() async {
    await _ensureTokenMigration();
    return _secureStorage.read(key: _refreshTokenStorageKey);
  }

  Future<void> _ensureTokenMigration() async {
    final pendingMigration = _tokenMigrationFuture;
    if (pendingMigration != null) {
      await pendingMigration;
      return;
    }

    final migration = _migrateLegacyTokens();
    _tokenMigrationFuture = migration;
    try {
      await migration;
    } finally {
      _tokenMigrationFuture = null;
    }
  }

  Future<void> _migrateLegacyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_accessTokenStorageKey, _refreshTokenStorageKey]) {
      final legacyToken = prefs.getString(key);
      if (legacyToken == null || legacyToken.isEmpty) continue;

      final secureToken = await _secureStorage.read(key: key);
      if (secureToken == null || secureToken.isEmpty) {
        await _secureStorage.write(key: key, value: legacyToken);
      }
      await prefs.remove(key);
    }
  }

  Future<String?> readVerificationToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_verificationTokenStorageKey);
  }

  Future<void> revokeRefreshToken(String refreshToken) async {
    final response = await _sendNetworkRequest(
      () => _client.post(
        ApiConfig.buildAuthUri('/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ),
    );
    _ensureSuccess(response);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() requestFactory, {
    required bool requiresAuth,
    bool allowRefresh = true,
    bool retryTransient = false,
  }) async {
    var response = await _requestWithRetry(
      requestFactory,
      retryTransient: retryTransient,
    );

    if (response.statusCode == 401 && requiresAuth && allowRefresh) {
      final refreshed = await _refreshAccessTokenOnce();
      if (refreshed) {
        response = await _sendNetworkRequest(requestFactory);
      }
    }

    _ensureSuccess(response);
    return response;
  }

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() requestFactory, {
    required bool retryTransient,
  }) async {
    try {
      final response = await _sendNetworkRequest(requestFactory);
      if (retryTransient &&
          (response.statusCode == 500 || response.statusCode == 503)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return _sendNetworkRequest(requestFactory);
      }
      return response;
    } on ApiException catch (error) {
      if (!retryTransient || error.failure == null) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _sendNetworkRequest(requestFactory);
    }
  }

  Future<http.Response> _sendNetworkRequest(
    Future<http.Response> Function() requestFactory,
  ) async {
    try {
      return await requestFactory().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(
        'Request timed out',
        failure: ApiFailure.timeout,
      );
    } on SocketException {
      throw ApiException(
        'Network connection failed',
        failure: ApiFailure.connection,
      );
    } on http.ClientException {
      throw ApiException(
        'Network connection failed',
        failure: ApiFailure.connection,
      );
    }
  }

  Future<Map<String, String>> _buildHeaders({
    required bool requiresAuth,
    String? bearerToken,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    } else if (requiresAuth) {
      final token = UserSingleton().token.isNotEmpty
          ? UserSingleton().token
          : await readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<bool> _refreshAccessTokenOnce() {
    final pendingRefresh = _refreshFuture;
    if (pendingRefresh != null) {
      return pendingRefresh;
    }

    final refreshFuture = _refreshAccessToken();
    _refreshFuture = refreshFuture;
    return refreshFuture.whenComplete(() => _refreshFuture = null);
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = await readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _sendNetworkRequest(
        () => _client.post(
          ApiConfig.buildAuthUri('/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        ),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await clearTokens();
        return false;
      }

      final json = _decodeMap(response);
      final newAccessToken = json['access_token'] as String?;
      final newRefreshToken = json['refresh_token'] as String?;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        await clearTokens();
        return false;
      }

      await persistTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? refreshToken,
      );
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response,
      {bool allowEmpty = false}) {
    if (response.body.isEmpty) {
      return allowEmpty ? <String, dynamic>{} : <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw ApiException(
      'Unexpected response format',
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  List<dynamic> _decodeList(http.Response response) {
    if (response.body.isEmpty) {
      return <dynamic>[];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) {
      return decoded;
    }

    throw ApiException(
      'Unexpected response format',
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Request failed';
    int? retryAfter;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          message = decoded['detail']?.toString() ??
              decoded['message']?.toString() ??
              (decoded.values.isNotEmpty
                  ? decoded.values.first.toString()
                  : message);
          final decodedRetryAfter = decoded['retry_after'];
          if (decodedRetryAfter is int) {
            retryAfter = decodedRetryAfter;
          } else if (decodedRetryAfter is String) {
            retryAfter = int.tryParse(decodedRetryAfter);
          }
        }
      } catch (_) {}
    }
    retryAfter ??= int.tryParse(response.headers['retry-after'] ?? '');

    throw ApiException(
      message,
      statusCode: response.statusCode,
      responseBody: response.body,
      retryAfter: retryAfter,
    );
  }
}
