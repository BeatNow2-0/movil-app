import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../Controllers/auth_controller.dart';

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

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

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
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please fill in the form to continue',
                style: TextStyle(color: Color(0xFF494949)),
              ),
              const SizedBox(height: 40),
              _input(_fullName, 'Full Name'),
              _input(_email, 'Email Address'),
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
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _authController.changeTab(0),
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

  Widget _input(TextEditingController c, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: c,
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

    if (_password.text != _confirmPassword.text) {
      _error('Passwords do not match');
      return;
    }

    try {
      setState(() => _isLoading = true);

      await http.post(
        Uri.parse('https://api.beatnow.app/v1/api/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': _fullName.text.trim(),
          'email': _email.text.trim(),
          'username': _username.text.trim(),
          'password': _password.text,
        }),
      );

      _error('Account created. Please sign in.');
      _authController.changeTab(0);
    } catch (e) {
      _error('Registration failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF3C0F4B),
        content: Text(msg),
      ),
    );
  }
}
