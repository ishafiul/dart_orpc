import 'package:dart_orpc/dart_orpc.dart';

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    final id = expectStringField(object, 'id', nonEmpty: true);
    return GetUserDto(id: id);
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    final id = expectStringField(object, 'id', nonEmpty: true);
    final name = expectStringField(object, 'name', nonEmpty: true);
    return UserResponseDto(id: id, name: name);
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
