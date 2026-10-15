import 'json_utils.dart';

enum ProcedureParameterSourceKind { rpcInput, path, query, header, body }

enum RpcProcedureKind { unary, serverStream }

enum RestResponseKind { json, sse }

/// Named security requirement declared by an RPC procedure.
final class ProcedureSecurityRequirement {
  const ProcedureSecurityRequirement(this.schemeName);

  final String schemeName;
}

final class ProcedureParameterMetadata {
  const ProcedureParameterMetadata({
    required this.parameterName,
    required this.wireName,
    required this.source,
    required this.typeCode,
  });

  final String parameterName;
  final String wireName;
  final ProcedureParameterSourceKind source;
  final String typeCode;
}

final class RestProcedureMetadata {
  const RestProcedureMetadata({
    required this.method,
    required this.path,
    this.responseKind = RestResponseKind.json,
    this.statusCode,
    this.headers = const {},
  });

  final String method;
  final String path;
  final RestResponseKind responseKind;
  final int? statusCode;
  final Map<String, String> headers;
}

final class ProcedureCustomMetadata {
  const ProcedureCustomMetadata({required this.key, required this.value});

  final String key;
  final JsonObject value;
}

final class ProcedureMetadata {
  const ProcedureMetadata({
    required this.rpcMethod,
    required this.controllerNamespace,
    required this.methodName,
    required this.outputTypeCode,
    this.kind = RpcProcedureKind.unary,
    this.path,
    this.inputTypeCode,
    this.description,
    this.tags = const [],
    this.guardTypes = const [],
    this.securityRequirements = const [],
    List<ProcedureCustomMetadata> customMetadata = const [],
    List<ProcedureParameterMetadata> parameters = const [],
  }) : _customMetadata = customMetadata,
       _parameters = parameters;

  final String rpcMethod;
  final String controllerNamespace;
  final String methodName;
  final RpcProcedureKind kind;
  final RestProcedureMetadata? path;
  final String? inputTypeCode;
  final String outputTypeCode;
  final String? description;
  final List<String> tags;
  final List<String> guardTypes;
  final List<ProcedureSecurityRequirement> securityRequirements;
  final List<ProcedureCustomMetadata> _customMetadata;
  final List<ProcedureParameterMetadata> _parameters;

  // Weak keys retain const construction without a permanent global cache.
  static final _prepared = Expando<_PreparedProcedureMetadata>();
  _PreparedProcedureMetadata get _index => _prepared[this] ??=
      _PreparedProcedureMetadata(_parameters, _customMetadata);

  /// Collections become immutable snapshots on preparation or first use.
  List<ProcedureCustomMetadata> get customMetadata => _index.customMetadata;
  List<ProcedureParameterMetadata> get parameters => _index.parameters;

  void prepare() {
    _index;
  }

  Iterable<ProcedureCustomMetadata> metadataEntries(String key) =>
      _index.byKey[key] ?? const [];

  Iterable<JsonObject> metadataValues(String key) =>
      metadataEntries(key).map((metadata) => metadata.value);

  JsonObject? firstMetadataValue(String key) => _index.byKey[key]?.first.value;
}

final class ProcedureMetadataRegistry {
  ProcedureMetadataRegistry(Iterable<ProcedureMetadata> procedures)
    : _procedures = _indexProcedures(procedures);

  final Map<String, ProcedureMetadata> _procedures;

  Iterable<String> get methods => _procedures.keys;
  Iterable<ProcedureMetadata> get procedures => _procedures.values;

  ProcedureMetadata? operator [](String rpcMethod) => _procedures[rpcMethod];

  static Map<String, ProcedureMetadata> _indexProcedures(
    Iterable<ProcedureMetadata> procedures,
  ) {
    final indexed = <String, ProcedureMetadata>{};

    for (final procedure in procedures) {
      if (indexed.containsKey(procedure.rpcMethod)) {
        throw StateError(
          'Duplicate procedure metadata "${procedure.rpcMethod}".',
        );
      }

      procedure.prepare();
      indexed[procedure.rpcMethod] = procedure;
    }

    return Map.unmodifiable(indexed);
  }
}

final class _PreparedProcedureMetadata {
  _PreparedProcedureMetadata(
    List<ProcedureParameterMetadata> parameters,
    List<ProcedureCustomMetadata> customMetadata,
  ) : parameters = List.unmodifiable(parameters),
      customMetadata = List.unmodifiable(customMetadata) {
    final grouped = <String, List<ProcedureCustomMetadata>>{};
    for (final metadata in this.customMetadata) {
      grouped.putIfAbsent(metadata.key, () => []).add(metadata);
    }
    byKey = {
      for (final entry in grouped.entries)
        entry.key: List<ProcedureCustomMetadata>.unmodifiable(entry.value),
    };
  }
  final List<ProcedureParameterMetadata> parameters;
  final List<ProcedureCustomMetadata> customMetadata;
  late final Map<String, List<ProcedureCustomMetadata>> byKey;
}
