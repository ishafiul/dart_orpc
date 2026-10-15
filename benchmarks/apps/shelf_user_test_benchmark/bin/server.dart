import 'dart:convert';
import 'dart:io';

import 'package:challenge_core/challenge_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Future<void> main() async {
  final router =
      Router(
          notFoundHandler: (_) =>
              _jsonResponse(HttpStatus.notFound, const {'error': 'not found'}),
        )
        ..get('/health', _health)
        ..get('/feed', _feed)
        ..get('/posts/<id>', _getPost)
        ..post('/posts', _createPost)
        ..post('/posts/<id>/like', _likePost);

  final host = Platform.environment['HOST'] ?? '127.0.0.1';
  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final server = await shelf_io.serve(router.call, host, port);
  stdout.writeln('READY shelf_user_test_benchmark ${server.port}');
}

Response _health(Request _) => _handleChallengeRequest(
  () => _ChallengeResult(body: challengeRuntime.health().toJson()),
);

Response _feed(Request _) => _handleChallengeRequest(
  () => _ChallengeResult(body: challengeRuntime.feed().toJson()),
);

Response _getPost(Request _, String id) => _handleChallengeRequest(
  () => _ChallengeResult(body: challengeRuntime.getPost(id).toJson()),
);

Future<Response> _createPost(Request request) =>
    _handleAsyncChallengeRequest(() async {
      final identity = challengeRuntime.authenticate(request.headers);
      final requestBody = jsonDecode(await request.readAsString());
      final result = challengeRuntime.createPost(identity, requestBody);
      return _ChallengeResult(
        statusCode: HttpStatus.created,
        body: result.toJson(),
      );
    });

Response _likePost(Request request, String id) => _handleChallengeRequest(() {
  final identity = challengeRuntime.authenticate(request.headers);
  final result = challengeRuntime.likePost(identity, id);
  return _ChallengeResult(
    statusCode: result.alreadyLiked ? HttpStatus.ok : HttpStatus.created,
    body: result.toJson(),
  );
});

Response _handleChallengeRequest(_ChallengeResult Function() action) {
  try {
    return _successResponse(action());
  } on Object catch (error) {
    return _errorResponse(error);
  }
}

Future<Response> _handleAsyncChallengeRequest(
  Future<_ChallengeResult> Function() action,
) async {
  try {
    return _successResponse(await action());
  } on Object catch (error) {
    return _errorResponse(error);
  }
}

Response _successResponse(_ChallengeResult result) =>
    _jsonResponse(result.statusCode, result.body);

Response _jsonResponse(int statusCode, Object? body) =>
    Response(statusCode, body: jsonEncode(body), headers: _jsonHeaders);

Response _errorResponse(Object error) {
  if (error is ChallengeFailure) {
    return _jsonErrorResponse(error.statusCode, error.message);
  }
  if (error is FormatException) {
    return _jsonErrorResponse(HttpStatus.badRequest, 'malformed JSON body');
  }
  return _jsonErrorResponse(
    HttpStatus.internalServerError,
    'internal server error',
  );
}

Response _jsonErrorResponse(int statusCode, String message) =>
    _jsonResponse(statusCode, {'error': message});

final class _ChallengeResult {
  const _ChallengeResult({required this.body, this.statusCode = HttpStatus.ok});

  final int statusCode;
  final Object? body;
}
