import 'dart:convert';

import '../../../domain/ports/app_database.dart';

/// Typed helpers over the raw JSON settings store of an [AppDatabase].
///
/// Every value is stored as its JSON encoding, so one string column works for
/// strings, booleans, numbers and string lists alike, and a future backend
/// needs no extra columns. Decoding is hostile-safe: a value of the wrong JSON
/// type (schema drift, a hand-edited store) reads back as `null` rather than
/// throwing.
extension AppDatabaseValues on AppDatabase {
  Future<String?> readString(String key) async =>
      _decode<String>(await readSetting(key));

  Future<void> writeString(String key, String value) =>
      writeSetting(key, jsonEncode(value));

  Future<bool?> readBool(String key) async =>
      _decode<bool>(await readSetting(key));

  Future<void> writeBool(String key, bool value) =>
      writeSetting(key, jsonEncode(value));

  Future<int?> readInt(String key) async =>
      _decode<int>(await readSetting(key));

  Future<void> writeInt(String key, int value) =>
      writeSetting(key, jsonEncode(value));

  /// Reads a list of strings; non-string entries are skipped and a non-list
  /// value reads back as `null`.
  Future<List<String>?> readStringList(String key) async {
    final String? raw = await readSetting(key);
    if (raw == null) {
      return null;
    }
    final Object? decoded = _decodeJson(raw);
    if (decoded is! List) {
      return null;
    }
    final List<String> result = <String>[];
    for (final Object? item in decoded) {
      if (item is String) {
        result.add(item);
      }
    }
    return result;
  }

  Future<void> writeStringList(String key, List<String> value) =>
      writeSetting(key, jsonEncode(value));

  /// Returns the decoded value when it has type [T], else `null`.
  T? _decode<T>(String? raw) {
    if (raw == null) {
      return null;
    }
    final Object? decoded = _decodeJson(raw);
    return decoded is T ? decoded : null;
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
