import 'package:flutter/material.dart';
import 'app_settings.dart';

/// Makes a single [AppSettings] instance available to every descendant
/// widget, and rebuilds any widget that calls [AppSettingsScope.of] when
/// the settings change (because InheritedNotifier listens to the notifier
/// for you).
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'No AppSettingsScope found above this widget.');
    return scope!.notifier!;
  }
}

/// Sugar so call sites can write `context.settings` instead of
/// `AppSettingsScope.of(context)`.
extension AppSettingsContext on BuildContext {
  AppSettings get settings => AppSettingsScope.of(this);
}