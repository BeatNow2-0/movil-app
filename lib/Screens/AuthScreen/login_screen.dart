import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/beatnow_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final TapGestureRecognizer _signUpRecognizer;

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _signUpRecognizer = TapGestureRecognizer()
      ..onTap = () => _authController.changeTab(AuthTabs.signUp);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _signUpRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeatNowTokens.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                BeatNowTokens.space4,
                BeatNowTokens.space4,
                BeatNowTokens.space4,
                BeatNowTokens.space6,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const BeatNowLogo(
                          size: 88,
                          subtitle: 'Discover your next sound',
                        ),
                        const SizedBox(height: BeatNowTokens.space6),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: BeatNowTokens.surface1,
                            borderRadius: BorderRadius.circular(
                                BeatNowTokens.radiusMedium),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back',
                                style: TextStyle(
                                    fontSize: 26,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to find beats, save inspiration and write.',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.64)),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('Username'),
                              ),
                              const SizedBox(height: BeatNowTokens.space4),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  'Password',
                                  suffix: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _authController
                                      .changeTab(AuthTabs.forgotPassword),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.2),
                                      )
                                    : const Text(
                                        'Continue',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7)),
                            children: [
                              TextSpan(
                                text: 'Sign Up',
                                style: const TextStyle(
                                  color: BeatNowTokens.accentSoft,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: _signUpRecognizer,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(hintText: hint, suffixIcon: suffix);
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Fill all fields');
      return;
    }

    setState(() => _isLoading = true);
    final success =
        await _authController.loginWithCredentials(username, password);
    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);
    if (!success && _authController.selectedIndex.value == AuthTabs.login) {
      _showMessage('Incorrect login');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
      ),
    );
  }
}
