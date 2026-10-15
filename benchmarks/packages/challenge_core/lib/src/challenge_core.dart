import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:sqlite3/sqlite3.dart';

final class ChallengeFailure implements Exception {
  const ChallengeFailure(this.statusCode, this.message);

  final int statusCode;
  final String message;
}

final class ChallengeIdentity {
  const ChallengeIdentity({required this.userId, required this.username});

  final int userId;
  final String username;
}

final class ChallengeHealth {
  const ChallengeHealth({
    required this.status,
    required this.database,
    required this.uptimeSeconds,
  });

  final String status;
  final String database;
  final int uptimeSeconds;

  Map<String, Object?> toJson() => {
    'status': status,
    'db': database,
    'uptime_s': uptimeSeconds,
  };
}

final class ChallengePost {
  const ChallengePost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
    required this.likeCount,
  });

  final int id;
  final String body;
  final String createdAt;
  final String author;
  final int likeCount;

  Map<String, Object?> toJson() => {
    'id': id,
    'body': body,
    'created_at': createdAt,
    'author': author,
    'like_count': likeCount,
  };
}

final class ChallengeFeed {
  const ChallengeFeed(this.posts);

  final List<ChallengePost> posts;

  Map<String, Object?> toJson() => {
    'posts': [for (final post in posts) post.toJson()],
  };
}

final class ChallengePostResponse {
  const ChallengePostResponse(this.post);

  final ChallengePost post;

  Map<String, Object?> toJson() => {'post': post.toJson()};
}

final class ChallengeLikeResponse {
  const ChallengeLikeResponse({
    required this.alreadyLiked,
    required this.postId,
  });

  final bool alreadyLiked;
  final int postId;

  Map<String, Object?> toJson() => {
    'liked': true,
    'already_liked': alreadyLiked,
    'post_id': postId,
  };
}

final class _LikeWriteResult {
  const _LikeWriteResult({required this.postExists, required this.created});

  final bool postExists;
  final bool created;
}

final class _ChallengeDatabase {
  _ChallengeDatabase(String path) : this._withDatabase(_openDatabase(path));

  _ChallengeDatabase._withDatabase(Database database)
    : _database = database,
      _feedQuery = database.prepare('''
        SELECT p.id, p.body, p.created_at, u.username AS author,
               (SELECT count(*) FROM likes l WHERE l.post_id = p.id) AS like_count
        FROM posts p
        JOIN users u ON u.id = p.user_id
        ORDER BY p.created_at DESC, p.id DESC
        LIMIT 20
      '''),
      _postByIdQuery = database.prepare('''
        SELECT p.id, p.body, p.created_at, u.username AS author,
               (SELECT count(*) FROM likes l WHERE l.post_id = p.id) AS like_count
        FROM posts p
        JOIN users u ON u.id = p.user_id
        WHERE p.id = ?
      '''),
      _postExistsQuery = database.prepare('SELECT 1 FROM posts WHERE id = ?'),
      _insertPostQuery = database.prepare('''
        INSERT INTO posts (user_id, body)
        VALUES (?, ?)
        RETURNING id, created_at
      '''),
      _insertLikeQuery = database.prepare('''
        INSERT INTO likes (user_id, post_id)
        VALUES (?, ?)
        ON CONFLICT (user_id, post_id) DO NOTHING
        RETURNING 1
      ''');

  static Database _openDatabase(String path) {
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

  List<ChallengePost> getFeed() => [
    for (final row in _feedQuery.select()) _postFromRow(row),
  ];

  ChallengePost? getPost(int postId) {
    final rows = _postByIdQuery.select([postId]);
    return rows.isEmpty ? null : _postFromRow(rows.first);
  }

  ChallengePost createPost({
    required int userId,
    required String username,
    required String body,
  }) {
    final row = _insertPostQuery.select([userId, body]).first;
    return ChallengePost(
      id: row['id'] as int,
      body: body,
      createdAt: row['created_at'] as String,
      author: username,
      likeCount: 0,
    );
  }

  _LikeWriteResult likePost({required int userId, required int postId}) {
    _database.execute('BEGIN IMMEDIATE;');
    try {
      if (_postExistsQuery.select([postId]).isEmpty) {
        _database.execute('COMMIT;');
        return const _LikeWriteResult(postExists: false, created: false);
      }
      final created = _insertLikeQuery.select([userId, postId]).isNotEmpty;
      _database.execute('COMMIT;');
      return _LikeWriteResult(postExists: true, created: created);
    } on Object {
      _database.execute('ROLLBACK;');
      rethrow;
    }
  }

  ChallengePost _postFromRow(Row row) => ChallengePost(
    id: row['id'] as int,
    body: row['body'] as String,
    createdAt: row['created_at'] as String,
    author: row['author'] as String,
    likeCount: row['like_count'] as int,
  );
}

final class ChallengeRuntime {
  ChallengeRuntime({String? databasePath, String? jwtSecret})
    : _databasePath = databasePath ?? Platform.environment['SQLITE_PATH'] ?? '',
      _jwtSecret =
          jwtSecret ??
          Platform.environment['JWT_SECRET'] ??
          'twelve-dollar-challenge';

