import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class CodeConfirmationScreen extends StatefulWidget {
  const CodeConfirmationScreen({super.key});

  @override
  State<CodeConfirmationScreen> createState() => _CodeConfirmationScreenState();
}

class _CodeConfirmationScreenState extends State<CodeConfirmationScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final BeatNowService _beatNowService = BeatNowService();
  final TextEditingController _codeController = TextEditingController();

  bool _submitting = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3C0F4B),
      minimumSize: const Size(double.infinity, 56),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Franklin Gothic Demi',
        fontSize: 16.0,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _authController.changeTab(AuthTabs.login);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Enter Confirmation Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Franklin Gothic Demi',
                  ),
                ),
                const SizedBox(height: 12.0),
                const Text(
                  'We sent a 6-digit code to your email address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20.0),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _codeController,
                  autoDismissKeyboard: true,
                  autoDisposeControllers: false,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12.0),
                    fieldHeight: 50,
                    fieldWidth: 40,
                    activeFillColor: const Color(0xFF494949),
                    inactiveFillColor: const Color(0xFF494949),
                    selectedFillColor: const Color(0xFF494949),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white70,
                    selectedColor: Colors.white,
                  ),
                  backgroundColor: const Color(0xFF111111),
                  textStyle: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {},
                ),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: _submitting ? null : _submitCode,
                  style: buttonStyle,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit'),
                ),
                const SizedBox(height: 12.0),
                TextButton(
                  onPressed: _resending ? null : _resendCode,
                  child: Text(
                    _resending ? 'Sending...' : 'Resend code',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showMessage('Enter the 6-digit code.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _beatNowService.confirmEmailCode(code);
      if (!mounted) return;
      await _authController.checkLogin();
      _showMessage('Email verified successfully.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _resending = true);
    try {
      await _beatNowService.sendConfirmationEmail();
      _showMessage('A new code has been sent.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3C0F4B),
      ),
    );
  }
}
