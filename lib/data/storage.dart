import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/models/app_settings.dart';
import '../core/models/signal.dart';

class SettingsRepository {
  static const _key = 'settings_v1';

  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }
}

/// API keys live in Android Keystore-backed secure storage, never in source.
/// Note: a key a client app can read is not truly secret; for production use
/// a server-side relay.
class ApiKeyStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'market_api_key';

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  Future<void> clear() => _storage.delete(key: _key);
}

class SignalRepository {
  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;
    final path = p.join(await getDatabasesPath(), 'signals.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) => db.execute(
          'CREATE TABLE signals(id TEXT PRIMARY KEY, created INTEGER, json TEXT)'),
    );
    _db = db;
    return db;
  }

  Future<void> upsert(Signal s) async {
    final db = await _open();
    await db.insert(
      'signals',
      {
        'id': s.id,
        'created': s.createdAt.millisecondsSinceEpoch,
        'json': jsonEncode(s.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Signal>> recent({int limit = 100}) async {
    final db = await _open();
    final rows = await db.query('signals', orderBy: 'created DESC', limit: limit);
    final out = <Signal>[];
    for (final r in rows) {
      try {
        out.add(Signal.fromJson(jsonDecode(r['json'] as String) as Map<String, dynamic>));
      } catch (_) {
        // skip rows written by an incompatible older version
      }
    }
    return out;
  }

  Future<void> clear() async {
    final db = await _open();
    await db.delete('signals');
  }
}
