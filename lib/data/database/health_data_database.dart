import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class HealthDataDatabase {
  static final HealthDataDatabase instance = HealthDataDatabase._init();
  static Database? _database;

  HealthDataDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('health_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Heart Rate table
    await db.execute('''
      CREATE TABLE heart_rate (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        bpm REAL NOT NULL,
        source TEXT,
        UNIQUE(timestamp)
      )
    ''');

    // SpO2 table
    await db.execute('''
      CREATE TABLE spo2 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        percentage REAL NOT NULL,
        source TEXT,
        UNIQUE(timestamp)
      )
    ''');

    // Sleep Session table
    await db.execute('''
      CREATE TABLE sleep_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        light_minutes INTEGER,
        deep_minutes INTEGER,
        rem_minutes INTEGER,
        awake_minutes INTEGER,
        source TEXT,
        UNIQUE(start_time, end_time)
      )
    ''');

    // Create indexes for better query performance
    await db.execute(
      'CREATE INDEX idx_heart_rate_timestamp ON heart_rate(timestamp)',
    );
    await db.execute('CREATE INDEX idx_spo2_timestamp ON spo2(timestamp)');
    await db.execute(
      'CREATE INDEX idx_sleep_start_time ON sleep_session(start_time)',
    );
  }

  // Insert heart rate with conflict resolution
  Future<void> insertHeartRate({
    required int timestamp,
    required double bpm,
    String? source,
  }) async {
    final db = await database;
    await db.insert('heart_rate', {
      'timestamp': timestamp,
      'bpm': bpm,
      'source': source,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Insert SpO2 with conflict resolution
  Future<void> insertSpO2({
    required int timestamp,
    required double percentage,
    String? source,
  }) async {
    final db = await database;
    await db.insert('spo2', {
      'timestamp': timestamp,
      'percentage': percentage,
      'source': source,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Insert sleep session with conflict resolution
  Future<void> insertSleepSession({
    required int startTime,
    required int endTime,
    int? lightMinutes,
    int? deepMinutes,
    int? remMinutes,
    int? awakeMinutes,
    String? source,
  }) async {
    final db = await database;
    await db.insert('sleep_session', {
      'start_time': startTime,
      'end_time': endTime,
      'light_minutes': lightMinutes,
      'deep_minutes': deepMinutes,
      'rem_minutes': remMinutes,
      'awake_minutes': awakeMinutes,
      'source': source,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Batch insert heart rate data
  Future<void> batchInsertHeartRate(List<Map<String, dynamic>> data) async {
    final db = await database;
    final batch = db.batch();
    for (final item in data) {
      batch.insert(
        'heart_rate',
        item,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // Batch insert SpO2 data
  Future<void> batchInsertSpO2(List<Map<String, dynamic>> data) async {
    final db = await database;
    final batch = db.batch();
    for (final item in data) {
      batch.insert('spo2', item, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // Batch insert sleep sessions
  Future<void> batchInsertSleepSessions(List<Map<String, dynamic>> data) async {
    final db = await database;
    final batch = db.batch();
    for (final item in data) {
      batch.insert(
        'sleep_session',
        item,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // Query heart rate within time range
  Future<List<Map<String, dynamic>>> queryHeartRate({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    return await db.query(
      'heart_rate',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startTime, endTime],
      orderBy: 'timestamp ASC',
    );
  }

  // Query SpO2 within time range
  Future<List<Map<String, dynamic>>> querySpO2({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    return await db.query(
      'spo2',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startTime, endTime],
      orderBy: 'timestamp ASC',
    );
  }

  // Query sleep sessions within time range
  Future<List<Map<String, dynamic>>> querySleepSessions({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    return await db.query(
      'sleep_session',
      where: 'start_time BETWEEN ? AND ?',
      whereArgs: [startTime, endTime],
      orderBy: 'start_time ASC',
    );
  }

  // Get all heart rate data (for debugging)
  Future<List<Map<String, dynamic>>> getAllHeartRate() async {
    final db = await database;
    return await db.query('heart_rate', orderBy: 'timestamp DESC', limit: 100);
  }

  // Get all SpO2 data (for debugging)
  Future<List<Map<String, dynamic>>> getAllSpO2() async {
    final db = await database;
    return await db.query('spo2', orderBy: 'timestamp DESC', limit: 100);
  }

  // Get all sleep sessions (for debugging)
  Future<List<Map<String, dynamic>>> getAllSleepSessions() async {
    final db = await database;
    return await db.query(
      'sleep_session',
      orderBy: 'start_time DESC',
      limit: 50,
    );
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('heart_rate');
    await db.delete('spo2');
    await db.delete('sleep_session');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
