import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/beatnow_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.sendPasswordReset = false});

  final bool sendPasswordReset;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sendPasswordReset) {
        _authController.sendPasswordMail(_authController.email.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BeatNowTokens.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeatNowLogo(size: 72, subtitle: 'Discover your next sound'),
            SizedBox(height: BeatNowTokens.space6),
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(BeatNowTokens.accentSoft),
            ),
          ],
        ),
      ),
    );
  }
}
