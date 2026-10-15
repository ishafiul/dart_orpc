import 'package:dart_orpc/dart_orpc.dart';

import 'challenge_auth.dart';
import 'challenge_database.dart';
import 'challenge_dtos.dart';

final class ChallengeService {
  ChallengeService(this._database);

  final ChallengeDatabase _database;

  static final Stopwatch _uptime = Stopwatch()..start();

  HealthResponseDto health() {
    final isHealthy = _database.isHealthy;
    return HealthResponseDto(
      status: isHealthy ? 'ok' : 'degraded',
      database: isHealthy ? 'ok' : 'unreachable',
      uptimeSeconds: _uptime.elapsed.inSeconds,
    );
  }

  FeedResponseDto feed() => FeedResponseDto(_database.getFeed());

  PostResponseDto getPost(String rawId) {
    final postId = _parsePostId(rawId);
    final post = _database.getPost(postId);
    if (post == null) {
      throw RpcException.notFound('post not found');
    }
    return PostResponseDto(post);
  }

  CreatePostResponseDto createPost(
    ChallengeIdentity identity,
    JsonObject requestBody,
  ) {
    final body = _validatedPostBody(requestBody);
    final post = _database.createPost(
      userId: identity.userId,
      username: identity.username,
      body: body,
    );
    return CreatePostResponseDto(post);
  }

  LikeResponseDto likePost(ChallengeIdentity identity, String rawId) {
    final postId = _parsePostId(rawId);
    final result = _database.likePost(userId: identity.userId, postId: postId);
    if (!result.postExists) {
      throw RpcException.notFound('post not found');
    }
    return LikeResponseDto(
      liked: true,
      alreadyLiked: !result.created,
      postId: postId,
    );
  }
}

int _parsePostId(String rawId) {
  final postId = int.tryParse(rawId);
  if (postId == null || postId <= 0 || rawId != '$postId') {
    throw RpcException.badRequest('invalid post id');
  }
  return postId;
}

String _validatedPostBody(JsonObject requestBody) {
  final value = requestBody['body'];
  if (value is! String || value.trim().isEmpty) {
    throw RpcException.badRequest('body is required');
  }
  final body = value.trim();
  if (body.runes.length > 500) {
    throw RpcException.badRequest('body must be at most 500 characters');
  }
  return body;
}
