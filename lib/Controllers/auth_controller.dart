import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/auth_service.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:get/get.dart';

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
  AuthController({AuthService? authService, BeatNowService? beatNowService})
      : _authService = authService ?? AuthService(),
        _beatNowService = beatNowService ?? BeatNowService();

  final AuthService _authService;
  final BeatNowService _beatNowService;

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

    final storedToken = await _authService.readAccessToken();
    if (storedToken == null || storedToken.isEmpty) {
      await clearSession();
      changeTab(AuthTabs.login);
      isLoading.value = false;
      return;
    }

    UserSingleton().token = storedToken;

    try {
      final userInfo = await _beatNowService.getCurrentUser();
      changeTab(
        userInfo['is_active'] == false
            ? AuthTabs.codeConfirmation
            : AuthTabs.home,
      );
    } catch (_) {
      await clearSession();
      changeTab(AuthTabs.login);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> loginWithCredentials(String username, String password) async {
    isLoading.value = true;

    try {
      await _authService.login(username: username, password: password);
      final userInfo = await _beatNowService.getCurrentUser();
      changeTab(
        userInfo['is_active'] == false
            ? AuthTabs.codeConfirmation
            : AuthTabs.home,
      );
      return true;
    } on ApiException {
      await clearSession();
      changeTab(AuthTabs.login);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> clearSession() async {
    await _authService.logout();
    UserSingleton()
      ..token = ''
      ..id = ''
      ..name = ''
      ..username = ''
      ..email = ''
      ..isActive = false;
  }
}
