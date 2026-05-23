import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

enum _Step { initial, phoneEntry, otpEntry }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _Step _step = _Step.initial;
  bool _loading = false;
  String? _errorMessage;
  String _verificationId = '';

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── Google ─────────────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    _setLoading(true);
    try {
      await AuthService.signInWithGoogle();
      // Router redirect handles navigation
    } catch (e) {
      _setError('Google sign-in failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final raw = _phoneController.text.trim();
    if (raw.length < 7) {
      _setError('Enter a valid phone number.');
      return;
    }
    final phone = raw.startsWith('+') ? raw : '+91$raw';
    _setLoading(true);
    _setError(null);

    await AuthService.verifyPhoneNumber(
      phoneNumber: phone,
      codeSent: (id, _) {
        if (mounted) {
          setState(() {
            _verificationId = id;
            _step = _Step.otpEntry;
            _loading = false;
          });
        }
      },
      onError: (msg) => _setError(msg),
      onAutoVerified: () {
        // Router redirect handles navigation
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _setError('Enter the 6-digit code.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      await AuthService.signInWithOtp(
        verificationId: _verificationId,
        smsCode: code,
      );
      // Router redirect handles navigation
    } catch (e) {
      _setError('Invalid OTP. Please try again.');
      _setLoading(false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    if (mounted) setState(() => _loading = v);
  }

  void _setError(String? msg) {
    if (mounted) setState(() => _errorMessage = msg);
  }

  void _back() => setState(() {
        _step = _step == _Step.otpEntry ? _Step.phoneEntry : _Step.initial;
        _errorMessage = null;
      });

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // ── Logo ──────────────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.format_quote_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Stauso',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Beautiful quotes for every moment',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 56),
              // ── Step content ──────────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: switch (_step) {
                    _Step.initial => _InitialStep(
                        key: const ValueKey('initial'),
                        loading: _loading,
                        onGoogle: _signInWithGoogle,
                        onPhone: () => setState(() {
                          _step = _Step.phoneEntry;
                          _errorMessage = null;
                        }),
                      ),
                    _Step.phoneEntry => _PhoneStep(
                        key: const ValueKey('phone'),
                        controller: _phoneController,
                        loading: _loading,
                        onSend: _sendOtp,
                        onBack: _back,
                      ),
                    _Step.otpEntry => _OtpStep(
                        key: const ValueKey('otp'),
                        controller: _otpController,
                        phone: _phoneController.text.trim(),
                        loading: _loading,
                        onVerify: _verifyOtp,
                        onBack: _back,
                      ),
                  },
                ),
              ),
              // ── Error ─────────────────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // ── Terms ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'By continuing you agree to our Terms of Service\nand Privacy Policy',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Initial step ─────────────────────────────────────────────────────────────

class _InitialStep extends StatelessWidget {
  final bool loading;
  final VoidCallback onGoogle;
  final VoidCallback onPhone;

  const _InitialStep({
    super.key,
    required this.loading,
    required this.onGoogle,
    required this.onPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Google button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: loading ? null : onGoogle,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'G',
                          style: GoogleFonts.roboto(
                            color: const Color(0xFF4285F4),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),
        // Phone button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: loading ? null : onPhone,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_outlined, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Continue with Phone',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Phone entry step ─────────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  final VoidCallback onBack;

  const _PhoneStep({
    super.key,
    required this.controller,
    required this.loading,
    required this.onSend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your phone number',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 22,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll send you a one-time verification code.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSend(),
          decoration: InputDecoration(
            hintText: '10-digit mobile number',
            prefixText: '+91  ',
            prefixStyle: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : onSend,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send OTP'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onBack,
          child: const Text('← Back'),
        ),
      ],
    );
  }
}

// ─── OTP entry step ───────────────────────────────────────────────────────────

class _OtpStep extends StatelessWidget {
  final TextEditingController controller;
  final String phone;
  final bool loading;
  final VoidCallback onVerify;
  final VoidCallback onBack;

  const _OtpStep({
    super.key,
    required this.controller,
    required this.phone,
    required this.loading,
    required this.onVerify,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify your number',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 22,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to +91 $phone',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 10,
            color: AppColors.textPrimary,
          ),
          onSubmitted: (_) => onVerify(),
          decoration: const InputDecoration(
            hintText: '• • • • • •',
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : onVerify,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify & Continue'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onBack,
          child: const Text('← Change number'),
        ),
      ],
    );
  }
}
