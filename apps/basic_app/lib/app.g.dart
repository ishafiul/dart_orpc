// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

RpcProcedureRegistry _$createAppModuleProcedureRegistry() {
  final userService = UserService();

  final userController = UserController(userService);

  return RpcProcedureRegistry([
    RpcProcedure<GetUserDto, UserResponseDto>(
      method: 'user.getById',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<GetUserDto>(
        rawInput: rawInput,
        method: 'user.getById',
        validate: $GetUserDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputWithLuthor<UserResponseDto>(
        output: output,
        method: 'user.getById',
        toJson: (output) => output.toJson(),
        validate: $UserResponseDtoValidate,
      ),
      handler: (context, input) => userController.getById(context, input),
    ),
    RpcProcedure<Null, UserStatusDto>(
      method: 'user.status',
      decodeInput: (rawInput) =>
          expectNoRpcInput(rawInput, context: 'RPC method "user.status"'),
      encodeOutput: (output) => encodeRpcOutputWithLuthor<UserStatusDto>(
        output: output,
        method: 'user.status',
        toJson: (output) => output.toJson(),
        validate: $UserStatusDtoValidate,
      ),
      handler: (context, input) => userController.status(),
    ),
  ]);
}

RpcHttpApp _$buildAppModuleRpcApp() {
  return RpcHttpApp(procedures: _$createAppModuleProcedureRegistry());
}

class AppClient {
  AppClient({required RpcTransport transport}) : _caller = RpcCaller(transport);

  final RpcCaller _caller;

  late final UserClient user = UserClient(_caller);
}

class UserClient {
  UserClient(this._caller);

  final RpcCaller _caller;

  Future<UserResponseDto> getById(GetUserDto input) {
    return _caller.call<UserResponseDto>(
      method: 'user.getById',
      input: input.toJson(),
      decode: (json) => UserResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "user.getById"'),
        ),
      ),
    );
  }

  Future<UserStatusDto> status() {
    return _caller.call<UserStatusDto>(
      method: 'user.status',
      decode: (json) => UserStatusDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "user.status"'),
        ),
      ),
    );
  }
}
