import 'package:dart_orpc/dart_orpc.dart';

import 'user_dtos.dart';
import 'user_service.dart';

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'getById')
  Future<UserResponseDto> getById(RpcContext _, @RpcInput() GetUserDto input) {
    return userService.getById(input.id);
  }

  @RpcMethod(
    name: 'getByIdRest',
    path: RestMapping.get('/users/:id'),
    description: 'Resolve a user by id from the REST-style example route.',
    tags: ['user', 'example'],
  )
  Future<UserResponseDto> getByIdRest(
    @PathParam() String id,
    @QueryParam('include') String? view,
  ) {
    return userService.getByIdForRest(id: id, include: view);
  }

  @RpcMethod()
  Future<UserStatusDto> status() {
    return userService.status();
  }
}
