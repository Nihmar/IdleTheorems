import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/save_data.dart';

/// Single typed box, single key, atomic writes (plan section 14.1).
/// The value is hand-rolled JSON so the schema stays testable without codegen.
class SaveService {
  static const String _boxName = 'main_save';
  static const String _currentKey = 'current';

  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  /// Returns the loaded save or null when none exists / it is unreadable.
  Future<SaveData?> load() async {
    final raw = _box.get(_currentKey);
    if (raw == null) return null;
    try {
      return SaveData.fromJson(
        jsonDecode(raw as String) as Map<String, dynamic>,
      );
    } catch (e) {
      // Corrupt or unsupported version: start fresh rather than crash.
      // (Migration chain lives in SaveData.migrate.)
      throw StateError('Unreadable save data: $e');
    }
  }

  Future<void> save(SaveData data) =>
      _box.put(_currentKey, jsonEncode(data.toJson()));

  Future<void> clear() => _box.delete(_currentKey);
}
