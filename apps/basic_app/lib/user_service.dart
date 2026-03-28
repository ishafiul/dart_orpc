import 'package:dart_orpc/dart_orpc.dart';

import 'user_dtos.dart';

final class UserService {
  static const Map<String, UserResponseDto> _users = {
    '1': UserResponseDto(id: '1', name: 'Ada Lovelace'),
    '2': UserResponseDto(id: '2', name: 'Grace Hopper'),
  };

  Future<UserResponseDto> getById(String id, {String? include}) async {
    final user = _users[id];
    if (user == null) {
      throw RpcException.notFound('User "$id" was not found.');
    }

    if (include == 'compact') {
      return user.copyWith(name: user.name.split(' ').first);
    }

    return user;
  }

  Future<UserStatusDto> status() async {
    return const UserStatusDto(status: 'ready');
  }
}
