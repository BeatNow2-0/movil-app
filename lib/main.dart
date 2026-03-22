import 'package:BeatNow/Screens/AuthScreen/authentication_code_screen.dart';
import 'package:BeatNow/Screens/AuthScreen/splash_screen.dart';
import 'package:BeatNow/Screens/HomeScreen/home_screen.dart';
import 'package:BeatNow/Screens/HomeScreen/saved_screen.dart';
import 'package:BeatNow/Screens/ProfileScreen/AccountSettingsScreen.dart';
import 'package:BeatNow/Screens/ProfileScreen/profileother_screen.dart';
import 'package:BeatNow/Screens/ProfileScreen/profileuser_screen.dart';
import 'package:BeatNow/Screens/SearchScreens/search_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Franklin Gothic Demi'),
        ),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final AuthController _authController = Get.put(AuthController());

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (_authController.selectedIndex.value) {
        case AuthTabs.splash:
          return const SplashScreen();
        case AuthTabs.signUp:
          return const SignUpScreen();
        case AuthTabs.forgotPassword:
          return ForgotPasswordScreen();
        case AuthTabs.home:
          return HomeScreenState();
        case AuthTabs.profile:
          return const ProfileScreen();
        case AuthTabs.accountSettings:
          return AccountSettingsScreen();
        case AuthTabs.search:
          return SearchScreen();
        case AuthTabs.saved:
          return const SavedScreen();
        case AuthTabs.otherProfile:
          return const ProfileOtherScreen();
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
}
