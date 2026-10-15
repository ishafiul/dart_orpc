import 'package:dart_orpc/dart_orpc.dart';

import '../../environment/app_env.dart';
import 'auth_dtos.dart';
import 'auth_service.dart';

@Controller('auth')
final class AuthController {
  AuthController(this.authService);

  final AuthService authService;

  @RpcMethod(
    name: 'signUp',
    path: RestMapping.post('/auth/signup'),
    description: 'Create an account and return a JWT access token.',
    tags: ['auth'],
  )
  Future<AuthResponseDto> signUp(
    RpcContext context,
    @RpcInput() SignUpDto input,
  ) {
    return authService.signUp(input, env: context.env);
  }

  @RpcMethod(
    name: 'login',
    path: RestMapping.post('/auth/login'),
    description: 'Authenticate with email and password.',
    tags: ['auth'],
  )
  Future<AuthResponseDto> login(
    RpcContext context,
    @RpcInput() LoginDto input,
  ) {
    return authService.login(input, env: context.env);
  }

  @RpcMethod(
    name: 'test',
    path: RestMapping.post('/auth/test'),
    description: 'Authenticate with email and password.',
    tags: ['auth'],
  )
  Future<int> test(RpcContext context,) async {
    print('test');
    return 42;
  }
}
