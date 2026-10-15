import 'package:dart_orpc/dart_orpc.dart';

import 'challenge_auth.dart';
import 'challenge_database.dart';
import 'challenge_dtos.dart';
import 'challenge_service.dart';

@Module(
  controllers: [HealthController, PostReadController, PostWriteController],
  providers: [ChallengeDatabase, ChallengeService, ChallengeBearerGuard],
)
final class ChallengeModule {
  const ChallengeModule();
}

@Controller('health')
final class HealthController {
  const HealthController(this.service);

  final ChallengeService service;

  @RpcMethod(path: RestMapping.get('/health'))
  HealthResponseDto health() => service.health();
}

@Controller('posts')
final class PostReadController {
  const PostReadController(this.service);

  final ChallengeService service;

  @RpcMethod(path: RestMapping.get('/feed'))
  FeedResponseDto feed() => service.feed();

  @RpcMethod(path: RestMapping.get('/posts/:id'))
  PostResponseDto getById(@PathParam() String id) => service.getPost(id);
}

@BearerAuth(guard: ChallengeBearerGuard)
@UseGuards([ChallengeBearerGuard])
@Controller('posts')
final class PostWriteController {
  const PostWriteController(this.service);

  final ChallengeService service;

  @RpcMethod(path: RestMapping.post('/posts'))
  CreatePostResponseDto create(RpcContext context, @Body() JsonObject body) {
    return service.createPost(identityFromContext(context), body);
  }

  @RpcMethod(path: RestMapping.post('/posts/:id/like'))
  LikeResponseDto like(RpcContext context, @PathParam() String id) {
    return service.likePost(identityFromContext(context), id);
  }
}
