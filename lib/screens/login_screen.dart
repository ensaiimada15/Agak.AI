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
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 43),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset('assets/images/logo.png', height: 175),
              const SizedBox(height: 40),
              _LoginField(
                controller: _emailController,
                hint: 'Email',
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                  onPressed: _emailController.clear,
                ),
              ),
              const SizedBox(height: 12),
              _LoginField(
                controller: _passwordController,
                hint: 'Password',
                obscure: _obscurePassword,
                trailing: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.black54,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 12),
              _LoginField(controller: _seniorIdController, hint: 'Senior ID'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Forgot Password?',
                      style: TextStyle(color: Colors.black54)),
                ),
              ),
              const SizedBox(height: 130),
              SizedBox(
                width: double.infinity,
                height: 43,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Log in',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
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
      height: 43,
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: AppTheme.headline(size: 13.5, color: Colors.black).copyWith(
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0x6E000000), fontSize: 13.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 22),
          suffixIcon: trailing,
        ),
      ),
    );
  }
}
