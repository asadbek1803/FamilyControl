import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('family_control.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE child_devices (
        id TEXT PRIMARY KEY,
        device_identifier TEXT,
        device_name TEXT,
        is_active INTEGER DEFAULT 0,
        battery_level REAL,
        last_seen TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE installed_apps (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        app_name TEXT,
        package_name TEXT,
        is_blocked INTEGER DEFAULT 0,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE location_logs (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        accuracy REAL,
        recorded_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_usage_logs (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        package_name TEXT,
        total_time_ms INTEGER,
        start_time TEXT,
        end_time TEXT,
        recorded_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE notification_logs (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        package_name TEXT,
        title TEXT,
        notification_text TEXT,
        recorded_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        body TEXT,
        headers TEXT,
        created_at TEXT,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE geo_zones (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_time_limits (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        package_name TEXT NOT NULL,
        limit_minutes INTEGER DEFAULT 0,
        is_blocked INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        is_blocked INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sos_alerts (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        status TEXT,
        created_at TEXT
      )
    ''');
  }

  // ---- Child Devices ----

  Future<void> upsertDevice(Map<String, dynamic> device) async {
    final db = await database;
    await db.insert(
      'child_devices',
      device,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final db = await database;
    return db.query('child_devices');
  }

  Future<Map<String, dynamic>?> getDevice(String id) async {
    final db = await database;
    final results =
        await db.query('child_devices', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> deleteDevice(String id) async {
    final db = await database;
    await db.delete('child_devices', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Installed Apps ----

  Future<void> upsertApps(List<Map<String, dynamic>> apps) async {
    final db = await database;
    final batch = db.batch();
    for (final app in apps) {
      batch.insert('installed_apps', app,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getApps(String deviceId) async {
    final db = await database;
    return db.query(
      'installed_apps',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'app_name ASC',
    );
  }

  Future<void> updateAppBlocked(String appId, bool isBlocked) async {
    final db = await database;
    await db.update(
      'installed_apps',
      {'is_blocked': isBlocked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [appId],
    );
  }

  // ---- Location Logs ----

  Future<void> upsertLocations(List<Map<String, dynamic>> logs) async {
    final db = await database;
    final batch = db.batch();
    for (final log in logs) {
      batch.insert('location_logs', log,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getLocations(
    String deviceId, {
    int limit = 50,
  }) async {
    final db = await database;
    return db.query(
      'location_logs',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
  }

  // ---- App Usage Logs ----

  Future<void> upsertUsageLogs(List<Map<String, dynamic>> logs) async {
    final db = await database;
    final batch = db.batch();
    for (final log in logs) {
      batch.insert('app_usage_logs', log,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getUsageLogs(String deviceId) async {
    final db = await database;
    return db.query(
      'app_usage_logs',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'recorded_at DESC',
      limit: 100,
    );
  }

  // ---- Notification Logs ----

  Future<void> upsertNotifications(List<Map<String, dynamic>> logs) async {
    final db = await database;
    final batch = db.batch();
    for (final log in logs) {
      batch.insert('notification_logs', log,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getNotifications(String deviceId) async {
    final db = await database;
    return db.query(
      'notification_logs',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'recorded_at DESC',
      limit: 100,
    );
  }

  // ---- Sync Queue ----

  Future<void> addToSyncQueue({
    required String endpoint,
    required String method,
    String? body,
    String? headers,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'endpoint': endpoint,
      'method': method,
      'body': body,
      'headers': headers,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return db.query(
      'sync_queue',
      where: 'retry_count < 3',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deleteSyncItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementSyncRetry(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('child_devices');
    await db.delete('installed_apps');
    await db.delete('location_logs');
    await db.delete('app_usage_logs');
    await db.delete('notification_logs');
    await db.delete('sync_queue');
    await db.delete('geo_zones');
    await db.delete('app_time_limits');
    await db.delete('contacts');
    await db.delete('sos_alerts');
  }

  // ---- Geo Zones ----
  Future<void> upsertGeoZones(List<Map<String, dynamic>> zones) async {
    final db = await database;
    final batch = db.batch();
    for (final zone in zones) {
      batch.insert('geo_zones', zone,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getGeoZones(String deviceId) async {
    final db = await database;
    return db.query(
      'geo_zones',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ---- App Time Limits ----
  Future<void> upsertAppTimeLimits(List<Map<String, dynamic>> limits) async {
    final db = await database;
    final batch = db.batch();
    for (final limit in limits) {
      batch.insert('app_time_limits', limit,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAppTimeLimits(String deviceId) async {
    final db = await database;
    return db.query(
      'app_time_limits',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ---- Contacts ----
  Future<void> upsertContacts(List<Map<String, dynamic>> contacts) async {
    final db = await database;
    final batch = db.batch();
    for (final contact in contacts) {
      batch.insert('contacts', contact,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getContacts(String deviceId) async {
    final db = await database;
    return db.query(
      'contacts',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ---- SOS Alerts ----
  Future<void> insertSOSAlert(Map<String, dynamic> alert) async {
    final db = await database;
    await db.insert('sos_alerts', alert,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSOSAlerts(String deviceId) async {
    final db = await database;
    return db.query(
      'sos_alerts',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
  }
}
