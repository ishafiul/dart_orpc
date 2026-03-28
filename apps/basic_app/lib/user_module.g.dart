// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_module.dart';

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

class _$UserModuleContainer {
  _$UserModuleContainer({
    required this.userService,
    required this.userController,
  });

  final UserService userService;

  final UserController userController;
}

_$UserModuleContainer _$createUserModuleContainer() {
  final userService = UserService();

  final userController = UserController(userService);

  return _$UserModuleContainer(
    userService: userService,
    userController: userController,
  );
}

// ignore: unused_element
RpcProcedureRegistry _$createUserModuleLocalProcedureRegistry() {
  final container = _$createUserModuleContainer();
  return _$createUserModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createUserModuleProcedureRegistryFromContainer(
  _$UserModuleContainer container,
) {
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
      handler: (context, input) =>
          container.userController.getById(context, input),
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
      handler: (context, input) => container.userController.status(),
    ),
  ]);
}

RpcProcedureRegistry _$createUserModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ..._$createUserModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateUserModuleProcedureRegistry() =>
    _$createUserModuleProcedureRegistry();

// ignore: unused_element
RestRouteRegistry _$createUserModuleLocalRestRouteRegistry() {
  final container = _$createUserModuleContainer();
  return _$createUserModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createUserModuleRestRouteRegistryFromContainer(
  _$UserModuleContainer container,
) {
  return RestRouteRegistry([
    RestRoute(
      method: 'GET',
      path: '/users/:id',
      handler: (context, request, pathParameters) async {
        final rawInput = <String, Object?>{};
        rawInput['id'] = decodeRestScalarParameter<String>(
          rawValue: pathParameters['id'],
          source: 'path parameter',
          name: 'id',
          route: 'GET /users/:id',
        );
        rawInput['include'] = decodeRestScalarParameter<String?>(
          rawValue: request.queryParameters['include'],
          source: 'query parameter',
          name: 'include',
          route: 'GET /users/:id',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<GetUserDto>(
          rawInput: rawInput,
          method: 'user.getById',
          validate: $GetUserDtoValidate,
        ))(rawInput);
        final output = await container.userController.getById(context, input);
        return ((output) => encodeRpcOutputWithLuthor<UserResponseDto>(
          output: output,
          method: 'user.getById',
          toJson: (output) => output.toJson(),
          validate: $UserResponseDtoValidate,
        ))(output);
      },
    ),
  ]);
}

RestRouteRegistry _$createUserModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ..._$createUserModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateUserModuleRestRouteRegistry() =>
    _$createUserModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry _$createUserModuleLocalProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    const ProcedureMetadata(
      rpcMethod: 'user.getById',
      controllerNamespace: 'user',
      methodName: 'getById',
      path: RestProcedureMetadata(method: 'GET', path: '/users/:id'),
      inputTypeCode: 'GetUserDto',
      outputTypeCode: 'UserResponseDto',
      description: 'Resolve a user by id from the shared RPC and REST method.',
      tags: ['user', 'example'],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'id',
          wireName: 'id',
          source: ProcedureParameterSourceKind.path,
          typeCode: 'String',
        ),
        ProcedureParameterMetadata(
          parameterName: 'include',
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

ProcedureMetadataRegistry _$createUserModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ..._$createUserModuleLocalProcedureMetadataRegistry().procedures,
  ]);
}

ProcedureMetadataRegistry dartOrpcCreateUserModuleProcedureMetadataRegistry() =>
    _$createUserModuleProcedureMetadataRegistry();

OpenApiSchemaRegistry _$createUserModuleLocalOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    OpenApiSchemaComponent(name: 'GetUserDto', validator: $GetUserDtoSchema),
    OpenApiSchemaComponent(
      name: 'UserResponseDto',
      validator: $UserResponseDtoSchema,
    ),
  ]);
}

OpenApiSchemaRegistry _$createUserModuleOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    ..._$createUserModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateUserModuleOpenApiSchemaRegistry() =>
    _$createUserModuleOpenApiSchemaRegistry();

JsonObject _$createUserModuleOpenApiDocument() {
  return createOpenApiDocument(
    title: 'User API',
    procedures: _$createUserModuleProcedureMetadataRegistry(),
    schemas: _$createUserModuleOpenApiSchemaRegistry(),
  );
}

// ignore: unused_element
RpcHttpApp _$buildUserModuleRpcApp() {
  return RpcHttpApp(
    procedures: _$createUserModuleProcedureRegistry(),
    restRoutes: _$createUserModuleRestRouteRegistry(),
    openApiDocument: _$createUserModuleOpenApiDocument(),
    docsHtml: createScalarHtml(title: 'User API'),
  );
}

class UserClientRoot {
  UserClientRoot({required RpcTransport transport})
    : _caller = RpcCaller(transport);

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
