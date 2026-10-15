import 'package:dart_orpc/dart_orpc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_dtos.freezed.dart';
part 'auth_dtos.g.dart';

@luthor
@freezed
abstract class SignUpDto with _$SignUpDto {
  const factory SignUpDto({
    @HasMin(3) required String name,
    @IsEmail(message: 'Enter a valid email address.')
    @HasMax(254)
    required String email,
    @HasMin(8)
    @HasMax(72)
    @MatchRegex(
      r'^(?=.*[A-Za-z])(?=.*\d).+$',
      message: 'Password must contain at least one letter and one number.',
    )
    required String password,
  }) = _SignUpDto;

  factory SignUpDto.fromJson(Map<String, dynamic> json) =>
      _$SignUpDtoFromJson(json);
}

@luthor
@freezed
abstract class LoginDto with _$LoginDto {
  const factory LoginDto({
    @IsEmail(message: 'Enter a valid email address.')
    @HasMax(254)
    required String email,
    @HasMin(8)
    @HasMax(72)
    @MatchRegex(
      r'^(?=.*[A-Za-z])(?=.*\d).+$',
      message: 'Password must contain at least one letter and one number.',
    )
    required String password,
  }) = _LoginDto;

  factory LoginDto.fromJson(Map<String, dynamic> json) =>
      _$LoginDtoFromJson(json);
}

@luthor
@freezed
abstract class AuthUserDto with _$AuthUserDto {
  const factory AuthUserDto({
    required String id,
    required String name,
    required String email,
  }) = _AuthUserDto;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) =>
      _$AuthUserDtoFromJson(json);
}

@luthor
@freezed
abstract class AuthResponseDto with _$AuthResponseDto {
  const factory AuthResponseDto({
    required String accessToken,
    @Default('Bearer') String tokenType,
    required int expiresIn,
    required AuthUserDto user,
  }) = _AuthResponseDto;

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseDtoFromJson(json);
}
