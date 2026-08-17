import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _seniorIdController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _seniorIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final seniorId = _seniorIdController.text.trim();
    final password = _passwordController.text.trim();

    if (seniorId.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Query public.user table directly for matching senior_id AND password
      // Note: Change 'user' below to 'profiles' if your table is named profiles
      final userRecord = await supabase
          .from('user')
          .select()
          .eq('senior_id', seniorId)
          .eq('password', password)
          .maybeSingle();

      if (userRecord == null) {
        throw Exception('Invalid Senior ID or Password.');
      }

      // Remember who logged in so the greeting, profile modal, benefits
      // filter, and LLM personalization all use THIS senior's data.
      ProfileService.setCurrentUser(userRecord['id'] as int);

      if (!mounted) return;

      // 3. Navigate to main application shell
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AppShell(),
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          // Calm entrance: the login form fades in gently.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 150,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_balance_wallet,
                      size: 80,
                      color: AppColors.navy,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Header
                Center(
                  child: Text(
                    'Welcome back',
                    style: AppTheme.headline(
                      size: 20,
                      color: AppColors.ink,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                const Center(
                  child: Text(
                    'Log in to continue',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.black54,
                      fontFamily: 'Rubik',
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Senior ID Field
                const _FieldLabel(label: 'Senior ID'),
                const SizedBox(height: 7),
                _LoginField(
                  controller: _seniorIdController,
                  hint: 'Enter your Senior ID',
                ),

                const SizedBox(height: 16),

                // Password Field
                const _FieldLabel(label: 'Password'),
                const SizedBox(height: 7),
                _LoginField(
                  controller: _passwordController,
                  hint: 'Enter your password',
                  obscure: _obscurePassword,
                  trailing: IconButton(
                    splashRadius: 20,
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black54,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontFamily: 'Rubik',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Log in',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rubik',
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// FIELD LABEL
// =============================================================================

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF11221D),
        fontFamily: 'Rubik',
      ),
    );
  }
}

// =============================================================================
// LOGIN FIELD
// =============================================================================

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: AppTheme.headline(
          size: 13.5,
          color: Colors.black,
        ).copyWith(
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0x6E000000),
            fontSize: 13.5,
            fontFamily: 'Rubik',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          suffixIcon: trailing,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 46,
          ),
        ),
      ),
    );
  }
}
