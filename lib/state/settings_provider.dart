import 'package:flutter/material.dart';
import 'settings_model.dart';

/// Provides [SettingsModel] to the widget tree via [InheritedNotifier].
///
/// Place this above [MaterialApp] so the theme can follow the setting.
class SettingsProvider extends InheritedNotifier<SettingsModel> {
  const SettingsProvider({
    super.key,
    required SettingsModel model,
    required super.child,
  }) : super(notifier: model);

  /// Retrieves the nearest [SettingsModel]; dependents rebuild on change.
  static SettingsModel of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    assert(provider != null, 'No SettingsProvider found in widget tree');
    return provider!.notifier!;
  }
}
