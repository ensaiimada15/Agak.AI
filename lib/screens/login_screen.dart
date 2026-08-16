import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _seniorIdController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _seniorIdController.dispose();
    super.dispose();
  }

  void _login() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AppShell(),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56),

              // Logo
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 150,
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

              Center(
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

              // Email
              const _FieldLabel(
                label: 'Email',
              ),
              const SizedBox(height: 7),

              _LoginField(
                controller: _emailController,
                hint: 'Enter your email',
              ),

              const SizedBox(height: 16),

              // Password
              const _FieldLabel(
                label: 'Password',
              ),
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

              const SizedBox(height: 16),

              // Senior ID
              const _FieldLabel(
                label: 'Senior ID',
              ),
              const SizedBox(height: 7),

              _LoginField(
                controller: _seniorIdController,
                hint: 'Enter your Senior ID',
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
                    tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
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

              const SizedBox(height: 112),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
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
    );
  }
}

// =============================================================================
// FIELD LABEL
// =============================================================================

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
  });

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