import 'dart:convert';

import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthTabs {
  static const int splash = 0;
  static const int signUp = 1;
  static const int forgotPassword = 2;
  static const int home = 3;
  static const int profile = 4;
  static const int accountSettings = 5;
  static const int search = 6;
  static const int saved = 7;
  static const int otherProfile = 8;
  static const int login = 9;
  static const int codeConfirmation = 10;
  static const int sendingResetEmail = 11;
}

class AuthController extends GetxController {
  static const String _tokenStorageKey = 'access_token';

  final selectedIndex = AuthTabs.splash.obs;
  final isLoading = true.obs;
  final email = ''.obs;

  @override
  void onInit() {
    super.onInit();
    checkLogin();
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  Future<void> checkLogin() async {
    isLoading.value = true;

    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenStorageKey);

    if (storedToken == null || storedToken.isEmpty) {
      await clearSession();
      changeTab(AuthTabs.login);
      isLoading.value = false;
      return;
    }

    UserSingleton().token = storedToken;
    final userInfo = await getUserInfo(storedToken);

    if (userInfo == null) {
      await clearSession();
      changeTab(AuthTabs.login);
    } else if (userInfo['is_active'] == false) {
      changeTab(AuthTabs.codeConfirmation);
    } else {
      changeTab(AuthTabs.home);
    }

    isLoading.value = false;
  }

  Future<bool> loginWithCredentials(String username, String password) async {
    isLoading.value = true;
    final token = await _token(username, password);

    if (token == null) {
      isLoading.value = false;
      return false;
    }

    final userInfo = await getUserInfo(token);
    if (userInfo == null) {
      await clearSession();
      changeTab(AuthTabs.login);
      isLoading.value = false;
      return false;
    }

    changeTab(
      userInfo['is_active'] == false
          ? AuthTabs.codeConfirmation
          : AuthTabs.home,
    );
    isLoading.value = false;
    return true;
  }

  Future<Map<String, dynamic>?> getTokenUser(
    String username,
    String password,
  ) async {
    final apiUrl = Uri.parse('https://api.beatnow.app/token');
    final body = {'username': username, 'password': password};

    try {
      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _token(String username, String password) async {
    final response = await getTokenUser(username, password);
    final token = response?['access_token'] as String?;

    if (token == null || token.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
    UserSingleton().token = token;
    return token;
  }

  Future<Map<String, dynamic>?> getUserInfo(String token) async {
    final apiUrl = Uri.parse('https://api.beatnow.app/v1/api/users/users/me');
    try {
      final response = await http.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      UserSingleton()
        ..id = jsonResponse['id'] ?? ''
        ..name = jsonResponse['full_name'] ?? ''
        ..username = jsonResponse['username'] ?? ''
        ..email = jsonResponse['email'] ?? ''
        ..isActive = jsonResponse['is_active'] ?? false;
      return jsonResponse;
    } catch (_) {
      return null;
    }
  }

  Future<void> sendPasswordMail(String emailAddress) async {
    isLoading.value = true;
    final response = await resetPassword(emailAddress);

    if (response != null) {
      Get.snackbar('Success', 'Email sent successfully');
      changeTab(AuthTabs.login);
    } else {
      Get.snackbar('Error', 'Email not sent');
      changeTab(AuthTabs.forgotPassword);
    }

    isLoading.value = false;
  }

  Future<Map<String, dynamic>?> resetPassword(String emailAddress) async {
    final apiUrl = Uri.parse(
      'https://api.beatnow.app/v1/api/mail/send-password-reset/?mail=$emailAddress',
    );

    try {
      final response = await http.post(
        apiUrl,
        headers: {'accept': 'application/json'},
      );
      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenStorageKey);
    UserSingleton()
      ..token = ''
      ..id = ''
      ..name = ''
      ..username = ''
      ..email = ''
      ..isActive = false;
  }
}
