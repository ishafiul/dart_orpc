import 'package:challenge_core/challenge_core.dart';
import 'package:dart_frog/dart_frog.dart';

final class ChallengeRouteResult {
  const ChallengeRouteResult({required this.body, this.statusCode = 200});

  final Object? body;
  final int statusCode;
}

Response handleChallengeRoute(ChallengeRouteResult Function() action) {
  try {
    return _successResponse(action());
  } on Object catch (error) {
    return _errorResponse(error);
  }
}

Future<Response> handleAsyncChallengeRoute(
  Future<ChallengeRouteResult> Function() action,
) async {
  try {
    return _successResponse(await action());
  } on Object catch (error) {
    return _errorResponse(error);
  }
}

Response _successResponse(ChallengeRouteResult result) =>
    Response.json(statusCode: result.statusCode, body: result.body);

Response _errorResponse(Object error) {
  if (error is ChallengeFailure) {
    return _jsonErrorResponse(error.statusCode, error.message);
  }
  if (error is FormatException) {
    return _jsonErrorResponse(400, 'malformed JSON body');
  }
  return _jsonErrorResponse(500, 'internal server error');
}

Response _jsonErrorResponse(int statusCode, String message) =>
    Response.json(statusCode: statusCode, body: {'error': message});
