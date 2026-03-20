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
      decodeInput: GetUserDto.fromJson,
      encodeOutput: (output) => output.toJson(),
      handler: (context, input) => userController.getById(context, input),
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
      decode: UserResponseDto.fromJson,
    );
  }
}
