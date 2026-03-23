import 'package:BeatNow/config/api_config.dart';
import 'package:BeatNow/services/api_client.dart';

class AuthSession {
  const AuthSession({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.postForm(
      ApiConfig.buildAuthUri('/login'),
      formData: {
        'username': username,
        'password': password,
      },
    );

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

  Future<void> logout() => _apiClient.clearTokens();

  Future<String?> readAccessToken() => _apiClient.readAccessToken();
}
