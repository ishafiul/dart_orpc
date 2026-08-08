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
  });

  final String method;
  final String path;
  final RestResponseKind responseKind;
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
    this.customMetadata = const [],
    this.parameters = const [],
  });

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
  final List<ProcedureCustomMetadata> customMetadata;
  final List<ProcedureParameterMetadata> parameters;

  Iterable<ProcedureCustomMetadata> metadataEntries(String key) sync* {
    for (final metadata in customMetadata) {
      if (metadata.key == key) {
        yield metadata;
      }
    }
  }

  Iterable<JsonObject> metadataValues(String key) sync* {
    for (final metadata in metadataEntries(key)) {
      yield metadata.value;
    }
  }

  JsonObject? firstMetadataValue(String key) {
    for (final metadata in customMetadata) {
      if (metadata.key == key) {
        return metadata.value;
      }
    }

    return null;
  }
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
