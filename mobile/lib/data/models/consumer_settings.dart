import 'package:flutter/foundation.dart';

/// Mirrors `public.theme_enum` in `backend/db/structure.sql`.
///
/// Named `ThemePreference` (not `AppTheme`) to avoid colliding with
/// `mobile/lib/core/theme/app_theme.dart`'s `AppTheme` class.
enum ThemePreference { light, dark, system }

/// JSON (de)serialization for [ThemePreference] against `theme_enum`.
extension ThemePreferenceJson on ThemePreference {
  static ThemePreference fromJson(String value) => switch (value) {
    'light' => ThemePreference.light,
    'dark' => ThemePreference.dark,
    'system' => ThemePreference.system,
    _ => throw ArgumentError('Unknown theme_enum value: $value'),
  };

  String toJson() => switch (this) {
    ThemePreference.light => 'light',
    ThemePreference.dark => 'dark',
    ThemePreference.system => 'system',
  };
}

/// Domain model for `public.consumer_settings`.
///
/// Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
@immutable
class ConsumerSettings {
  const ConsumerSettings({
    required this.id,
    required this.consumerId,
    required this.theme,
    required this.notificationsEnabled,
  });

  final int id;
  final String consumerId;
  final ThemePreference theme;
  final bool notificationsEnabled;

  factory ConsumerSettings.fromJson(Map<String, dynamic> json) {
    return ConsumerSettings(
      id: json['id'] as int,
      consumerId: json['consumer_id'] as String,
      theme: ThemePreferenceJson.fromJson(json['theme'] as String),
      notificationsEnabled: json['notifications_enabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consumer_id': consumerId,
      'theme': theme.toJson(),
      'notifications_enabled': notificationsEnabled,
    };
  }
}
