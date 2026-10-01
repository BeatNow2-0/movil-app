import 'dart:async';

import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';

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
  int _resendSeconds = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown(60);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fieldWidth =
        ((MediaQuery.sizeOf(context).width - 80) / 6).clamp(32.0, 48.0);
    return Scaffold(
      backgroundColor: BeatNowTokens.background,
      appBar: AppBar(
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
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.only(bottom: BeatNowTokens.space4),
                    decoration: BoxDecoration(
                      color: BeatNowTokens.accentMuted,
                      borderRadius:
                          BorderRadius.circular(BeatNowTokens.radiusMedium),
                    ),
                    child: const Icon(Icons.mark_email_read_outlined,
                        color: BeatNowTokens.accentSoft, size: 28),
                  ),
                ),
                const Text(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12.0),
                const Text(
                  'Enter the 6-digit code sent to your email address.',
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
                    borderRadius:
                        BorderRadius.circular(BeatNowTokens.radiusSmall),
                    fieldHeight: 52,
                    fieldWidth: fieldWidth,
                    activeFillColor: BeatNowTokens.surface2,
                    inactiveFillColor: BeatNowTokens.surface2,
                    selectedFillColor: BeatNowTokens.surface3,
                    activeColor: BeatNowTokens.accentSoft,
                    inactiveColor: BeatNowTokens.borderStrong,
                    selectedColor: BeatNowTokens.accentSoft,
                  ),
                  backgroundColor: BeatNowTokens.background,
                  textStyle: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {},
                ),
                const SizedBox(height: 20.0),
                FilledButton(
                  onPressed: _submitting ? null : _submitCode,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit'),
                ),
                const SizedBox(height: 12.0),
                TextButton(
                  onPressed:
                      _resending || _resendSeconds > 0 ? null : _resendCode,
                  child: Text(
                    _resending
                        ? 'Sending...'
                        : _resendSeconds > 0
                            ? 'Resend code in ${_resendSeconds}s'
                            : 'Resend code',
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
      _showMessage(error.userMessage);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _resending = true);
    try {
      final response = await _beatNowService.sendConfirmationEmail();
      final retryAfter = response['retry_after'];
      _startResendCooldown(retryAfter is int ? retryAfter : 60);
      _showMessage('A new code has been sent.');
    } on ApiException catch (error) {
      if (error.statusCode == 429) {
        _startResendCooldown(error.retryAfter ?? 60);
      }
      _showMessage(error.userMessage);
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
        backgroundColor: BeatNowTokens.surface3,
      ),
    );
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    if (!mounted) {
      _resendSeconds = seconds;
      return;
    }

    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }
}
