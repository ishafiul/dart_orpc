part of '../../rpc_module_generator.dart';

/// One option of the generated `buildRpcApp` functions.
///
/// The private builder, the public `dartOrpcBuild…RpcApp` function and the
/// module extension all declare these, in this order, so a new option is
/// added here once.
final class _BuildAppParameter {
  const _BuildAppParameter(
    this.name,
    this.type, {
    this.defaultValue,
    this.passedToApp = true,
  });

  final String name;
  final String type;
  final String? defaultValue;

  /// Whether the builder forwards it to `RpcHttpApp` under the same name.
  /// The others (OpenAPI, docs, WebSocket) are turned into app arguments.
  final bool passedToApp;

  String get declaration =>
      defaultValue == null ? '$type $name' : '$type $name = $defaultValue';
}

const _buildAppParameters = <_BuildAppParameter>[
  _BuildAppParameter('openApi', 'OpenApiDocumentOptions?', passedToApp: false),
  _BuildAppParameter('docs', 'RpcHttpDocsOptions?', passedToApp: false),
  _BuildAppParameter('staticAssets', 'RpcHttpStaticOptions?'),
  _BuildAppParameter('health', 'RpcHttpHealthOptions?'),
  _BuildAppParameter('metrics', 'RpcHttpMetricsOptions?'),
  _BuildAppParameter(
    'webSocket',
    'RpcWebSocketServerOptions?',
    passedToApp: false,
  ),
  _BuildAppParameter(
    'bindings',
    'RpcContextBindings',
    defaultValue: 'const RpcContextBindings.empty()',
  ),
  _BuildAppParameter('contextFactory', 'RpcContextFactory?'),
  _BuildAppParameter(
    'sseHeartbeatInterval',
    'Duration',
    defaultValue: 'const Duration(seconds: 15)',
  ),
  _BuildAppParameter('sseFlushEachChunk', 'bool', defaultValue: 'true'),
  _BuildAppParameter('encodeJsonToBytes', 'bool', defaultValue: 'true'),
  _BuildAppParameter('maxConcurrentRequests', 'int?'),
  _BuildAppParameter('requestBodyIdleTimeout', 'Duration?'),
  _BuildAppParameter(
    'serverOptions',
    'RpcHttpServerOptions',
    defaultValue: 'const RpcHttpServerOptions()',
  ),
  _BuildAppParameter(
    'middleware',
    'Iterable<RpcHttpMiddleware>',
    defaultValue: 'const []',
  ),
  _BuildAppParameter('observer', 'RpcObserver?'),
];

/// `{…}` for a `buildRpcApp` declaration: the module's external
/// dependencies, then every option.
String _buildAppParameterBlock(_ModuleGenerationPlan context) {
  final dependencies = _dependencyParameterFields(context);
  return '{${[if (dependencies.isNotEmpty) dependencies, for (final parameter in _buildAppParameters) parameter.declaration].join(', ')}}';
}

/// The arguments that forward every dependency and option unchanged.
String _buildAppForwardedArguments(_ModuleGenerationPlan context) {
  final dependencies = _dependencyArgumentList(context);
  return [
    if (dependencies.isNotEmpty) dependencies,
    for (final parameter in _buildAppParameters)
      '${parameter.name}: ${parameter.name}',
  ].join(', ');
}
