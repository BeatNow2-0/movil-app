import 'package:BeatNow/Screens/AuthScreen/authentication_code_screen.dart';
import 'package:BeatNow/Screens/AuthScreen/splash_screen.dart';
import 'package:BeatNow/Screens/HomeScreen/home_screen.dart';
import 'package:BeatNow/Screens/HomeScreen/LyricScreen.dart';
import 'package:BeatNow/Screens/HomeScreen/saved_screen.dart';
import 'package:BeatNow/Screens/ProfileScreen/AccountSettingsScreen.dart';
import 'package:BeatNow/Screens/ProfileScreen/profileuser_screen.dart';
import 'package:BeatNow/Screens/SearchScreens/search_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'theme/beatnow_theme.dart';

import 'Controllers/auth_controller.dart';
import 'Screens/AuthScreen/forgot_password_screen.dart';
import 'Screens/AuthScreen/login_screen.dart';
import 'Screens/AuthScreen/signup_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BeatNow',
      theme: BeatNowTheme.dark,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthController _authController = Get.put(AuthController());
  final List<Widget?> _primaryPages = List<Widget?>.filled(5, null);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedTab = _authController.selectedIndex.value;
      final selectedIndex = _navigationIndex(selectedTab);
      if (selectedIndex != null) {
        _primaryPages[selectedIndex] ??= _primaryPage(selectedIndex);
        return Scaffold(
          body: IndexedStack(
            index: selectedIndex,
            children: List.generate(
              _primaryPages.length,
              (index) => _primaryPages[index] ?? const SizedBox.shrink(),
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: selectedIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (index) => _authController.changeTab(_tabForIndex(index)),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: 'Explore',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bookmark_border_rounded),
                activeIcon: Icon(Icons.bookmark_rounded),
                label: 'Saved',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.edit_note_rounded),
                label: 'Lyrics',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      }

      switch (selectedTab) {
        case AuthTabs.splash:
          return const SplashScreen();
        case AuthTabs.signUp:
          return const SignUpScreen();
        case AuthTabs.forgotPassword:
          return ForgotPasswordScreen();
        case AuthTabs.accountSettings:
          return AccountSettingsScreen();
        case AuthTabs.login:
          return const LoginScreen();
        case AuthTabs.codeConfirmation:
          return const CodeConfirmationScreen();
        case AuthTabs.sendingResetEmail:
          return const SplashScreen(sendPasswordReset: true);
        default:
          return const LoginScreen();
      }
    });
  }

  Widget _primaryPage(int index) {
    switch (index) {
      case 0:
        return const HomeScreenState();
      case 1:
        return const SearchScreen();
      case 2:
        return const SavedScreen();
      case 3:
        return const LyricScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const HomeScreenState();
    }
  }

  int? _navigationIndex(int tab) {
    switch (tab) {
      case AuthTabs.home:
        return 0;
      case AuthTabs.search:
        return 1;
      case AuthTabs.saved:
        return 2;
      case AuthTabs.lyrics:
        return 3;
      case AuthTabs.profile:
        return 4;
      default:
        return null;
    }
  }

  int _tabForIndex(int index) {
    switch (index) {
      case 1:
        return AuthTabs.search;
      case 2:
        return AuthTabs.saved;
      case 3:
        return AuthTabs.lyrics;
      case 4:
        return AuthTabs.profile;
      case 0:
      default:
        return AuthTabs.home;
    }
  }
}
