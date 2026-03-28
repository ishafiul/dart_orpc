import 'package:dart_orpc/dart_orpc.dart';

import 'user_dtos.dart';
import 'user_service.dart';

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(
    name: 'getById',
    path: RestMapping.get('/users/:id'),
    description: 'Resolve a user by id from the shared RPC and REST method.',
    tags: ['user', 'example'],
  )
  Future<UserResponseDto> getById(RpcContext _, @RpcInput() GetUserDto input) {
    return userService.getById(input.id, include: input.include);
  }

  @RpcMethod()
  Future<UserStatusDto> status() {
    return userService.status();
  }
}
