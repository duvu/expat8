part of 'local_database.dart';

/// Device id, user session and key-value settings.
extension LocalDatabaseIdentity on LocalDatabase {
  Future<String> getOrCreateDeviceId(String Function() createId) async {
    final existing = await getSetting('device_id');
    if (existing != null && existing.isNotEmpty) {
      final normalized = _anonymousDeviceId(existing);
      if (normalized != existing) {
        await setSetting('device_id', normalized);
      }
      return normalized;
    }

    final deviceId = _anonymousDeviceId(createId());
    await setSetting('device_id', deviceId);
    return deviceId;
  }

  String _anonymousDeviceId(String value) {
    return value.startsWith('anonymous_') ? value : 'anonymous_$value';
  }

  Future<void> saveUserSession(UserSession session) async {
    await setSetting('user_session', jsonEncode(session.toJson()));
  }

  Future<UserSession?> loadUserSession() async {
    final raw = await getSetting('user_session');
    if (raw == null) {
      return null;
    }
    return UserSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearUserSession() async {
    final query =
        _settings.query(AppSettingEntity_.key.equals('user_session')).build();
    final row = query.findFirst();
    if (row != null) {
      _settings.remove(row.id);
    }
  }

  Future<String?> getSetting(String key) async {
    final row =
        _settings.query(AppSettingEntity_.key.equals(key)).build().findFirst();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    final existing =
        _settings.query(AppSettingEntity_.key.equals(key)).build().findFirst();
    _settings.put(
      AppSettingEntity(
        id: existing?.id ?? 0,
        key: key,
        value: value,
      ),
    );
  }
}
