import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../../../l10n/app_localizations.dart';

class OTPScreen extends StatefulWidget {
  final String phone;
  const OTPScreen({super.key, required this.phone});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  late final List<TextEditingController> _controllers;
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
  }

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // AuthAuthenticated: GoRouter's redirect handles role-based navigation
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.otpVerification),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    l10n.enterCode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.otpSentTo(widget.phone),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _buildDigitBox(i)),
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final loading = state is AuthLoading;
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (loading || _otp.length < 6) ? null : _verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(l10n.verifyButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        context.read<AuthCubit>().sendOtp(widget.phone);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.otpResent)),
                        );
                      },
                      child: Text(l10n.resendOtp),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          setState(() {});
          if (_otp.length == 6) _verify();
        },
      ),
    );
  }

  void _verify() {
    if (_otp.length == 6) {
      context.read<AuthCubit>().verifyOtp(widget.phone, _otp);
    }
  }
}
