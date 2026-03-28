enum ProcedureParameterSourceKind { rpcInput, path, query, header, body }

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
  const RestProcedureMetadata({required this.method, required this.path});

  final String method;
  final String path;
}

final class ProcedureMetadata {
  const ProcedureMetadata({
    required this.rpcMethod,
    required this.controllerNamespace,
    required this.methodName,
    required this.outputTypeCode,
    this.path,
    this.inputTypeCode,
    this.description,
    this.tags = const [],
    this.parameters = const [],
  });

  final String rpcMethod;
  final String controllerNamespace;
  final String methodName;
  final RestProcedureMetadata? path;
  final String? inputTypeCode;
  final String outputTypeCode;
  final String? description;
  final List<String> tags;
  final List<ProcedureParameterMetadata> parameters;
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

      indexed[procedure.rpcMethod] = procedure;
    }

    return Map.unmodifiable(indexed);
  }
}
