import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:regexed_validator/regexed_validator.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _emailController = TextEditingController();
  late final TapGestureRecognizer _signInRecognizer;

  @override
  void initState() {
    super.initState();
    _signInRecognizer = TapGestureRecognizer()
      ..onTap = () => _authController.changeTab(AuthTabs.login);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _signInRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeatNowTokens.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Center(
                child: Text(
                  'Enter your email',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16.0,
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                style: const TextStyle(color: Colors.white),
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8.0),
              const Center(
                child: Text(
                  'An email will be sent to your account.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14.0,
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              FilledButton(
                onPressed: _submit,
                child: const Text('Send'),
              ),
              const SizedBox(height: 20.0),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Go to ',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Sign In',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          color: BeatNowTokens.accentSoft,
                        ),
                        recognizer: _signInRecognizer,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final email = _emailController.text.trim();
    if (validator.email(email)) {
      _authController.email.value = email;
      _authController.changeTab(AuthTabs.sendingResetEmail);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please enter a valid email address.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
