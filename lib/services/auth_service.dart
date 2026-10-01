import 'dart:convert';

import 'package:BeatNow/config/api_config.dart';
import 'package:BeatNow/services/api_client.dart';

class AuthSession {
  const AuthSession({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;
}

class AccountVerificationRequiredException extends ApiException {
  AccountVerificationRequiredException({
    required this.verificationToken,
    required this.expiresIn,
    String message = 'Account verification required',
  }) : super(message, statusCode: 403);

  final String verificationToken;
  final int expiresIn;
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await _apiClient.postForm(
        ApiConfig.buildAuthUri('/login'),
        formData: {
          'username': username,
          'password': password,
        },
      );
    } on ApiException catch (error) {
      if (error.statusCode == 403) {
        dynamic decoded;
        if (error.responseBody != null && error.responseBody!.isNotEmpty) {
          try {
            decoded = jsonDecode(error.responseBody!);
          } catch (_) {
            decoded = null;
          }
        }
        if (decoded is Map<String, dynamic> &&
            decoded['verification_required'] == true) {
          final verificationToken = decoded['verification_token']?.toString();
          final expiresIn = decoded['expires_in'];
          if (verificationToken != null && verificationToken.isNotEmpty) {
            await _apiClient.persistVerificationToken(verificationToken);
            throw AccountVerificationRequiredException(
              verificationToken: verificationToken,
              expiresIn: expiresIn is int ? expiresIn : 0,
              message: decoded['detail']?.toString() ??
                  'Account verification required',
            );
          }
        }
      }
      rethrow;
    }

    final accessToken = response['access_token'] as String?;
    final refreshToken = response['refresh_token'] as String?;

    if (accessToken == null || accessToken.isEmpty) {
      throw ApiException('Missing access token in login response');
    }

    await _apiClient.persistTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<void> logout() async {
    final refreshToken = await _apiClient.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.revokeRefreshToken(refreshToken);
      }
    } on ApiException {
      // Local logout must always complete even if backend revocation fails.
    } finally {
      await _apiClient.clearTokens();
    }
  }

  Future<String?> readAccessToken() => _apiClient.readAccessToken();

  Future<String?> readVerificationToken() => _apiClient.readVerificationToken();

  Future<void> persistVerificationToken(String verificationToken) =>
      _apiClient.persistVerificationToken(verificationToken);

  Future<void> clearVerificationToken() => _apiClient.clearVerificationToken();
}
