import 'package:basic_app/environment/app_env.dart';
import 'package:basic_app/modules/auth/auth_dtos.dart';
import 'package:basic_app/modules/auth/auth_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

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
}
