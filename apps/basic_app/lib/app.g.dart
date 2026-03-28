// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

class _$AppModuleContainer {
  _$AppModuleContainer();
}

_$AppModuleContainer _$createAppModuleContainer() {
  return _$AppModuleContainer();
}

// ignore: unused_element
RpcProcedureRegistry _$createAppModuleLocalProcedureRegistry() {
  final container = _$createAppModuleContainer();
  return _$createAppModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createAppModuleProcedureRegistryFromContainer(
  _$AppModuleContainer container,
) {
  return RpcProcedureRegistry([]);
}

RpcProcedureRegistry _$createAppModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ...dartOrpcCreateUserModuleProcedureRegistry().procedures,
    ..._$createAppModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateAppModuleProcedureRegistry() =>
    _$createAppModuleProcedureRegistry();

// ignore: unused_element
RestRouteRegistry _$createAppModuleLocalRestRouteRegistry() {
  final container = _$createAppModuleContainer();
  return _$createAppModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createAppModuleRestRouteRegistryFromContainer(
  _$AppModuleContainer container,
) {
  return RestRouteRegistry([]);
}

RestRouteRegistry _$createAppModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ...dartOrpcCreateUserModuleRestRouteRegistry().routes,
    ..._$createAppModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateAppModuleRestRouteRegistry() =>
    _$createAppModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry _$createAppModuleLocalProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([]);
}

ProcedureMetadataRegistry _$createAppModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ...dartOrpcCreateUserModuleProcedureMetadataRegistry().procedures,
    ..._$createAppModuleLocalProcedureMetadataRegistry().procedures,
  ]);
}

ProcedureMetadataRegistry dartOrpcCreateAppModuleProcedureMetadataRegistry() =>
    _$createAppModuleProcedureMetadataRegistry();

OpenApiSchemaRegistry _$createAppModuleLocalOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([]);
}

OpenApiSchemaRegistry _$createAppModuleOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    ...dartOrpcCreateUserModuleOpenApiSchemaRegistry().components,
    ..._$createAppModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateAppModuleOpenApiSchemaRegistry() =>
    _$createAppModuleOpenApiSchemaRegistry();

JsonObject _$createAppModuleOpenApiDocument() {
  return createOpenApiDocument(
    title: 'App API',
    procedures: _$createAppModuleProcedureMetadataRegistry(),
    schemas: _$createAppModuleOpenApiSchemaRegistry(),
  );
}

// ignore: unused_element
RpcHttpApp _$buildAppModuleRpcApp() {
  return RpcHttpApp(
    procedures: _$createAppModuleProcedureRegistry(),
    restRoutes: _$createAppModuleRestRouteRegistry(),
    openApiDocument: _$createAppModuleOpenApiDocument(),
    docsHtml: createScalarHtml(title: 'App API'),
  );
}

class AppClient {
  AppClient({required RpcTransport transport}) : _transport = transport;

  final RpcTransport _transport;

  late final UserClientRoot _userModuleClient = UserClientRoot(
    transport: _transport,
  );
  late final UserClient user = _userModuleClient.user;
}
