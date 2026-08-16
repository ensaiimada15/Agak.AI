import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/responsive_frame.dart';

Future<void> main() async {
  // Required when executing async code inside main() before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables if using dotenv
  await dotenv.load(fileName: '.env');

  // Initialize Supabase BEFORE running the app
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const AgakAIApp());
}

class AgakAIApp extends StatelessWidget {
  const AgakAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgakAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => ResponsiveFrame(child: child!),
      home: const LoginScreen(),
    );
  }
}