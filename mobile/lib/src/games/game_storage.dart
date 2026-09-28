import '../data/local_database.dart';

/// Minimal key-value persistence for games. Everything is stored on the
/// device so games work without a backend connection.
abstract class GameStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Stores game data in the app's ObjectBox settings table.
class LocalDatabaseGameStorage implements GameStorage {
  LocalDatabaseGameStorage(this.database);

  final LocalDatabase database;

  @override
  Future<String?> read(String key) async {
    final value = await database.getSetting(key);
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<void> write(String key, String value) =>
      database.setSetting(key, value);

  @override
  Future<void> remove(String key) => database.setSetting(key, '');
}

/// In-memory storage for tests and previews.
class InMemoryGameStorage implements GameStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
