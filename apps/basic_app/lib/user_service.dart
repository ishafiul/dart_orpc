import 'package:dart_orpc/dart_orpc.dart';

import 'user_dtos.dart';

final class UserService {
  static const Map<String, UserResponseDto> _users = {
    '1': UserResponseDto(id: '1', name: 'Ada Lovelace'),
    '2': UserResponseDto(id: '2', name: 'Grace Hopper'),
  };

  Future<UserResponseDto> getById(String id) async {
    final user = _users[id];
    if (user == null) {
      throw RpcException.notFound('User "$id" was not found.');
    }

    return user;
  }
}
