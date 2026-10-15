import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'challenge_dtos.dart';

final class LikeWriteResult {
  const LikeWriteResult({required this.postExists, required this.created});

  final bool postExists;
  final bool created;
}

final class ChallengeDatabase {
  ChallengeDatabase() : this._withDatabase(_openDatabase());

  ChallengeDatabase._withDatabase(this._database)
    : _feedQuery = _database.prepare(
        '''
        SELECT p.id, p.body, p.created_at, u.username AS author,
               (SELECT count(*) FROM likes l WHERE l.post_id = p.id) AS like_count
        FROM posts p
        JOIN users u ON u.id = p.user_id
        ORDER BY p.created_at DESC, p.id DESC
        LIMIT 20
      ''',
      ),
      _postByIdQuery = _database.prepare('''
        SELECT p.id, p.body, p.created_at, u.username AS author,
               (SELECT count(*) FROM likes l WHERE l.post_id = p.id) AS like_count
        FROM posts p
        JOIN users u ON u.id = p.user_id
        WHERE p.id = ?
      '''),
      _postExistsQuery = _database.prepare('SELECT 1 FROM posts WHERE id = ?'),
      _insertPostQuery = _database.prepare('''
        INSERT INTO posts (user_id, body)
        VALUES (?, ?)
        RETURNING id, created_at
      '''),
      _insertLikeQuery = _database.prepare('''
        INSERT INTO likes (user_id, post_id)
        VALUES (?, ?)
        ON CONFLICT (user_id, post_id) DO NOTHING
        RETURNING 1
      ''');

  static Database _openDatabase() {
    final path = Platform.environment['SQLITE_PATH'];
    if (path == null || path.isEmpty) {
      throw StateError('SQLITE_PATH is required.');
    }
    final database = sqlite3.open(path);
    database.execute('PRAGMA foreign_keys = ON;');
    database.execute('PRAGMA journal_mode = WAL;');
    database.execute('PRAGMA synchronous = NORMAL;');
    return database;
  }

  final Database _database;
  final PreparedStatement _feedQuery;
  final PreparedStatement _postByIdQuery;
  final PreparedStatement _postExistsQuery;
  final PreparedStatement _insertPostQuery;
  final PreparedStatement _insertLikeQuery;

  bool get isHealthy => _database.select('SELECT 1').isNotEmpty;

  List<PostDto> getFeed() => [
    for (final row in _feedQuery.select()) _postFromRow(row),
  ];

  PostDto? getPost(int postId) {
    final rows = _postByIdQuery.select([postId]);
    return rows.isEmpty ? null : _postFromRow(rows.first);
  }

  PostDto createPost({
    required int userId,
    required String username,
    required String body,
  }) {
    final row = _insertPostQuery.select([userId, body]).first;
    return PostDto(
      id: row['id'] as int,
      body: body,
      createdAt: row['created_at'] as String,
      author: username,
      likeCount: 0,
    );
  }

  LikeWriteResult likePost({required int userId, required int postId}) {
    _database.execute('BEGIN IMMEDIATE;');
    try {
      if (_postExistsQuery.select([postId]).isEmpty) {
        _database.execute('COMMIT;');
        return const LikeWriteResult(postExists: false, created: false);
      }
      final created = _insertLikeQuery.select([userId, postId]).isNotEmpty;
      _database.execute('COMMIT;');
      return LikeWriteResult(postExists: true, created: created);
    } on Object {
      _database.execute('ROLLBACK;');
      rethrow;
    }
  }

  PostDto _postFromRow(Row row) => PostDto(
    id: row['id'] as int,
    body: row['body'] as String,
    createdAt: row['created_at'] as String,
    author: row['author'] as String,
    likeCount: row['like_count'] as int,
  );
}
