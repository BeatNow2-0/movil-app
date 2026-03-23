import 'dart:convert';

import 'package:BeatNow/config/api_config.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const String _accessTokenStorageKey = 'access_token';
  static const String _refreshTokenStorageKey = 'refresh_token';

  final http.Client _client;

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
    );

    return _decodeList(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      () async => _client.post(
        ApiConfig.buildUri(path, queryParameters),
        headers: {
          ...await _buildHeaders(requiresAuth: requiresAuth),
          ...?headers,
        },
        body: body == null ? null : jsonEncode(body),
      ),
      requiresAuth: requiresAuth,
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
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: formData,
    );
    _ensureSuccess(response);
    return _decodeMap(response);
  }

  Future<void> persistTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenStorageKey, accessToken);
    UserSingleton().token = accessToken;

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenStorageKey, refreshToken);
    }
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenStorageKey);
    await prefs.remove(_refreshTokenStorageKey);
    UserSingleton().token = '';
  }

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenStorageKey);
  }

  Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenStorageKey);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() requestFactory, {
    required bool requiresAuth,
  }) async {
    var response = await requestFactory();

    if (response.statusCode == 401 && requiresAuth) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await requestFactory();
      }
    }

    _ensureSuccess(response);
    return response;
  }

  Future<Map<String, String>> _buildHeaders({required bool requiresAuth}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (requiresAuth) {
      final token = UserSingleton().token.isNotEmpty
          ? UserSingleton().token
          : await readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = await readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _client.post(
        ApiConfig.buildAuthUri('/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
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

  Map<String, dynamic> _decodeMap(http.Response response, {bool allowEmpty = false}) {
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
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          message = decoded['detail']?.toString() ??
              decoded['message']?.toString() ??
              (decoded.values.isNotEmpty ? decoded.values.first.toString() : message);
        }
      } catch (_) {}
    }

    throw ApiException(
      message,
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }
}