  final String _databasePath;
  final String _jwtSecret;
  final Stopwatch _uptime = Stopwatch()..start();
  late final _ChallengeDatabase _database = _createDatabase();

  _ChallengeDatabase _createDatabase() {
    if (_databasePath.isEmpty) {
      throw StateError('SQLITE_PATH is required.');
    }
    return _ChallengeDatabase(_databasePath);
  }

  ChallengeHealth health() {
    final healthy = _database.isHealthy;
    return ChallengeHealth(
      status: healthy ? 'ok' : 'degraded',
      database: healthy ? 'ok' : 'unreachable',
      uptimeSeconds: _uptime.elapsed.inSeconds,
    );
  }

  ChallengeFeed feed() => ChallengeFeed(_database.getFeed());

  ChallengePostResponse getPost(String rawId) {
    final post = _database.getPost(_parsePostId(rawId));
    if (post == null) {
      throw const ChallengeFailure(HttpStatus.notFound, 'post not found');
    }
    return ChallengePostResponse(post);
  }

  ChallengePostResponse createPost(
    ChallengeIdentity identity,
    Object? requestBody,
  ) {
    final body = _validatedPostBody(requestBody);
    return ChallengePostResponse(
      _database.createPost(
        userId: identity.userId,
        username: identity.username,
        body: body,
      ),
    );
  }

  ChallengeLikeResponse likePost(ChallengeIdentity identity, String rawId) {
    final postId = _parsePostId(rawId);
    final result = _database.likePost(userId: identity.userId, postId: postId);
    if (!result.postExists) {
      throw const ChallengeFailure(HttpStatus.notFound, 'post not found');
    }
    return ChallengeLikeResponse(alreadyLiked: !result.created, postId: postId);
  }

  ChallengeIdentity authenticate(Map<String, String> headers) {
    final authorization = _findHeader(headers, 'authorization');
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      throw const ChallengeFailure(
        HttpStatus.unauthorized,
        'missing bearer token',
      );
    }

    final token = authorization.substring('Bearer '.length);
    final payload = _verifiedPayload(token);
    if (payload is! Map<String, dynamic>) {
      throw const ChallengeFailure(
        HttpStatus.unauthorized,
        'invalid token payload',
      );
    }

    final subject = payload['sub'];
    final username = payload['username'];
    if (subject is! String || username is! String) {
      throw const ChallengeFailure(
        HttpStatus.unauthorized,
        'invalid token payload',
      );
    }
    final userId = int.tryParse(subject);
    if (userId == null || userId <= 0 || subject != '$userId') {
      throw const ChallengeFailure(
        HttpStatus.unauthorized,
        'invalid token payload',
      );
    }
    return ChallengeIdentity(userId: userId, username: username);
  }

  Object? _verifiedPayload(String token) {
    try {
      _requireHs256(token);
      return JWT.verify(token, SecretKey(_jwtSecret)).payload;
    } on Object {
      throw const ChallengeFailure(
        HttpStatus.unauthorized,
        'invalid or expired token',
      );
    }
  }
}

final ChallengeRuntime challengeRuntime = ChallengeRuntime();

int _parsePostId(String rawId) {
  final postId = int.tryParse(rawId);
  if (postId == null || postId <= 0 || rawId != '$postId') {
    throw const ChallengeFailure(HttpStatus.badRequest, 'invalid post id');
  }
  return postId;
}

String _validatedPostBody(Object? requestBody) {
  if (requestBody is! Map) {
    throw const ChallengeFailure(HttpStatus.badRequest, 'body is required');
  }
  final value = requestBody['body'];
  if (value is! String || value.trim().isEmpty) {
    throw const ChallengeFailure(HttpStatus.badRequest, 'body is required');
  }
  final body = value.trim();
  if (body.runes.length > 500) {
    throw const ChallengeFailure(
      HttpStatus.badRequest,
      'body must be at most 500 characters',
    );
  }
  return body;
}

void _requireHs256(String token) {
  final segments = token.split('.');
  if (segments.length != 3 || segments.first.isEmpty) {
    throw const FormatException('Malformed JWT.');
  }
  final encodedHeader = base64Url.normalize(segments.first);
  final header = jsonDecode(utf8.decode(base64Url.decode(encodedHeader)));
  if (header is! Map<String, dynamic> || header['alg'] != 'HS256') {
    throw const FormatException('JWT must use HS256.');
  }
}

String? _findHeader(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name) {
      return entry.value;
    }
  }
  return null;
}
