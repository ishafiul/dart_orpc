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
}
