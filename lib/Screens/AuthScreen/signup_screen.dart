import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:regexed_validator/regexed_validator.dart';

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
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text(
                'Create New Account',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please fill in the form to continue',
                style: TextStyle(color: Color(0xFF494949)),
              ),
              const SizedBox(height: 40),
              _input(_fullName, 'Full Name'),
              _input(_email, 'Email Address', keyboardType: TextInputType.emailAddress),
              _input(_username, 'Username'),
              _passwordInput(_password, 'Password', true),
              _passwordInput(_confirmPassword, 'Confirm Password', false),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3C0F4B),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign Up'),
              ),
              const SizedBox(height: 40),
              RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: const TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: 'Sign In',
                      style: const TextStyle(
                        color: Color(0xFF4E0566),
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
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(
          hint,
          suffix: IconButton(
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
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF494949),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffix,
    );
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
      await _beatNowService.register(
        fullName: fullName,
        email: email,
        username: username,
        password: password,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Account created. Please sign in.');
      _authController.changeTab(AuthTabs.login);
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
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
        backgroundColor: const Color(0xFF3C0F4B),
        content: Text(msg),
      ),
    );
  }
}
