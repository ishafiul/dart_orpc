import 'package:challenge_core/challenge_core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_user_test_benchmark/challenge_responses.dart';

Response onRequest(RequestContext context) => handleChallengeRoute(
  () => ChallengeRouteResult(body: challengeRuntime.health().toJson()),
);
