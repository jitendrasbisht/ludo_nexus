import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_bg_theme.dart';

/// Persists the player's chosen background theme across launches and
/// exposes it as a [ValueNotifier] so every screen showing [AppBackground]
/// (or an AppBar colored to match it) updates live the moment it's
/// changed, without needing to navigate away and back.
class ThemeStore {
  static const _key = 'ludo_bg_theme';
  static final ValueNotifier<AppBgTheme> current = ValueNotifier(AppBgTheme.navy);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return;
    current.value = AppBgTheme.values.firstWhere(
      (t) => t.name == saved,
      orElse: () => AppBgTheme.navy,
    );
  }

  static Future<void> select(AppBgTheme theme) async {
    current.value = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.name);
  }
}
