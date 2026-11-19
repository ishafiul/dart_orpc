// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

// ignore_for_file: unnecessary_import

export 'package:basic_app/modules/auth/auth_dtos.dart';
export 'package:basic_app/modules/auth/auth_module.dart';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/modules/auth/auth_controller.dart';
import 'package:basic_app/modules/auth/auth_dtos.dart';
import 'package:basic_app/modules/auth/auth_module.dart';
import 'package:basic_app/modules/auth/auth_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$AuthModuleContainer {
  _$AuthModuleContainer({
    required this.authService,
    required this.authController,
  });

  final AuthService authService;

  final AuthController authController;

  Future<void> dispose() => disposeRpcProviders([authController, authService]);
}

_$AuthModuleContainer _$createAuthModuleContainer({
  required AppDatabase appDatabase,
}) {
  final authService = AuthService(appDatabase);

  final authController = AuthController(authService);

  return _$AuthModuleContainer(
    authService: authService,
    authController: authController,
  );
}

RpcProcedureRegistry _$createAuthModuleProcedureRegistryFromContainer(
  _$AuthModuleContainer container,
) {
  final metadataRegistry = _$authModuleProcedureMetadata;
  return RpcProcedureRegistry([
    RpcUnaryProcedure<SignUpDto, AuthResponseDto>(
      method: 'auth.signUp',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<SignUpDto>(
        rawInput: rawInput,
        method: 'auth.signUp',
        validate: $SignUpDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<AuthResponseDto>(
        output: output,
        method: 'auth.signUp',
        toJson: (output) => output.toJson(),
        validateJson: $AuthResponseDtoSchema.validate,
      ),
      metadata: metadataRegistry['auth.signUp']!,

      handler: (context, input) =>
          container.authController.signUp(context, input),
    ),
    RpcUnaryProcedure<LoginDto, AuthResponseDto>(
      method: 'auth.login',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<LoginDto>(
        rawInput: rawInput,
        method: 'auth.login',
        validate: $LoginDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<AuthResponseDto>(
        output: output,
        method: 'auth.login',
        toJson: (output) => output.toJson(),
        validateJson: $AuthResponseDtoSchema.validate,
      ),
      metadata: metadataRegistry['auth.login']!,

      handler: (context, input) =>
          container.authController.login(context, input),
    ),
  ]);
}

RpcProcedureRegistry _$createAuthModuleProcedureRegistry({
  required AppDatabase appDatabase,
}) => _$createAuthModuleProcedureRegistryFromContainer(
  _$createAuthModuleContainer(appDatabase: appDatabase),
);

RpcProcedureRegistry dartOrpcCreateAuthModuleProcedureRegistry({
  required AppDatabase appDatabase,
}) => _$createAuthModuleProcedureRegistry(appDatabase: appDatabase);

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createAuthModuleRuntime({required AppDatabase appDatabase}) {
  final container = _$createAuthModuleContainer(appDatabase: appDatabase);
  return (
    procedures: _$createAuthModuleProcedureRegistryFromContainer(container),
    restRoutes: _$createAuthModuleRestRouteRegistryFromContainer(container),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateAuthModuleRuntime({required AppDatabase appDatabase}) =>
    _$createAuthModuleRuntime(appDatabase: appDatabase);

RestRouteRegistry _$createAuthModuleRestRouteRegistryFromContainer(
  _$AuthModuleContainer container,
) {
  final metadataRegistry = _$authModuleProcedureMetadata;
  return RestRouteRegistry([
    RestUnaryRoute(
      method: 'POST',
      path: '/auth/signup',
      handler: (context, request, pathParameters) async {
        final rawInput = decodeRestRpcInputBody(
          request,
          route: 'POST /auth/signup',
          parameterName: 'input',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<SignUpDto>(
          rawInput: rawInput,
          method: 'auth.signUp',
          validate: $SignUpDtoValidate,
        ))(rawInput);
        final output = await container.authController.signUp(context, input);
        return encodeRpcOutputJsonWithLuthor<AuthResponseDto>(
          output: output,
          method: 'auth.signUp',
          toJson: (output) => output.toJson(),
          validateJson: $AuthResponseDtoSchema.validate,
        );
      },
      metadata: metadataRegistry['auth.signUp']!,
    ),
    RestUnaryRoute(
      method: 'POST',
      path: '/auth/login',
      handler: (context, request, pathParameters) async {
        final rawInput = decodeRestRpcInputBody(
          request,
          route: 'POST /auth/login',
          parameterName: 'input',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<LoginDto>(
          rawInput: rawInput,
          method: 'auth.login',
          validate: $LoginDtoValidate,
        ))(rawInput);
        final output = await container.authController.login(context, input);
        return encodeRpcOutputJsonWithLuthor<AuthResponseDto>(
          output: output,
          method: 'auth.login',
          toJson: (output) => output.toJson(),
          validateJson: $AuthResponseDtoSchema.validate,
        );
      },
      metadata: metadataRegistry['auth.login']!,
    ),
  ]);
}

RestRouteRegistry _$createAuthModuleRestRouteRegistry({
  required AppDatabase appDatabase,
}) => _$createAuthModuleRestRouteRegistryFromContainer(
  _$createAuthModuleContainer(appDatabase: appDatabase),
);

RestRouteRegistry dartOrpcCreateAuthModuleRestRouteRegistry({
  required AppDatabase appDatabase,
}) => _$createAuthModuleRestRouteRegistry(appDatabase: appDatabase);

final ProcedureMetadataRegistry _$authModuleProcedureMetadata =
    ProcedureMetadataRegistry([
      const ProcedureMetadata(
        rpcMethod: 'auth.signUp',
        controllerNamespace: 'auth',
        methodName: 'signUp',
        path: RestProcedureMetadata(method: 'POST', path: '/auth/signup'),
        inputTypeCode: 'SignUpDto',
        outputTypeCode: 'AuthResponseDto',
        description: 'Create an account and return a JWT access token.',
        tags: ['auth'],
        parameters: [
          ProcedureParameterMetadata(
            parameterName: 'input',
            wireName: 'input',
            source: ProcedureParameterSourceKind.body,
            typeCode: 'SignUpDto',
          ),
        ],
      ),
      const ProcedureMetadata(
        rpcMethod: 'auth.login',
        controllerNamespace: 'auth',
        methodName: 'login',
        path: RestProcedureMetadata(method: 'POST', path: '/auth/login'),
        inputTypeCode: 'LoginDto',
        outputTypeCode: 'AuthResponseDto',
        description: 'Authenticate with email and password.',
        tags: ['auth'],
        parameters: [
          ProcedureParameterMetadata(
            parameterName: 'input',
            wireName: 'input',
            source: ProcedureParameterSourceKind.body,
            typeCode: 'LoginDto',
          ),
        ],
      ),
    ]);

ProcedureMetadataRegistry _$createAuthModuleProcedureMetadataRegistry() =>
    _$authModuleProcedureMetadata;

ProcedureMetadataRegistry dartOrpcCreateAuthModuleProcedureMetadataRegistry() =>
    _$createAuthModuleProcedureMetadataRegistry();

JsonObject _$createAuthModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'Auth API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createAuthModuleProcedureMetadataRegistry(),
    schemas: _$createAuthModuleDtoSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateAuthModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createAuthModuleOpenApiDocument(options: options);

RpcHttpApp _$buildAuthModuleRpcApp({
  required AppDatabase appDatabase,
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  RpcHttpStaticOptions? staticAssets,
  RpcHttpHealthOptions? health,
  RpcHttpMetricsOptions? metrics,
  RpcWebSocketServerOptions? webSocket,
  RpcContextBindings bindings = const RpcContextBindings.empty(),
  RpcContextFactory? contextFactory,
  Duration sseHeartbeatInterval = const Duration(seconds: 15),
  bool sseFlushEachChunk = true,
  bool encodeJsonToBytes = true,
  int? maxConcurrentRequests,
  Duration? requestBodyIdleTimeout,
  RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
  Iterable<RpcHttpMiddleware> middleware = const [],
  RpcObserver? observer,
}) {
  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();
  final effectiveDocs = docs ?? const RpcHttpDocsOptions();
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'Auth API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final container = _$createAuthModuleContainer(appDatabase: appDatabase);
  final procedures = _$createAuthModuleProcedureRegistryFromContainer(
    container,
  );
  final restRoutes = _$createAuthModuleRestRouteRegistryFromContainer(
    container,
  );
  return RpcHttpApp(
    procedures: procedures,
    restRoutes: restRoutes,
    onClose: container.dispose,
    openApiDocument: _$createAuthModuleOpenApiDocument(
      options: effectiveOpenApi,
    ),
    openApiPath: effectiveOpenApiPath,
    docsHtml:
        effectiveDocs.html ??
        createScalarHtml(
          title: effectiveDocs.title ?? effectiveOpenApiTitle,
          openApiPath: effectiveOpenApiPath,
        ),
    docsPath: effectiveDocs.docsPath,
    docsBasicAuth: effectiveDocs.basicAuth,
    staticAssets: staticAssets,
    health: health,
    metrics: metrics,
    bindings: bindings,
    contextFactory: contextFactory,
    sseHeartbeatInterval: sseHeartbeatInterval,
    sseFlushEachChunk: sseFlushEachChunk,
    encodeJsonToBytes: encodeJsonToBytes,
    maxConcurrentRequests: maxConcurrentRequests,
    requestBodyIdleTimeout: requestBodyIdleTimeout,
    serverOptions: serverOptions,
    middleware: middleware,
    observer: observer,
    upgradeHandlers: [
      if (webSocket != null)
        RpcWebSocketUpgradeHandler(
          procedures: procedures,
          options: webSocket,
          observer: observer,
        ),
    ],
  );
}

RpcHttpApp dartOrpcBuildAuthModuleRpcApp({
  required AppDatabase appDatabase,
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  RpcHttpStaticOptions? staticAssets,
  RpcHttpHealthOptions? health,
  RpcHttpMetricsOptions? metrics,
  RpcWebSocketServerOptions? webSocket,
  RpcContextBindings bindings = const RpcContextBindings.empty(),
  RpcContextFactory? contextFactory,
  Duration sseHeartbeatInterval = const Duration(seconds: 15),
  bool sseFlushEachChunk = true,
  bool encodeJsonToBytes = true,
  int? maxConcurrentRequests,
  Duration? requestBodyIdleTimeout,
  RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
  Iterable<RpcHttpMiddleware> middleware = const [],
  RpcObserver? observer,
}) => _$buildAuthModuleRpcApp(
  appDatabase: appDatabase,
  openApi: openApi,
  docs: docs,
  staticAssets: staticAssets,
  health: health,
  metrics: metrics,
  webSocket: webSocket,
  bindings: bindings,
  contextFactory: contextFactory,
  sseHeartbeatInterval: sseHeartbeatInterval,
  sseFlushEachChunk: sseFlushEachChunk,
  encodeJsonToBytes: encodeJsonToBytes,
  maxConcurrentRequests: maxConcurrentRequests,
  requestBodyIdleTimeout: requestBodyIdleTimeout,
  serverOptions: serverOptions,
  middleware: middleware,
  observer: observer,
);

DtoSchemaRegistry _$createAuthModuleLocalDtoSchemaRegistry() {
  return DtoSchemaRegistry(const [
    DtoSchemaMetadata(
      name: 'AuthResponseDto',
      fields: [
        DtoFieldMetadata(wireName: 'accessToken', type: DtoStringType()),
        DtoFieldMetadata(wireName: 'expiresIn', type: DtoIntegerType()),
        DtoFieldMetadata(wireName: 'user', type: DtoObjectType('AuthUserDto')),
        DtoFieldMetadata(
          wireName: 'tokenType',
          type: DtoStringType(),
          required: false,
        ),
      ],
    ),
    DtoSchemaMetadata(
      name: 'AuthUserDto',
      fields: [
        DtoFieldMetadata(wireName: 'id', type: DtoStringType()),
        DtoFieldMetadata(wireName: 'name', type: DtoStringType()),
        DtoFieldMetadata(wireName: 'email', type: DtoStringType()),
      ],
    ),
    DtoSchemaMetadata(
      name: 'LoginDto',
      fields: [
        DtoFieldMetadata(
          wireName: 'email',
          type: DtoStringType(),
          constraints: DtoFieldConstraints(
            max: 254,
            format: DtoStringFormat.email,
          ),
        ),
        DtoFieldMetadata(
          wireName: 'password',
          type: DtoStringType(),
          constraints: DtoFieldConstraints(
            min: 8,
            max: 72,
            pattern: '^(?=.*[A-Za-z])(?=.*\\d).+\$',
          ),
        ),
      ],
      unknownKeys: DtoUnknownKeys.strict,
    ),
    DtoSchemaMetadata(
      name: 'SignUpDto',
      fields: [
        DtoFieldMetadata(
          wireName: 'name',
          type: DtoStringType(),
          constraints: DtoFieldConstraints(min: 3),
        ),
        DtoFieldMetadata(
          wireName: 'email',
          type: DtoStringType(),
          constraints: DtoFieldConstraints(
            max: 254,
            format: DtoStringFormat.email,
          ),
        ),
        DtoFieldMetadata(
          wireName: 'password',
          type: DtoStringType(),
          constraints: DtoFieldConstraints(
            min: 8,
            max: 72,
            pattern: '^(?=.*[A-Za-z])(?=.*\\d).+\$',
          ),
        ),
      ],
      unknownKeys: DtoUnknownKeys.strict,
    ),
  ]);
}

DtoSchemaRegistry dartOrpcCreateAuthModuleLocalDtoSchemaRegistry() =>
    _$createAuthModuleLocalDtoSchemaRegistry();

DtoSchemaRegistry _$createAuthModuleDtoSchemaRegistry() {
  return DtoSchemaRegistry([
    ..._$createAuthModuleLocalDtoSchemaRegistry().schemas,
  ]);
}

DtoSchemaRegistry dartOrpcCreateAuthModuleDtoSchemaRegistry() =>
    _$createAuthModuleDtoSchemaRegistry();

class AuthClientRoot {
  AuthClientRoot({required RpcClientTransports transports})
    : _transports = transports;

  final RpcClientTransports _transports;

  late final auth = AuthClient(_transports);
}

class AuthClient {
  AuthClient(this._transports);

  final RpcClientTransports _transports;

  Future<AuthResponseDto> signUp(SignUpDto input) {
    return RpcCaller(_transports.requireUnary('auth.signUp'))
        .call<AuthResponseDto>(
          method: 'auth.signUp',
          input: input.toJson(),
          options: null,
          decode: (json) => AuthResponseDto.fromJson(
            Map<String, dynamic>.from(
              expectJsonObject(json, context: 'RPC response for "auth.signUp"'),
            ),
          ),
        );
  }

  Future<AuthResponseDto> login(LoginDto input) {
    return RpcCaller(_transports.requireUnary('auth.login'))
        .call<AuthResponseDto>(
          method: 'auth.login',
          input: input.toJson(),
          options: null,
          decode: (json) => AuthResponseDto.fromJson(
            Map<String, dynamic>.from(
              expectJsonObject(json, context: 'RPC response for "auth.login"'),
            ),
          ),
        );
  }
}

extension DartOrpcAuthModuleGenerated on AuthModule {
  RpcProcedureRegistry procedureRegistry({required AppDatabase appDatabase}) =>
      dartOrpcCreateAuthModuleProcedureRegistry(appDatabase: appDatabase);
  RestRouteRegistry restRouteRegistry({required AppDatabase appDatabase}) =>
      dartOrpcCreateAuthModuleRestRouteRegistry(appDatabase: appDatabase);
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateAuthModuleProcedureMetadataRegistry();
  DtoSchemaRegistry dtoSchemaRegistry() =>
      dartOrpcCreateAuthModuleDtoSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateAuthModuleOpenApiDocument(options: options);
  RpcHttpApp buildRpcApp({
    required AppDatabase appDatabase,
    OpenApiDocumentOptions? openApi,
    RpcHttpDocsOptions? docs,
    RpcHttpStaticOptions? staticAssets,
    RpcHttpHealthOptions? health,
    RpcHttpMetricsOptions? metrics,
    RpcWebSocketServerOptions? webSocket,
    RpcContextBindings bindings = const RpcContextBindings.empty(),
    RpcContextFactory? contextFactory,
    Duration sseHeartbeatInterval = const Duration(seconds: 15),
    bool sseFlushEachChunk = true,
    bool encodeJsonToBytes = true,
    int? maxConcurrentRequests,
    Duration? requestBodyIdleTimeout,
    RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
    Iterable<RpcHttpMiddleware> middleware = const [],
    RpcObserver? observer,
  }) => dartOrpcBuildAuthModuleRpcApp(
    appDatabase: appDatabase,
    openApi: openApi,
    docs: docs,
    staticAssets: staticAssets,
    health: health,
    metrics: metrics,
    webSocket: webSocket,
    bindings: bindings,
    contextFactory: contextFactory,
    sseHeartbeatInterval: sseHeartbeatInterval,
    sseFlushEachChunk: sseFlushEachChunk,
    encodeJsonToBytes: encodeJsonToBytes,
    maxConcurrentRequests: maxConcurrentRequests,
    requestBodyIdleTimeout: requestBodyIdleTimeout,
    serverOptions: serverOptions,
    middleware: middleware,
    observer: observer,
  );
  AuthClientRoot createClient({required RpcClientTransports transports}) =>
      AuthClientRoot(transports: transports);
}
