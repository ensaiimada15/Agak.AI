import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings/app_settings.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/responsive_frame.dart';

class AppSettingsScope extends InheritedWidget {
  const AppSettingsScope({
    super.key,
    required this.settings,
    required super.child,
  });

  final AppSettings settings;

  static AppSettings of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(result != null, 'No AppSettingsScope found in context');
    return result!.settings;
  }

  @override
  bool updateShouldNotify(AppSettingsScope oldWidget) => true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_KEY']
  );

  final appSettings = AppSettings();
  await appSettings.init();

  runApp(AgakAIApp(settings: appSettings));
}

class AgakAIApp extends StatelessWidget {
  const AgakAIApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, child) {
        return AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            title: 'AgakAI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              // Apply the settings text scale (standard / enlarged) to the
              // whole app on top of the device's own font scale.
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.textScale),
              ),
              child: ResponsiveFrame(child: child!),
            ),
            home: const LoginScreen(),
          ),
        );
      },
    );
  }
}
