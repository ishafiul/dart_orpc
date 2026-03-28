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

RestRouteRegistry _$createAppModuleRestRouteRegistry() {
  final userService = UserService();

  final userController = UserController(userService);

  return RestRouteRegistry([
    RestRoute(
      method: 'GET',
      path: '/users/:id',
      handler: (context, request, pathParameters) async {
        final id = decodeRestScalarParameter<String>(
          rawValue: pathParameters['id'],
          source: 'path parameter',
          name: 'id',
          route: 'GET /users/:id',
        );
        final view = decodeRestScalarParameter<String?>(
          rawValue: request.queryParameters['include'],
          source: 'query parameter',
          name: 'include',
          route: 'GET /users/:id',
        );
        final output = await userController.getByIdRest(id, view);
        return ((output) => encodeRpcOutputWithLuthor<UserResponseDto>(
          output: output,
          method: 'user.getByIdRest',
          toJson: (output) => output.toJson(),
          validate: $UserResponseDtoValidate,
        ))(output);
      },
    ),
  ]);
}

// ignore: unused_element
ProcedureMetadataRegistry _$createAppModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    const ProcedureMetadata(
      rpcMethod: 'user.getById',
      controllerNamespace: 'user',
      methodName: 'getById',
      inputTypeCode: 'GetUserDto',
      outputTypeCode: 'UserResponseDto',
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'input',
          wireName: 'input',
          source: ProcedureParameterSourceKind.rpcInput,
          typeCode: 'GetUserDto',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'user.getByIdRest',
      controllerNamespace: 'user',
      methodName: 'getByIdRest',
      path: RestProcedureMetadata(method: 'GET', path: '/users/:id'),
      outputTypeCode: 'UserResponseDto',
      description: 'Resolve a user by id from the REST-style example route.',
      tags: ['user', 'example'],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'id',
          wireName: 'id',
          source: ProcedureParameterSourceKind.path,
          typeCode: 'String',
        ),
        ProcedureParameterMetadata(
          parameterName: 'view',
          wireName: 'include',
          source: ProcedureParameterSourceKind.query,
          typeCode: 'String?',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'user.status',
      controllerNamespace: 'user',
      methodName: 'status',
      outputTypeCode: 'UserStatusDto',
    ),
  ]);
}

RpcHttpApp _$buildAppModuleRpcApp() {
  return RpcHttpApp(
    procedures: _$createAppModuleProcedureRegistry(),
    restRoutes: _$createAppModuleRestRouteRegistry(),
  );
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
