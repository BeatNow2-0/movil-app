import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/auth_service.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:regexed_validator/regexed_validator.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/beatnow_logo.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthController _authController = Get.find<AuthController>();

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final TapGestureRecognizer _signInRecognizer;

  final BeatNowService _beatNowService = BeatNowService();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _signInRecognizer = TapGestureRecognizer()
      ..onTap = () => _authController.changeTab(AuthTabs.login);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _signInRecognizer.dispose();
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BeatNowLogo(
                          size: 86,
                          subtitle: 'Create. Save. Write.',
                        ),
                        const SizedBox(height: BeatNowTokens.space6),
                        const Text(
                          'Create your account',
                          style: TextStyle(
                            fontSize: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Join BeatNow to find your sound.',
                          style: TextStyle(color: BeatNowTokens.textMuted),
                        ),
                        const SizedBox(height: BeatNowTokens.space5),
                        _input(_fullName, 'Full Name'),
                        _input(_email, 'Email Address',
                            keyboardType: TextInputType.emailAddress),
                        _input(_username, 'Username'),
                        _passwordInput(_password, 'Password', true),
                        _passwordInput(
                            _confirmPassword, 'Confirm Password', false),
                        const SizedBox(height: BeatNowTokens.space2),
                        FilledButton(
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Sign Up'),
                        ),
                        const SizedBox(height: BeatNowTokens.space4),
                        RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: const TextStyle(color: Colors.white),
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: const TextStyle(
                                  color: BeatNowTokens.accentSoft,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _signInRecognizer,
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

  Widget _input(
    TextEditingController c,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        autofillHints: keyboardType == TextInputType.emailAddress
            ? const [AutofillHints.email]
            : null,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(hint),
      ),
    );
  }

  Widget _passwordInput(TextEditingController c, String hint, bool main) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: c,
        obscureText: main ? _obscurePassword : _obscureConfirmPassword,
        textInputAction: main ? TextInputAction.next : TextInputAction.done,
        autofillHints: main
            ? const [AutofillHints.newPassword]
            : const [AutofillHints.newPassword],
        onSubmitted: main ? null : (_) => _register(),
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(
          hint,
          suffix: IconButton(
            tooltip: (main ? _obscurePassword : _obscureConfirmPassword)
                ? 'Show password'
                : 'Hide password',
            icon: Icon(
              (main ? _obscurePassword : _obscureConfirmPassword)
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: Colors.white70,
            ),
            onPressed: () => setState(() {
              main
                  ? _obscurePassword = !_obscurePassword
                  : _obscureConfirmPassword = !_obscureConfirmPassword;
            }),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(hintText: hint, suffixIcon: suffix);
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final fullName = _fullName.text.trim();
    final email = _email.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;

    final validationError = _validateForm(
      fullName: fullName,
      email: email,
      username: username,
      password: password,
      confirmPassword: confirmPassword,
    );

    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _beatNowService.register(
        fullName: fullName,
        email: email,
        username: username,
        password: password,
      );
      final verificationToken = response['verification_token']?.toString();

      if (!mounted) {
        return;
      }

      if (verificationToken != null && verificationToken.isNotEmpty) {
        await _authService.persistVerificationToken(verificationToken);
        _showMessage(
            'Account created. Check your email for the verification code.');
        _authController.changeTab(AuthTabs.codeConfirmation);
      } else {
        _showMessage('Account created. Please sign in.');
        _authController.changeTab(AuthTabs.login);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.userMessage);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Registration failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateForm({
    required String fullName,
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) {
    if (fullName.isEmpty || email.isEmpty || username.isEmpty) {
      return 'Fill all fields';
    }
    if (!validator.email(email)) {
      return 'Enter a valid email address';
    }
    if (username.length < 3) {
      return 'Username must contain at least 3 characters';
    }
    if (password.length < 8) {
      return 'Password must contain at least 8 characters';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
      ),
    );
  }
}
