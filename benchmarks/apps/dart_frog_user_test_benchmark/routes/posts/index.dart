import 'dart:convert';

import 'package:challenge_core/challenge_core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_user_test_benchmark/challenge_responses.dart';

Future<Response> onRequest(RequestContext context) =>
    handleAsyncChallengeRoute(() async {
      final identity = challengeRuntime.authenticate(context.request.headers);
      final requestBody = jsonDecode(await context.request.body());
      final response = challengeRuntime.createPost(identity, requestBody);
      return ChallengeRouteResult(statusCode: 201, body: response.toJson());
    });
