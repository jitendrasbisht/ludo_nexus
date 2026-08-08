import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A remembered human player: name + photo, nothing game-specific.
class SavedProfile {
  final String name;
  final String? photoPath;

  const SavedProfile({required this.name, this.photoPath});

  Map<String, dynamic> toJson() => {'name': name, 'photoPath': photoPath};

  factory SavedProfile.fromJson(Map<String, dynamic> json) => SavedProfile(
        name: json['name'] as String? ?? '',
        photoPath: json['photoPath'] as String?,
      );
}

/// Remembers human players' name + photo across launches so the setup
/// screen can pre-fill them instead of starting blank every time.
class PlayerProfileStore {
  static const _key = 'ludo_saved_profiles';

  static Future<List<SavedProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => SavedProfile.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> save(List<SavedProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profiles.map((p) => p.toJson()).toList()));
  }
}
