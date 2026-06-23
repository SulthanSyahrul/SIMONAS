import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredAuthSession {
  final String userId;
  final String role;
  final DateTime savedAt;
  final DateTime expiresAt;

  const StoredAuthSession({
    required this.userId,
    required this.role,
    required this.savedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': userId,
      'role': role,
      'savedAt': savedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory StoredAuthSession.fromMap(Map<String, dynamic> map) {
    final savedAt =
        DateTime.tryParse((map['savedAt'] ?? '').toString()) ?? DateTime.now();
    final expiresAt =
        DateTime.tryParse((map['expiresAt'] ?? '').toString()) ?? savedAt;

    return StoredAuthSession(
      userId: (map['id'] ?? map['uid'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      savedAt: savedAt,
      expiresAt: expiresAt,
    );
  }
}

class AuthSessionService {
  static const String _sessionKey = 'auth_session';
  static const Duration sessionLifetime = Duration(days: 30);

  Future<void> saveSession({
    required String userId,
    required String role,
    Duration? ttl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final session = StoredAuthSession(
      userId: userId,
      role: role,
      savedAt: now,
      expiresAt: now.add(ttl ?? sessionLifetime),
    );

    await prefs.setString(_sessionKey, jsonEncode(session.toMap()));
  }

  Future<StoredAuthSession?> getStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final session = StoredAuthSession.fromMap(map);
      if (session.userId.trim().isEmpty || session.role.trim().isEmpty) {
        await clearSession();
        return null;
      }
      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<StoredAuthSession?> getValidSession() async {
    final session = await getStoredSession();
    if (session == null) {
      return null;
    }

    if (session.isExpired) {
      await clearSession();
      return null;
    }

    return session;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
