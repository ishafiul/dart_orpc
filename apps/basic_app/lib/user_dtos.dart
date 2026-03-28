import 'package:dart_orpc/dart_orpc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_dtos.freezed.dart';
part 'user_dtos.g.dart';

@luthor
@freezed
abstract class GetUserDto with _$GetUserDto {
  const factory GetUserDto({@HasMin(1) required String id}) = _GetUserDto;

  factory GetUserDto.fromJson(Map<String, dynamic> json) =>
      _$GetUserDtoFromJson(json);
}

@luthor
@freezed
abstract class UserResponseDto with _$UserResponseDto {
  const factory UserResponseDto({
    @HasMin(1) required String id,
    @HasMin(1) required String name,
  }) = _UserResponseDto;

  factory UserResponseDto.fromJson(Map<String, dynamic> json) =>
      _$UserResponseDtoFromJson(json);
}

@luthor
@freezed
abstract class UserStatusDto with _$UserStatusDto {
  const factory UserStatusDto({@HasMin(1) required String status}) =
      _UserStatusDto;

  factory UserStatusDto.fromJson(Map<String, dynamic> json) =>
      _$UserStatusDtoFromJson(json);
}
