import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/news_article.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'elenni_app.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create news articles table
    await db.execute('''
      CREATE TABLE articles(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        content TEXT,
        url TEXT NOT NULL,
        imageUrl TEXT,
        publishDate TEXT NOT NULL,
        sourceId TEXT NOT NULL,
        sourceName TEXT NOT NULL,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        isRead INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create radio stations table
    await db.execute('''
      CREATE TABLE radio_stations(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        streamUrl TEXT NOT NULL,
        logoUrl TEXT,
        region TEXT NOT NULL,
        genre TEXT NOT NULL,
        description TEXT,
        country TEXT,
        language TEXT,
        website TEXT,
        isFavorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add radio stations table in version 2
      await db.execute('''
        CREATE TABLE radio_stations(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          streamUrl TEXT NOT NULL,
          logoUrl TEXT,
          region TEXT NOT NULL,
          genre TEXT NOT NULL,
          description TEXT,
          country TEXT,
          language TEXT,
          website TEXT,
          isFavorite INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  // CRUD Operations for NewsArticle

  Future<int> insertArticle(NewsArticle article) async {
    final db = await database;
    return await db.insert(
      'articles',
      article.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertArticles(List<NewsArticle> articles) async {
    final db = await database;
    final batch = db.batch();

    for (var article in articles) {
      batch.insert(
        'articles',
        article.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<NewsArticle>> getArticles({
    String? sourceId,
    int limit = 50,
    int offset = 0,
    bool favoritesOnly = false,
  }) async {
    final db = await database;

    String query = 'SELECT * FROM articles';
    List<dynamic> arguments = [];

    if (sourceId != null || favoritesOnly) {
      query += ' WHERE';

      if (sourceId != null) {
        query += ' sourceId = ?';
        arguments.add(sourceId);
      }

      if (favoritesOnly) {
        if (sourceId != null) query += ' AND';
        query += ' isFavorite = 1';
      }
    }

    query += ' ORDER BY publishDate DESC LIMIT ? OFFSET ?';
    arguments.add(limit);
    arguments.add(offset);

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);

    return List.generate(maps.length, (i) {
      return NewsArticle.fromMap(maps[i]);
    });
  }

  Future<NewsArticle?> getArticleById(String id) async {
    final db = await database;
    final maps = await db.query(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return NewsArticle.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateArticle(NewsArticle article) async {
    final db = await database;
    return await db.update(
      'articles',
      article.toMap(),
      where: 'id = ?',
      whereArgs: [article.id],
    );
  }

  Future<int> deleteArticle(String id) async {
    final db = await database;
    return await db.delete(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteOldArticles(int daysToKeep) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    return await db.delete(
      'articles',
      where: 'publishDate < ? AND isFavorite = 0',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<void> markArticleAsRead(String id) async {
    final db = await database;
    await db.update(
      'articles',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleFavorite(String id) async {
    final db = await database;
    final article = await getArticleById(id);

    if (article != null) {
      await db.update(
        'articles',
        {'isFavorite': article.isFavorite ? 0 : 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // CRUD Operations for Radio Stations

  Future<int> insertRadioStation(Map<String, dynamic> station) async {
    final db = await database;
    return await db.insert(
      'radio_stations',
      station,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRadioStations({
    String? region,
    String? genre,
    int limit = 50,
    int offset = 0,
    bool favoritesOnly = false,
  }) async {
    final db = await database;

    String query = 'SELECT * FROM radio_stations';
    List<dynamic> arguments = [];

    if (region != null || genre != null || favoritesOnly) {
      query += ' WHERE';

      if (region != null) {
        query += ' region = ?';
        arguments.add(region);
      }

      if (genre != null) {
        if (region != null) query += ' AND';
        query += ' genre = ?';
        arguments.add(genre);
      }

      if (favoritesOnly) {
        if (region != null || genre != null) query += ' AND';
        query += ' isFavorite = 1';
      }
    }

    query += ' ORDER BY name ASC LIMIT ? OFFSET ?';
    arguments.add(limit);
    arguments.add(offset);

    return await db.rawQuery(query, arguments);
  }

  Future<Map<String, dynamic>?> getRadioStationById(String id) async {
    final db = await database;
    final maps = await db.query(
      'radio_stations',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> toggleRadioStationFavorite(String id) async {
    final db = await database;
    final station = await getRadioStationById(id);

    if (station != null) {
      await db.update(
        'radio_stations',
        {'isFavorite': station['isFavorite'] == 1 ? 0 : 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}
