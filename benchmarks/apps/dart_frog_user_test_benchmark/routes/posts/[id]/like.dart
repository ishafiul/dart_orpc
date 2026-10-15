import 'dart:io';

import 'package:challenge_core/challenge_core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_user_test_benchmark/challenge_responses.dart';

Response onRequest(RequestContext context, String id) =>
    handleChallengeRoute(() {
      final identity = challengeRuntime.authenticate(context.request.headers);
      final response = challengeRuntime.likePost(identity, id);
      return ChallengeRouteResult(
        statusCode: response.alreadyLiked ? HttpStatus.ok : HttpStatus.created,
        body: response.toJson(),
      );
    });
