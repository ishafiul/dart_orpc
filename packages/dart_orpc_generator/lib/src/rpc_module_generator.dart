import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:luthor/luthor.dart';
import 'package:source_gen/source_gen.dart';

const _controllerChecker = TypeChecker.typeNamed(
  Controller,
  inPackage: 'dart_orpc_annotations',
);
const _rpcInputChecker = TypeChecker.typeNamed(
  RpcInput,
  inPackage: 'dart_orpc_annotations',
);
const _rpcMethodChecker = TypeChecker.typeNamed(
  RpcMethod,
  inPackage: 'dart_orpc_annotations',
);
const _rpcContextChecker = TypeChecker.typeNamed(
  RpcContext,
  inPackage: 'dart_orpc_core',
);
const _pathParamChecker = TypeChecker.typeNamed(
  PathParam,
  inPackage: 'dart_orpc_annotations',
);
const _queryParamChecker = TypeChecker.typeNamed(
  QueryParam,
  inPackage: 'dart_orpc_annotations',
);
const _bodyChecker = TypeChecker.typeNamed(
  Body,
  inPackage: 'dart_orpc_annotations',
);
const _fromPathChecker = TypeChecker.typeNamed(
  FromPath,
  inPackage: 'dart_orpc_annotations',
);
const _fromQueryChecker = TypeChecker.typeNamed(
  FromQuery,
  inPackage: 'dart_orpc_annotations',
);
const _fromHeaderChecker = TypeChecker.typeNamed(
  FromHeader,
  inPackage: 'dart_orpc_annotations',
);
const _luthorChecker = TypeChecker.typeNamed(Luthor, inPackage: 'luthor');

final class RpcModuleGenerator extends GeneratorForAnnotation<Module> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! InterfaceElement) {
      throw InvalidGenerationSourceError(
        '@Module can only be applied to classes.',
        element: element,
      );
    }

    final moduleName = element.displayName;
    final providerElements = _readInterfaceElements(
      annotation.read('providers'),
      element: element,
      fieldName: 'providers',
    );
    final controllerElements = _readInterfaceElements(
      annotation.read('controllers'),
      element: element,
      fieldName: 'controllers',
    );

    final usedNames = <String>{};
    final providerInstantiations = _resolveProviderInstantiations(
      providerElements,
      usedNames: usedNames,
      moduleElement: element,
    );
    final availableProviders = {
      for (final instantiation in providerInstantiations)
        instantiation.typeKey: instantiation.variableName,
    };

    final controllerBindings = controllerElements
        .map(
          (controllerElement) => _buildControllerBinding(
            controllerElement,
            availableProviders: availableProviders,
            usedNames: usedNames,
          ),
        )
        .toList(growable: false);

    final rpcClientControllers = controllerBindings
        .where((controller) => controller.rpcCompatibleProcedures.isNotEmpty)
        .toList(growable: false);

    final rootClientName = _rootClientNameFor(moduleName);
    final createRegistryName = '_\$create${moduleName}ProcedureRegistry';
    final createRestRouteRegistryName =
        '_\$create${moduleName}RestRouteRegistry';
    final createMetadataRegistryName =
        '_\$create${moduleName}ProcedureMetadataRegistry';
    final createOpenApiSchemaRegistryName =
        '_\$create${moduleName}OpenApiSchemaRegistry';
    final createOpenApiDocumentName = '_\$create${moduleName}OpenApiDocument';
    final buildAppName = '_\$build${moduleName}RpcApp';
    final openApiTitle = _openApiTitleFor(moduleName);
    final openApiSchemaComponents = _collectOpenApiSchemaComponents(
      controllerBindings,
    );

    final buffer = StringBuffer()
      ..writeln('RpcProcedureRegistry $createRegistryName() {');

    for (final instantiation in providerInstantiations) {
      buffer.writeln('  ${instantiation.code}');
    }

    if (providerInstantiations.isNotEmpty && controllerBindings.isNotEmpty) {
      buffer.writeln();
    }

    for (var index = 0; index < controllerBindings.length; index++) {
      buffer.writeln('  ${controllerBindings[index].instantiationCode}');
      if (index < controllerBindings.length - 1) {
        buffer.writeln();
      }
    }

    if (controllerBindings.isNotEmpty) {
      buffer.writeln();
    }

    buffer..writeln('  return RpcProcedureRegistry([');

    for (final controller in controllerBindings) {
      for (final procedure in controller.rpcCompatibleProcedures) {
        final inputTypeCode = procedure.inputTypeCode ?? 'Null';
        buffer
          ..writeln(
            '    RpcProcedure<$inputTypeCode, ${procedure.outputTypeCode}>(',
          )
          ..writeln("      method: '${procedure.rpcMethod}',")
          ..writeln('      decodeInput: ${_decodeInputExpression(procedure)},')
          ..writeln(
            '      encodeOutput: ${_encodeOutputExpression(procedure)},',
          )
          ..writeln(
            '      handler: (context, input) => ${controller.instanceName}.${procedure.methodName}(${procedure.serverInvocationArguments}),',
          )
          ..writeln('    ),');
      }
    }

    buffer
      ..writeln('  ]);')
      ..writeln('}')
      ..writeln()
      ..writeln('RestRouteRegistry $createRestRouteRegistryName() {');

    for (final instantiation in providerInstantiations) {
      buffer.writeln('  ${instantiation.code}');
    }

    if (providerInstantiations.isNotEmpty && controllerBindings.isNotEmpty) {
      buffer.writeln();
    }

    for (var index = 0; index < controllerBindings.length; index++) {
      buffer.writeln('  ${controllerBindings[index].instantiationCode}');
      if (index < controllerBindings.length - 1) {
        buffer.writeln();
      }
    }

    if (controllerBindings.isNotEmpty) {
      buffer.writeln();
    }

    buffer.writeln('  return RestRouteRegistry([');

    for (final controller in controllerBindings) {
      for (final procedure in controller.procedures.where(
        (procedure) => procedure.path != null,
      )) {
        buffer
          ..writeln('    RestRoute(')
          ..writeln("      method: '${procedure.path!.method}',")
          ..writeln("      path: '${procedure.path!.path}',")
          ..writeln(
            '      handler: (context, request, pathParameters) async {',
          );

        if (procedure.restRpcInput != null) {
          for (final declaration in _restRpcInputDeclarations(
            procedure.restRpcInput!,
            procedure,
          )) {
            buffer.writeln('        $declaration');
          }
        }

        for (final parameter in procedure.restInvocationParameters) {
          if (parameter.source == _InvocationParameterSourceKind.rpcInput) {
            continue;
          }
          final declaration = _restParameterDeclaration(parameter, procedure);
          if (declaration != null) {
            buffer.writeln('        $declaration');
          }
        }

        final invocationArguments = procedure.restInvocationParameters
            .map(_restInvocationArgumentExpression)
            .join(', ');
        buffer
          ..writeln(
            '        final output = await ${controller.instanceName}.${procedure.methodName}($invocationArguments);',
          )
          ..writeln(
            '        return (${_encodeOutputExpression(procedure)})(output);',
          )
          ..writeln('      },')
          ..writeln('    ),');
      }
    }

    buffer
      ..writeln('  ]);')
      ..writeln('}')
      ..writeln()
      ..writeln('// ignore: unused_element')
      ..writeln('ProcedureMetadataRegistry $createMetadataRegistryName() {')
      ..writeln('  return ProcedureMetadataRegistry([');

    for (final controller in controllerBindings) {
      for (final procedure in controller.procedures) {
        buffer
          ..writeln('    const ProcedureMetadata(')
          ..writeln("      rpcMethod: '${procedure.rpcMethod}',")
          ..writeln(
            "      controllerNamespace: '${procedure.controllerNamespace}',",
          )
          ..writeln("      methodName: '${procedure.methodName}',");

        if (procedure.path != null) {
          buffer.writeln(
            "      path: RestProcedureMetadata(method: '${procedure.path!.method}', path: '${procedure.path!.path}'),",
          );
        }

        if (procedure.inputTypeCode != null) {
          buffer.writeln("      inputTypeCode: '${procedure.inputTypeCode}',");
        }

        buffer.writeln("      outputTypeCode: '${procedure.outputTypeCode}',");

        if (procedure.description != null) {
          buffer.writeln(
            "      description: '${_escapeDartString(procedure.description!)}',",
          );
        }

        if (procedure.tags.isNotEmpty) {
          buffer..writeln('      tags: [');
          for (final tag in procedure.tags) {
            buffer.writeln("        '${_escapeDartString(tag)}',");
          }
          buffer.writeln('      ],');
        }

        if (procedure.parameters.isNotEmpty) {
          buffer..writeln('      parameters: [');
          for (final parameter in procedure.parameters) {
            buffer
              ..writeln('        ProcedureParameterMetadata(')
              ..writeln(
                "          parameterName: '${parameter.parameterName}',",
              )
              ..writeln("          wireName: '${parameter.wireName}',")
              ..writeln(
                '          source: ProcedureParameterSourceKind.${parameter.source.name},',
              )
              ..writeln("          typeCode: '${parameter.typeCode}',")
              ..writeln('        ),');
          }
          buffer.writeln('      ],');
        }

        buffer.writeln('    ),');
      }
    }

    buffer
      ..writeln('  ]);')
      ..writeln('}')
      ..writeln()
      ..writeln('OpenApiSchemaRegistry $createOpenApiSchemaRegistryName() {')
      ..writeln('  return OpenApiSchemaRegistry([');

    for (final component in openApiSchemaComponents) {
      buffer
        ..writeln('    OpenApiSchemaComponent(')
        ..writeln("      name: '${component.name}',")
        ..writeln('      validator: ${component.validatorExpression},')
        ..writeln('    ),');
    }

    buffer
      ..writeln('  ]);')
      ..writeln('}')
      ..writeln()
      ..writeln('JsonObject $createOpenApiDocumentName() {')
      ..writeln('  return createOpenApiDocument(')
      ..writeln("    title: '${_escapeDartString(openApiTitle)}',")
      ..writeln('    procedures: $createMetadataRegistryName(),')
      ..writeln('    schemas: $createOpenApiSchemaRegistryName(),')
      ..writeln('  );')
      ..writeln('}')
      ..writeln()
      ..writeln('RpcHttpApp $buildAppName() {')
      ..writeln(
        '  return RpcHttpApp(procedures: $createRegistryName(), restRoutes: $createRestRouteRegistryName(), openApiDocument: $createOpenApiDocumentName(), docsHtml: createScalarHtml(title: \'${_escapeDartString(openApiTitle)}\'));',
      )
      ..writeln('}')
      ..writeln()
      ..writeln('class $rootClientName {')
      ..writeln(
        '  $rootClientName({required RpcTransport transport}) : _caller = RpcCaller(transport);',
      )
      ..writeln()
      ..writeln('  final RpcCaller _caller;');

    if (rpcClientControllers.isNotEmpty) {
      buffer.writeln();
      for (final controller in rpcClientControllers) {
        buffer.writeln(
          '  late final ${controller.clientClassName} ${controller.clientGetterName} = ${controller.clientClassName}(_caller);',
        );
      }
    }

    buffer.writeln('}');

    for (final controller in rpcClientControllers) {
      buffer
        ..writeln()
        ..writeln('class ${controller.clientClassName} {')
        ..writeln('  ${controller.clientClassName}(this._caller);')
        ..writeln()
        ..writeln('  final RpcCaller _caller;');

      for (final procedure in controller.rpcCompatibleProcedures) {
        if (procedure.hasInput) {
          buffer
            ..writeln()
            ..writeln(
              '  Future<${procedure.outputTypeCode}> ${procedure.methodName}(${procedure.inputTypeCode!} ${procedure.inputParameterName!}) {',
            )
            ..writeln('    return _caller.call<${procedure.outputTypeCode}>(')
            ..writeln("      method: '${procedure.rpcMethod}',")
            ..writeln('      input: ${procedure.inputParameterName!}.toJson(),')
            ..writeln(
              '      decode: (json) => ${procedure.outputTypeCode}.fromJson(Map<String, dynamic>.from(expectJsonObject(json, context: \'RPC response for "${procedure.rpcMethod}"\'))),',
            )
            ..writeln('    );')
            ..writeln('  }');
          continue;
        }

        buffer
          ..writeln()
          ..writeln(
            '  Future<${procedure.outputTypeCode}> ${procedure.methodName}() {',
          )
          ..writeln('    return _caller.call<${procedure.outputTypeCode}>(')
          ..writeln("      method: '${procedure.rpcMethod}',")
          ..writeln(
            '      decode: (json) => ${procedure.outputTypeCode}.fromJson(Map<String, dynamic>.from(expectJsonObject(json, context: \'RPC response for "${procedure.rpcMethod}"\'))),',
          )
          ..writeln('    );')
          ..writeln('  }');
      }

      buffer.writeln('}');
    }

    return buffer.toString().trimRight();
  }

  List<InterfaceElement> _readInterfaceElements(
    ConstantReader reader, {
    required Element element,
    required String fieldName,
  }) {
    return reader.listValue
        .map((object) {
          final type = object.toTypeValue();
          if (type is! InterfaceType) {
            throw InvalidGenerationSourceError(
              '@Module.$fieldName entries must be class types.',
              element: element,
            );
          }
          return type.element;
        })
        .toList(growable: false);
  }

  List<_ResolvedInstantiation> _resolveProviderInstantiations(
    List<InterfaceElement> providers, {
    required Set<String> usedNames,
    required Element moduleElement,
  }) {
    final resolved = <_ResolvedInstantiation>[];
    final availableProviders = <String, String>{};
    final remainingProviders = [...providers];

    while (remainingProviders.isNotEmpty) {
      var progressed = false;

      for (final provider in List<InterfaceElement>.from(remainingProviders)) {
        final instantiation = _tryBuildInstantiation(
          provider,
          availableProviders: availableProviders,
          usedNames: usedNames,
        );
        if (instantiation == null) {
          continue;
        }

        resolved.add(instantiation);
        availableProviders[instantiation.typeKey] = instantiation.variableName;
        remainingProviders.remove(provider);
        progressed = true;
      }

      if (progressed) {
        continue;
      }

      final unresolved = remainingProviders
          .map((provider) => provider.displayName)
          .join(', ');
      throw InvalidGenerationSourceError(
        'Unable to resolve provider constructor dependencies for: $unresolved.',
        element: moduleElement,
      );
    }

    return resolved;
  }

  _ControllerBinding _buildControllerBinding(
    InterfaceElement controllerElement, {
    required Map<String, String> availableProviders,
    required Set<String> usedNames,
  }) {
    final controllerAnnotation = _controllerChecker.firstAnnotationOfExact(
      controllerElement,
    );
    if (controllerAnnotation == null) {
      throw InvalidGenerationSourceError(
        'Controllers listed in @Module must be annotated with @Controller.',
        element: controllerElement,
      );
    }

    final namespace = ConstantReader(
      controllerAnnotation,
    ).read('namespace').stringValue;
    final controllerInstantiation = _tryBuildInstantiation(
      controllerElement,
      availableProviders: availableProviders,
      usedNames: usedNames,
    );

    if (controllerInstantiation == null) {
      throw InvalidGenerationSourceError(
        'Unable to resolve controller constructor dependencies for "${controllerElement.displayName}".',
        element: controllerElement,
      );
    }

    final procedures = controllerElement.methods
        .where((method) => _rpcMethodChecker.hasAnnotationOfExact(method))
        .map((method) => _buildMethodBinding(namespace, method))
        .toList(growable: false);

    if (procedures.isEmpty) {
      throw InvalidGenerationSourceError(
        'Controllers must declare at least one @RpcMethod.',
        element: controllerElement,
      );
    }

    return _ControllerBinding(
      instanceName: controllerInstantiation.variableName,
      instantiationCode: controllerInstantiation.code,
      clientClassName: _clientClassNameFor(controllerElement.displayName),
      clientGetterName: _clientGetterNameFor(namespace),
      procedures: procedures,
    );
  }

  _ResolvedProcedure _buildMethodBinding(
    String namespace,
    MethodElement method,
  ) {
    final methodAnnotation = _rpcMethodChecker.firstAnnotationOfExact(method);
    if (methodAnnotation == null) {
      throw InvalidGenerationSourceError(
        'RPC methods must be annotated with @RpcMethod.',
        element: method,
      );
    }

    final annotationReader = ConstantReader(methodAnnotation);
    final methodName = method.displayName;
    final path = _readPathMapping(annotationReader);
    final description = annotationReader.peek('description')?.stringValue;
    final tags = _readTags(annotationReader);
    final rpcInputParameters = method.formalParameters
        .where((parameter) => _rpcInputChecker.hasAnnotationOfExact(parameter))
        .toList(growable: false);
    final pathParameters = method.formalParameters
        .where((parameter) => _pathParamChecker.hasAnnotationOfExact(parameter))
        .toList(growable: false);
    final queryParameters = method.formalParameters
        .where(
          (parameter) => _queryParamChecker.hasAnnotationOfExact(parameter),
        )
        .toList(growable: false);
    final bodyParameters = method.formalParameters
        .where((parameter) => _bodyChecker.hasAnnotationOfExact(parameter))
        .toList(growable: false);

    if (rpcInputParameters.length > 1) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" may declare at most one @RpcInput parameter.',
        element: method,
      );
    }

    if (bodyParameters.length > 1) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" may declare at most one @Body parameter.',
        element: method,
      );
    }

    final hasRestSourceParameters =
        pathParameters.isNotEmpty ||
        queryParameters.isNotEmpty ||
        bodyParameters.isNotEmpty;

    if (hasRestSourceParameters && path == null) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" may only use @PathParam, @QueryParam, or @Body when RpcMethod(path: ...) is declared.',
        element: method,
      );
    }

    if (path != null &&
        rpcInputParameters.isNotEmpty &&
        hasRestSourceParameters) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" may not mix @RpcInput with @PathParam, @QueryParam, or @Body.',
        element: method,
      );
    }

    _ensureUniqueWireNames(
      pathParameters,
      annotationLabel: '@PathParam',
      wireNameFor: _pathParamWireName,
      methodName: methodName,
    );
    _ensureUniqueWireNames(
      queryParameters,
      annotationLabel: '@QueryParam',
      wireNameFor: _queryParamWireName,
      methodName: methodName,
    );

    if (path != null && rpcInputParameters.isEmpty) {
      _validateRestPathBindings(
        path.path,
        pathParameters,
        methodName: methodName,
      );
    }

    final inputParameter = rpcInputParameters.isEmpty
        ? null
        : rpcInputParameters.single;
    final rpcInputBinding = inputParameter == null
        ? null
        : _readRpcInputBinding(inputParameter);
    if (rpcInputBinding != null && path == null) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" may only use @RpcInput(binding: ...) when RpcMethod(path: ...) is declared.',
        element: inputParameter,
      );
    }
    final restRpcInput =
        path != null && inputParameter != null && !hasRestSourceParameters
        ? _resolveRestRpcInput(
            inputParameter,
            path: path,
            methodName: methodName,
            binding: rpcInputBinding,
          )
        : null;
    final invocationArguments = <String>[];
    final restInvocationParameters = <_ResolvedInvocationParameter>[];
    final parameters = <_ResolvedParameter>[];
    var supportsRpcGeneration = true;

    for (final parameter in method.formalParameters) {
      if (_isRpcContext(parameter.type)) {
        invocationArguments.add('context');
        restInvocationParameters.add(
          const _ResolvedInvocationParameter(
            parameterName: 'context',
            source: _InvocationParameterSourceKind.context,
            typeCode: 'RpcContext',
            wireName: null,
            typeName: null,
            usesLuthor: false,
          ),
        );
        continue;
      }

      if (_rpcInputChecker.hasAnnotationOfExact(parameter)) {
        invocationArguments.add('input');
        if (restRpcInput == null) {
          parameters.add(
            _ResolvedParameter(
              parameterName: parameter.displayName,
              wireName: parameter.displayName,
              source: ProcedureParameterSourceKind.rpcInput,
              typeCode: parameter.type.getDisplayString(),
            ),
          );
        } else {
          parameters.addAll(restRpcInput.metadataParameters);
        }
        restInvocationParameters.add(
          _ResolvedInvocationParameter(
            parameterName: parameter.displayName,
            source: _InvocationParameterSourceKind.rpcInput,
            typeCode: parameter.type.getDisplayString(),
            wireName: parameter.displayName,
            typeName: parameter.type.element?.displayName,
            usesLuthor: _usesLuthorValidation(parameter.type),
          ),
        );
        continue;
      }

      if (_pathParamChecker.hasAnnotationOfExact(parameter)) {
        supportsRpcGeneration = false;
        _ensureSupportedRestScalarParameter(
          parameter,
          sourceLabel: '@PathParam',
          methodName: methodName,
        );
        parameters.add(
          _ResolvedParameter(
            parameterName: parameter.displayName,
            wireName: _pathParamWireName(parameter),
            source: ProcedureParameterSourceKind.path,
            typeCode: parameter.type.getDisplayString(),
          ),
        );
        restInvocationParameters.add(
          _ResolvedInvocationParameter(
            parameterName: parameter.displayName,
            source: _InvocationParameterSourceKind.path,
            typeCode: parameter.type.getDisplayString(),
            wireName: _pathParamWireName(parameter),
            typeName: parameter.type.element?.displayName,
            usesLuthor: false,
          ),
        );
        continue;
      }

      if (_queryParamChecker.hasAnnotationOfExact(parameter)) {
        supportsRpcGeneration = false;
        _ensureSupportedRestScalarParameter(
          parameter,
          sourceLabel: '@QueryParam',
          methodName: methodName,
        );
        parameters.add(
          _ResolvedParameter(
            parameterName: parameter.displayName,
            wireName: _queryParamWireName(parameter),
            source: ProcedureParameterSourceKind.query,
            typeCode: parameter.type.getDisplayString(),
          ),
        );
        restInvocationParameters.add(
          _ResolvedInvocationParameter(
            parameterName: parameter.displayName,
            source: _InvocationParameterSourceKind.query,
            typeCode: parameter.type.getDisplayString(),
            wireName: _queryParamWireName(parameter),
            typeName: parameter.type.element?.displayName,
            usesLuthor: false,
          ),
        );
        continue;
      }

      if (_bodyChecker.hasAnnotationOfExact(parameter)) {
        supportsRpcGeneration = false;
        parameters.add(
          _ResolvedParameter(
            parameterName: parameter.displayName,
            wireName: parameter.displayName,
            source: ProcedureParameterSourceKind.body,
            typeCode: parameter.type.getDisplayString(),
          ),
        );
        restInvocationParameters.add(
          _ResolvedInvocationParameter(
            parameterName: parameter.displayName,
            source: _InvocationParameterSourceKind.body,
            typeCode: parameter.type.getDisplayString(),
            wireName: parameter.displayName,
            typeName: parameter.type.element?.displayName,
            usesLuthor: _usesLuthorValidation(parameter.type),
          ),
        );
        continue;
      }

      throw InvalidGenerationSourceError(
        'RPC method "$methodName" only supports an optional RpcContext, one @RpcInput parameter, and explicit REST source parameters (@PathParam, @QueryParam, @Body).',
        element: parameter,
      );
    }

    final outputType = _unwrapFuture(method.returnType);
    final wireName = annotationReader.peek('name')?.stringValue ?? methodName;

    return _ResolvedProcedure(
      controllerNamespace: namespace,
      methodName: methodName,
      rpcMethod: '$namespace.$wireName',
      path: path,
      description: description,
      tags: tags,
      parameters: parameters,
      restInvocationParameters: restInvocationParameters,
      restRpcInput: restRpcInput,
      hasInput: inputParameter != null,
      inputTypeCode: inputParameter?.type.getDisplayString(),
      inputTypeName: inputParameter?.type.element?.displayName,
      inputParameterName: inputParameter?.displayName,
      inputUsesLuthor: inputParameter == null
          ? false
          : _usesLuthorValidation(inputParameter.type),
      outputTypeCode: outputType.getDisplayString(),
      outputTypeName:
          outputType.element?.displayName ?? outputType.getDisplayString(),
      outputUsesLuthor: _usesLuthorValidation(outputType),
      supportsRpcGeneration: supportsRpcGeneration,
      serverInvocationArguments: invocationArguments.join(', '),
    );
  }

  _ResolvedPathMapping? _readPathMapping(ConstantReader annotationReader) {
    final pathReader = annotationReader.peek('path');
    if (pathReader == null || pathReader.isNull) {
      return null;
    }

    final method = pathReader.read('method').stringValue;
    final rawPath = pathReader.read('rawPath').stringValue;
    return _ResolvedPathMapping(
      method: method,
      path: _normalizeRestPath(rawPath),
    );
  }

  List<String> _readTags(ConstantReader annotationReader) {
    final tagsReader = annotationReader.peek('tags');
    if (tagsReader == null || tagsReader.isNull) {
      return const [];
    }

    return tagsReader.listValue
        .map((tag) => ConstantReader(tag).stringValue)
        .toList(growable: false);
  }

  String _escapeDartString(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\$', r'\$');
  }

  String _normalizeRestPath(String rawPath) {
    if (rawPath.isEmpty) {
      return '/';
    }

    return rawPath.startsWith('/') ? rawPath : '/$rawPath';
  }

  String _decodeInputExpression(_ResolvedProcedure procedure) {
    if (procedure.hasInput) {
      if (procedure.inputUsesLuthor) {
        return '(rawInput) => decodeRpcInputWithLuthor<${procedure.inputTypeCode!}>(rawInput: rawInput, method: \'${procedure.rpcMethod}\', validate: \$${procedure.inputTypeName!}Validate)';
      }

      return '(rawInput) => ${procedure.inputTypeCode!}.fromJson(Map<String, dynamic>.from(expectJsonObject(rawInput, context: \'RPC method "${procedure.rpcMethod}" input\')))';
    }

    return '(rawInput) => expectNoRpcInput(rawInput, context: \'RPC method "${procedure.rpcMethod}"\')';
  }

  String _encodeOutputExpression(_ResolvedProcedure procedure) {
    if (procedure.outputUsesLuthor) {
      return '(output) => encodeRpcOutputWithLuthor<${procedure.outputTypeCode}>(output: output, method: \'${procedure.rpcMethod}\', toJson: (output) => output.toJson(), validate: \$${procedure.outputTypeName}Validate)';
    }

    return '(output) => output.toJson()';
  }

  String? _restParameterDeclaration(
    _ResolvedInvocationParameter parameter,
    _ResolvedProcedure procedure,
  ) {
    final routeLabel = _restRouteLabel(procedure);
    switch (parameter.source) {
      case _InvocationParameterSourceKind.context:
        return null;
      case _InvocationParameterSourceKind.rpcInput:
        return null;
      case _InvocationParameterSourceKind.path:
        return 'final ${parameter.parameterName} = decodeRestScalarParameter<${parameter.typeCode}>(rawValue: pathParameters[\'${parameter.wireName}\'], source: \'path parameter\', name: \'${parameter.wireName}\', route: \'$routeLabel\');';
      case _InvocationParameterSourceKind.query:
        return 'final ${parameter.parameterName} = decodeRestScalarParameter<${parameter.typeCode}>(rawValue: request.queryParameters[\'${parameter.wireName}\'], source: \'query parameter\', name: \'${parameter.wireName}\', route: \'$routeLabel\');';
      case _InvocationParameterSourceKind.header:
        return 'final ${parameter.parameterName} = decodeRestScalarParameter<${parameter.typeCode}>(rawValue: lookupRestHeader(request.headers, \'${_escapeDartString(parameter.wireName!)}\'), source: \'header\', name: \'${_escapeDartString(parameter.wireName!)}\', route: \'$routeLabel\');';
      case _InvocationParameterSourceKind.body:
        return 'final ${parameter.parameterName} = decodeRestBody<${parameter.typeCode}>(rawBody: request.body, route: \'$routeLabel\', parameterName: \'${parameter.parameterName}\', decode: ${_decodeRestBodyExpression(parameter, procedure)});';
    }
  }

  String _restInvocationArgumentExpression(
    _ResolvedInvocationParameter parameter,
  ) {
    switch (parameter.source) {
      case _InvocationParameterSourceKind.context:
        return 'context';
      case _InvocationParameterSourceKind.rpcInput:
      case _InvocationParameterSourceKind.path:
      case _InvocationParameterSourceKind.query:
      case _InvocationParameterSourceKind.header:
      case _InvocationParameterSourceKind.body:
        return parameter.parameterName;
    }
  }

  String _decodeRestBodyExpression(
    _ResolvedInvocationParameter parameter,
    _ResolvedProcedure procedure,
  ) {
    final routeLabel = _restRouteLabel(procedure);
    final bodyContext = '$routeLabel body';
    final nonNullableTypeCode = _nonNullableTypeCode(parameter.typeCode);

    if (_usesJsonObjectBodyDecode(nonNullableTypeCode)) {
      return "(rawBody) => expectJsonObject(rawBody, context: '$bodyContext')";
    }

    if (_isSupportedRestScalarType(parameter.typeCode)) {
      return "(rawBody) => decodeRestJsonValue<${parameter.typeCode}>(rawValue: rawBody, source: 'body parameter', name: '${parameter.parameterName}', route: '$routeLabel')";
    }

    if (parameter.usesLuthor) {
      return "(rawBody) => decodeRpcInputWithLuthor<${parameter.typeCode}>(rawInput: rawBody, method: '$bodyContext', validate: \$${parameter.typeName!}Validate)";
    }

    return "(rawBody) => ${parameter.typeName!}.fromJson(Map<String, dynamic>.from(expectJsonObject(rawBody, context: '$bodyContext')))";
  }

  String _restRouteLabel(_ResolvedProcedure procedure) {
    return '${procedure.path!.method} ${procedure.path!.path}';
  }

  List<String> _restRpcInputDeclarations(
    _ResolvedRestRpcInput restRpcInput,
    _ResolvedProcedure procedure,
  ) {
    final routeLabel = _restRouteLabel(procedure);
    final lines = <String>[];

    switch (restRpcInput.mode) {
      case _ResolvedRestRpcInputMode.query:
        lines.add('final rawInput = <String, Object?>{};');
        for (final pathField in restRpcInput.pathFields) {
          lines.add(
            "rawInput['${pathField.name}'] = decodeRestScalarParameter<${pathField.typeCode}>(rawValue: pathParameters['${pathField.wireName}'], source: 'path parameter', name: '${pathField.wireName}', route: '$routeLabel');",
          );
        }
        for (final queryField in restRpcInput.queryFields) {
          lines.add(
            "rawInput['${queryField.name}'] = decodeRestScalarParameter<${queryField.typeCode}>(rawValue: request.queryParameters['${queryField.wireName}'], source: 'query parameter', name: '${queryField.wireName}', route: '$routeLabel');",
          );
        }
        for (final headerField in restRpcInput.headerFields) {
          lines.add(
            "rawInput['${headerField.name}'] = decodeRestScalarParameter<${headerField.typeCode}>(rawValue: lookupRestHeader(request.headers, '${_escapeDartString(headerField.wireName)}'), source: 'header', name: '${_escapeDartString(headerField.wireName)}', route: '$routeLabel');",
          );
        }
      case _ResolvedRestRpcInputMode.body:
        if (restRpcInput.bodyFields.isNotEmpty) {
          lines.add(
            "final rawInput = request.body.trim().isEmpty ? <String, Object?>{} : Map<String, Object?>.from(decodeRestBody<JsonObject>(rawBody: request.body, route: '$routeLabel', parameterName: '${restRpcInput.parameterName}', decode: (rawJson) => expectJsonObject(rawJson, context: '$routeLabel body')));",
          );
        } else {
          lines.add('final rawInput = <String, Object?>{};');
        }
        for (final pathField in restRpcInput.pathFields) {
          lines.add(
            "rawInput['${pathField.name}'] = decodeRestScalarParameter<${pathField.typeCode}>(rawValue: pathParameters['${pathField.wireName}'], source: 'path parameter', name: '${pathField.wireName}', route: '$routeLabel');",
          );
        }
        for (final queryField in restRpcInput.queryFields) {
          lines.add(
            "rawInput['${queryField.name}'] = decodeRestScalarParameter<${queryField.typeCode}>(rawValue: request.queryParameters['${queryField.wireName}'], source: 'query parameter', name: '${queryField.wireName}', route: '$routeLabel');",
          );
        }
        for (final headerField in restRpcInput.headerFields) {
          lines.add(
            "rawInput['${headerField.name}'] = decodeRestScalarParameter<${headerField.typeCode}>(rawValue: lookupRestHeader(request.headers, '${_escapeDartString(headerField.wireName)}'), source: 'header', name: '${_escapeDartString(headerField.wireName)}', route: '$routeLabel');",
          );
        }
    }

    lines.add(
      'final ${restRpcInput.parameterName} = (${_decodeInputExpression(procedure)})(rawInput);',
    );

    return lines;
  }

  void _ensureUniqueWireNames(
    List<FormalParameterElement> parameters, {
    required String annotationLabel,
    required String Function(FormalParameterElement parameter) wireNameFor,
    required String methodName,
  }) {
    final seenWireNames = <String>{};

    for (final parameter in parameters) {
      final wireName = wireNameFor(parameter);
      if (!seenWireNames.add(wireName)) {
        throw InvalidGenerationSourceError(
          'RPC method "$methodName" declares duplicate $annotationLabel wire name "$wireName".',
          element: parameter,
        );
      }
    }
  }

  void _ensureSupportedRestScalarParameter(
    FormalParameterElement parameter, {
    required String sourceLabel,
    required String methodName,
  }) {
    final typeCode = parameter.type.getDisplayString();
    if (_isSupportedRestScalarType(typeCode)) {
      return;
    }

    throw InvalidGenerationSourceError(
      'RPC method "$methodName" only supports String, int, double, or bool parameter types for $sourceLabel.',
      element: parameter,
    );
  }

  void _validateRestPathBindings(
    String routePath,
    List<FormalParameterElement> pathParameters, {
    required String methodName,
  }) {
    final placeholderMatches = RegExp(
      r':([A-Za-z_][A-Za-z0-9_]*)',
    ).allMatches(routePath);
    final routeParameters = placeholderMatches
        .map((match) => match.group(1)!)
        .toSet();
    final boundParameters = pathParameters.map(_pathParamWireName).toSet();

    final unknownBindings = boundParameters.difference(routeParameters);
    if (unknownBindings.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" declares @PathParam bindings not present in route "$routePath": ${unknownBindings.join(', ')}.',
      );
    }

    final missingBindings = routeParameters.difference(boundParameters);
    if (missingBindings.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" must declare @PathParam bindings for route "$routePath": ${missingBindings.join(', ')}.',
      );
    }
  }

  _ResolvedRestRpcInput _resolveRestRpcInput(
    FormalParameterElement inputParameter, {
    required _ResolvedPathMapping path,
    required String methodName,
    _ResolvedRpcInputDetails? binding,
  }) {
    final inputFields = _resolveDtoFields(
      inputParameter.type,
      methodName: methodName,
    );
    if (inputFields.isEmpty) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" could not infer fields from input DTO "${inputParameter.type.getDisplayString()}".',
        element: inputParameter,
      );
    }

    final fieldByName = <String, _ResolvedDtoField>{
      for (final field in inputFields) field.name: field,
    };
    final routeParameters = RegExp(r':([A-Za-z_][A-Za-z0-9_]*)')
        .allMatches(path.path)
        .map((match) => match.group(1)!)
        .toList(growable: false);

    final defaultDetails = _rpcInputBindingFromDtoFields(inputFields);
    final effectiveDetails = _mergeRpcInputDetails(defaultDetails, binding);

    _validateRpcInputDetails(
      effectiveDetails,
      fieldByName: fieldByName,
      routeParameters: routeParameters,
      methodName: methodName,
      element: inputParameter,
    );

    final explicitSourceByField = <String, _ResolvedRpcInputField>{};
    for (final binding in [
      ...effectiveDetails.path,
      ...effectiveDetails.query,
      ...effectiveDetails.headers,
      ...effectiveDetails.body,
    ]) {
      explicitSourceByField[binding.fieldName] = binding;
    }

    final explicitPathByWireName = <String, _ResolvedRpcInputField>{
      for (final binding in effectiveDetails.path) binding.wireName: binding,
    };

    final pathFields = <_ResolvedRestInputField>[];
    final boundFieldNames = <String>{};
    for (final routeParameter in routeParameters) {
      final explicitPathBinding = explicitPathByWireName[routeParameter];
      if (explicitPathBinding != null) {
        final field = fieldByName[explicitPathBinding.fieldName]!;
        _ensureSupportedRestInputField(
          field,
          sourceLabel: 'path parameter',
          methodName: methodName,
          element: inputParameter,
        );
        pathFields.add(
          _ResolvedRestInputField(
            name: field.name,
            typeCode: field.typeCode,
            wireName: explicitPathBinding.wireName,
          ),
        );
        boundFieldNames.add(field.name);
        continue;
      }

      final conflictingBinding = explicitSourceByField[routeParameter];
      if (conflictingBinding != null && conflictingBinding.source != 'path') {
        throw InvalidGenerationSourceError(
          'REST-enabled RPC method "$methodName" binds DTO field "$routeParameter" from ${conflictingBinding.source}, but route "${path.path}" requires it as a path parameter.',
          element: inputParameter,
        );
      }

      final field = fieldByName[routeParameter];
      if (field == null) {
        throw InvalidGenerationSourceError(
          'REST-enabled RPC method "$methodName" must declare input DTO field "$routeParameter" required by route "${path.path}".',
          element: inputParameter,
        );
      }

      _ensureSupportedRestInputField(
        field,
        sourceLabel: 'path parameter',
        methodName: methodName,
        element: inputParameter,
      );
      pathFields.add(
        _ResolvedRestInputField(
          name: field.name,
          typeCode: field.typeCode,
          wireName: routeParameter,
        ),
      );
      boundFieldNames.add(field.name);
    }

    final queryFields = <_ResolvedRestInputField>[
      for (final binding in effectiveDetails.query)
        _resolveRestInputFieldBinding(
          binding,
          fieldByName: fieldByName,
          sourceLabel: 'query parameter',
          methodName: methodName,
          element: inputParameter,
        ),
    ];
    final headerFields = <_ResolvedRestInputField>[
      for (final binding in effectiveDetails.headers)
        _resolveRestInputFieldBinding(
          binding,
          fieldByName: fieldByName,
          sourceLabel: 'header',
          methodName: methodName,
          element: inputParameter,
        ),
    ];
    final explicitBodyFields = <_ResolvedRestInputField>[
      for (final binding in effectiveDetails.body)
        _resolveRestInputFieldBinding(
          binding,
          fieldByName: fieldByName,
          sourceLabel: 'body',
          methodName: methodName,
          element: inputParameter,
          allowCustomWireName: false,
          requiresScalar: false,
        ),
    ];

    boundFieldNames.addAll(queryFields.map((field) => field.name));
    boundFieldNames.addAll(headerFields.map((field) => field.name));
    boundFieldNames.addAll(explicitBodyFields.map((field) => field.name));

    final remainingFields = inputFields
        .where((field) => !boundFieldNames.contains(field.name))
        .toList(growable: false);
    final httpMethod = path.method.toUpperCase();

    if (httpMethod == 'GET' || httpMethod == 'DELETE') {
      if (explicitBodyFields.isNotEmpty) {
        throw InvalidGenerationSourceError(
          'REST-enabled RPC method "$methodName" may not bind @RpcInput(binding: ...) body fields for ${path.method} routes.',
          element: inputParameter,
        );
      }

      for (final field in remainingFields) {
        _ensureSupportedRestInputField(
          field,
          sourceLabel: 'query parameter',
          methodName: methodName,
          element: inputParameter,
        );
      }

      return _ResolvedRestRpcInput(
        parameterName: inputParameter.displayName,
        mode: _ResolvedRestRpcInputMode.query,
        pathFields: pathFields,
        queryFields: [
          ...queryFields,
          for (final field in remainingFields)
            _ResolvedRestInputField(
              name: field.name,
              typeCode: field.typeCode,
              wireName: field.name,
            ),
        ],
        headerFields: headerFields,
        bodyFields: const [],
        metadataParameters: [
          for (final field in pathFields)
            _ResolvedParameter(
              parameterName: field.name,
              wireName: field.wireName,
              source: ProcedureParameterSourceKind.path,
              typeCode: field.typeCode,
            ),
          for (final field in [
            ...queryFields,
            for (final remainingField in remainingFields)
              _ResolvedRestInputField(
                name: remainingField.name,
                typeCode: remainingField.typeCode,
                wireName: remainingField.name,
              ),
          ])
            _ResolvedParameter(
              parameterName: field.name,
              wireName: field.wireName,
              source: ProcedureParameterSourceKind.query,
              typeCode: field.typeCode,
            ),
          for (final field in headerFields)
            _ResolvedParameter(
              parameterName: field.name,
              wireName: field.wireName,
              source: ProcedureParameterSourceKind.header,
              typeCode: field.typeCode,
            ),
        ],
      );
    }

    final bodyFields = [
      ...explicitBodyFields,
      for (final field in remainingFields)
        _ResolvedRestInputField(
          name: field.name,
          typeCode: field.typeCode,
          wireName: field.name,
        ),
    ];

    return _ResolvedRestRpcInput(
      parameterName: inputParameter.displayName,
      mode: _ResolvedRestRpcInputMode.body,
      pathFields: pathFields,
      queryFields: queryFields,
      headerFields: headerFields,
      bodyFields: bodyFields,
      metadataParameters: [
        for (final field in pathFields)
          _ResolvedParameter(
            parameterName: field.name,
            wireName: field.wireName,
            source: ProcedureParameterSourceKind.path,
            typeCode: field.typeCode,
          ),
        for (final field in queryFields)
          _ResolvedParameter(
            parameterName: field.name,
            wireName: field.wireName,
            source: ProcedureParameterSourceKind.query,
            typeCode: field.typeCode,
          ),
        for (final field in headerFields)
          _ResolvedParameter(
            parameterName: field.name,
            wireName: field.wireName,
            source: ProcedureParameterSourceKind.header,
            typeCode: field.typeCode,
          ),
        if (bodyFields.isNotEmpty)
          _ResolvedParameter(
            parameterName: inputParameter.displayName,
            wireName: inputParameter.displayName,
            source: ProcedureParameterSourceKind.body,
            typeCode: inputParameter.type.getDisplayString(),
          ),
      ],
    );
  }

  List<_ResolvedDtoField> _resolveDtoFields(
    DartType type, {
    required String methodName,
  }) {
    final element = type.element;
    if (element is! InterfaceElement) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" requires an interface or class DTO input type.',
      );
    }

    final fieldsByName = <String, _ResolvedDtoFieldBuilder>{};

    void recordField(
      String name,
      String typeCode, {
      _ResolvedDtoFieldBinding? binding,
    }) {
      final field = fieldsByName.putIfAbsent(
        name,
        () => _ResolvedDtoFieldBuilder(name: name, typeCode: typeCode),
      );
      if (binding != null) {
        field.applyBinding(binding, methodName: methodName, element: element);
      }
    }

    for (final field in element.fields) {
      final name = field.displayName;
      if (field.isStatic || name.startsWith('_')) {
        continue;
      }

      recordField(
        name,
        field.type.getDisplayString(),
        binding: _readResolvedDtoFieldBinding(field, methodName: methodName),
      );
    }

    for (final getter in element.getters) {
      if (getter.isStatic) {
        continue;
      }

      final name = getter.displayName;
      if (name.startsWith('_') || name == 'hashCode' || name == 'runtimeType') {
        continue;
      }

      recordField(
        name,
        getter.returnType.getDisplayString(),
        binding: _readResolvedDtoFieldBinding(getter, methodName: methodName),
      );
    }

    final candidateConstructors = element.constructors.where((constructor) {
      final name = constructor.name ?? '';
      return name.isEmpty || name == 'new';
    });

    for (final constructor in candidateConstructors) {
      for (final parameter in constructor.formalParameters) {
        final name = parameter.displayName;
        if (name.startsWith('_')) {
          continue;
        }

        recordField(
          name,
          parameter.type.getDisplayString(),
          binding: _readResolvedDtoFieldBinding(
            parameter,
            methodName: methodName,
          ),
        );
      }
    }

    return fieldsByName.values
        .map((field) => field.build())
        .toList(growable: false);
  }

  _ResolvedDtoFieldBinding? _readResolvedDtoFieldBinding(
    Element element, {
    required String methodName,
  }) {
    final bindings = <_ResolvedDtoFieldBinding>[];

    final pathAnnotation = _fromPathChecker.firstAnnotationOfExact(element);
    if (pathAnnotation != null) {
      final reader = ConstantReader(pathAnnotation);
      bindings.add(
        _ResolvedDtoFieldBinding(
          source: 'path',
          wireName: reader.peek('name')?.stringValue,
        ),
      );
    }

    final queryAnnotation = _fromQueryChecker.firstAnnotationOfExact(element);
    if (queryAnnotation != null) {
      final reader = ConstantReader(queryAnnotation);
      bindings.add(
        _ResolvedDtoFieldBinding(
          source: 'query',
          wireName: reader.peek('name')?.stringValue,
        ),
      );
    }

    final headerAnnotation = _fromHeaderChecker.firstAnnotationOfExact(element);
    if (headerAnnotation != null) {
      final reader = ConstantReader(headerAnnotation);
      bindings.add(
        _ResolvedDtoFieldBinding(
          source: 'header',
          wireName: reader.peek('name')?.stringValue,
        ),
      );
    }

    if (bindings.length > 1) {
      throw InvalidGenerationSourceError(
        'RPC DTO field "${element.displayName}" may declare at most one of @FromPath, @FromQuery, or @FromHeader.',
        element: element,
      );
    }

    if (bindings.isEmpty) {
      return null;
    }

    return bindings.single;
  }

  _ResolvedRpcInputDetails? _readRpcInputBinding(
    FormalParameterElement parameter,
  ) {
    final annotation = _rpcInputChecker.firstAnnotationOfExact(parameter);
    if (annotation == null) {
      return null;
    }

    final reader = ConstantReader(annotation);
    final bindingReader = reader.peek('binding');
    if (bindingReader == null || bindingReader.isNull) {
      return null;
    }

    return _ResolvedRpcInputDetails(
      path: _readRpcInputFieldBindings(
        bindingReader.read('path'),
        source: 'path',
      ),
      query: _readRpcInputFieldBindings(
        bindingReader.read('query'),
        source: 'query',
      ),
      headers: _readRpcInputFieldBindings(
        bindingReader.read('headers'),
        source: 'header',
      ),
      body: _readRpcInputFieldBindings(
        bindingReader.read('body'),
        source: 'body',
      ),
    );
  }

  List<_ResolvedRpcInputField> _readRpcInputFieldBindings(
    ConstantReader reader, {
    required String source,
  }) {
    if (reader.isNull) {
      return const [];
    }

    return reader.listValue
        .map((value) {
          final bindingReader = ConstantReader(value);
          return _ResolvedRpcInputField(
            fieldName: bindingReader.read('field').stringValue,
            wireName:
                bindingReader.peek('name')?.stringValue ??
                bindingReader.read('field').stringValue,
            source: source,
          );
        })
        .toList(growable: false);
  }

  _ResolvedRpcInputDetails _rpcInputBindingFromDtoFields(
    List<_ResolvedDtoField> inputFields,
  ) {
    return _ResolvedRpcInputDetails(
      path: [
        for (final field in inputFields)
          if (field.defaultSource == 'path')
            _ResolvedRpcInputField(
              fieldName: field.name,
              wireName: field.defaultWireName ?? field.name,
              source: 'path',
            ),
      ],
      query: [
        for (final field in inputFields)
          if (field.defaultSource == 'query')
            _ResolvedRpcInputField(
              fieldName: field.name,
              wireName: field.defaultWireName ?? field.name,
              source: 'query',
            ),
      ],
      headers: [
        for (final field in inputFields)
          if (field.defaultSource == 'header')
            _ResolvedRpcInputField(
              fieldName: field.name,
              wireName: field.defaultWireName ?? field.name,
              source: 'header',
            ),
      ],
      body: const [],
    );
  }

  _ResolvedRpcInputDetails _mergeRpcInputDetails(
    _ResolvedRpcInputDetails defaults,
    _ResolvedRpcInputDetails? overrides,
  ) {
    if (overrides == null) {
      return defaults;
    }

    final overriddenFields = <String>{
      for (final binding in [
        ...overrides.path,
        ...overrides.query,
        ...overrides.headers,
        ...overrides.body,
      ])
        binding.fieldName,
    };

    List<_ResolvedRpcInputField> merged(
      List<_ResolvedRpcInputField> defaultBindings,
      List<_ResolvedRpcInputField> overrideBindings,
    ) {
      return [
        for (final binding in defaultBindings)
          if (!overriddenFields.contains(binding.fieldName)) binding,
        ...overrideBindings,
      ];
    }

    return _ResolvedRpcInputDetails(
      path: merged(defaults.path, overrides.path),
      query: merged(defaults.query, overrides.query),
      headers: merged(defaults.headers, overrides.headers),
      body: merged(defaults.body, overrides.body),
    );
  }

  void _validateRpcInputDetails(
    _ResolvedRpcInputDetails details, {
    required Map<String, _ResolvedDtoField> fieldByName,
    required List<String> routeParameters,
    required String methodName,
    required Element element,
  }) {
    final boundFieldNames = <String>{};
    for (final binding in [
      ...details.path,
      ...details.query,
      ...details.headers,
      ...details.body,
    ]) {
      if (!fieldByName.containsKey(binding.fieldName)) {
        throw InvalidGenerationSourceError(
          'REST-enabled RPC method "$methodName" references unknown DTO field "${binding.fieldName}" in @RpcInput(binding: ...).',
          element: element,
        );
      }

      if (!boundFieldNames.add(binding.fieldName)) {
        throw InvalidGenerationSourceError(
          'REST-enabled RPC method "$methodName" may not bind DTO field "${binding.fieldName}" from more than one @RpcInput(binding: ...) source.',
          element: element,
        );
      }
    }

    _ensureUniqueRpcInputDetailWireNames(
      details.path,
      sourceLabel: 'path',
      methodName: methodName,
      element: element,
    );
    _ensureUniqueRpcInputDetailWireNames(
      details.query,
      sourceLabel: 'query',
      methodName: methodName,
      element: element,
    );
    _ensureUniqueRpcInputDetailWireNames(
      details.headers,
      sourceLabel: 'header',
      methodName: methodName,
      element: element,
    );

    final routeParameterSet = routeParameters.toSet();
    final unknownPathBindings = details.path
        .where((binding) => !routeParameterSet.contains(binding.wireName))
        .toList(growable: false);
    if (unknownPathBindings.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" declares @RpcInput(binding: ...) path bindings not present in route: ${unknownPathBindings.map((binding) => binding.wireName).join(', ')}.',
        element: element,
      );
    }

    final invalidBodyBindings = details.body
        .where((binding) => binding.wireName != binding.fieldName)
        .toList(growable: false);
    if (invalidBodyBindings.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" does not support custom body wire names in @RpcInput(binding: ...).',
        element: element,
      );
    }
  }

  void _ensureUniqueRpcInputDetailWireNames(
    List<_ResolvedRpcInputField> bindings, {
    required String sourceLabel,
    required String methodName,
    required Element element,
  }) {
    final seenWireNames = <String>{};
    for (final binding in bindings) {
      if (!seenWireNames.add(binding.wireName)) {
        throw InvalidGenerationSourceError(
          'REST-enabled RPC method "$methodName" declares duplicate $sourceLabel binding "${binding.wireName}" in @RpcInput(binding: ...).',
          element: element,
        );
      }
    }
  }

  _ResolvedRestInputField _resolveRestInputFieldBinding(
    _ResolvedRpcInputField binding, {
    required Map<String, _ResolvedDtoField> fieldByName,
    required String sourceLabel,
    required String methodName,
    required Element element,
    bool allowCustomWireName = true,
    bool requiresScalar = true,
  }) {
    final field = fieldByName[binding.fieldName]!;
    if (requiresScalar) {
      _ensureSupportedRestInputField(
        field,
        sourceLabel: sourceLabel,
        methodName: methodName,
        element: element,
      );
    }
    if (!allowCustomWireName && binding.wireName != binding.fieldName) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" does not support custom $sourceLabel names for DTO field "${binding.fieldName}".',
        element: element,
      );
    }

    return _ResolvedRestInputField(
      name: field.name,
      typeCode: field.typeCode,
      wireName: binding.wireName,
    );
  }

  void _ensureSupportedRestInputField(
    _ResolvedDtoField field, {
    required String sourceLabel,
    required String methodName,
    required Element element,
  }) {
    if (_isSupportedRestScalarType(field.typeCode)) {
      return;
    }

    throw InvalidGenerationSourceError(
      'REST-enabled RPC method "$methodName" only supports String, int, double, or bool input DTO fields for $sourceLabel binding. Unsupported field: "${field.name}".',
      element: element,
    );
  }

  String _pathParamWireName(FormalParameterElement parameter) {
    final annotation = _pathParamChecker.firstAnnotationOfExact(parameter);
    if (annotation == null) {
      return parameter.displayName;
    }

    final reader = ConstantReader(annotation);
    return reader.peek('name')?.stringValue ?? parameter.displayName;
  }

  String _queryParamWireName(FormalParameterElement parameter) {
    final annotation = _queryParamChecker.firstAnnotationOfExact(parameter);
    if (annotation == null) {
      return parameter.displayName;
    }

    final reader = ConstantReader(annotation);
    return reader.peek('name')?.stringValue ?? parameter.displayName;
  }

  bool _isSupportedRestScalarType(String typeCode) {
    return switch (_nonNullableTypeCode(typeCode)) {
      'String' || 'int' || 'double' || 'bool' => true,
      _ => false,
    };
  }

  bool _usesJsonObjectBodyDecode(String typeCode) {
    return typeCode == 'JsonObject' || typeCode.startsWith('Map<');
  }

  String _nonNullableTypeCode(String typeCode) {
    if (typeCode.endsWith('?')) {
      return typeCode.substring(0, typeCode.length - 1);
    }

    return typeCode;
  }

  _ResolvedInstantiation? _tryBuildInstantiation(
    InterfaceElement element, {
    required Map<String, String> availableProviders,
    required Set<String> usedNames,
  }) {
    final constructor = _selectUnnamedConstructor(element);
    final positionalArguments = <String>[];
    final namedArguments = <String>[];

    for (final parameter in constructor.formalParameters) {
      final dependency = availableProviders[_typeKeyFor(parameter.type)];
      if (dependency == null) {
        return null;
      }

      if (parameter.isNamed) {
        namedArguments.add('${parameter.name}: $dependency');
      } else {
        positionalArguments.add(dependency);
      }
    }

    final variableName = _uniqueName(
      _lowerCamel(element.displayName),
      usedNames,
    );
    final allArguments = [...positionalArguments, ...namedArguments].join(', ');

    return _ResolvedInstantiation(
      typeKey: _typeKeyFor(element.thisType),
      variableName: variableName,
      code: 'final $variableName = ${element.displayName}($allArguments);',
    );
  }

  ConstructorElement _selectUnnamedConstructor(InterfaceElement element) {
    final constructors = element.constructors
        .where((constructor) => !constructor.isFactory)
        .toList(growable: false);
    if (constructors.isEmpty) {
      throw InvalidGenerationSourceError(
        'Type "${element.displayName}" must declare an unnamed constructor.',
        element: element,
      );
    }

    final unnamedConstructors = constructors
        .where((constructor) {
          final name = constructor.name ?? '';
          return name.isEmpty || name == 'new';
        })
        .toList(growable: false);

    if (unnamedConstructors.length != 1) {
      throw InvalidGenerationSourceError(
        'Type "${element.displayName}" must declare exactly one unnamed constructor.',
        element: element,
      );
    }

    return unnamedConstructors.single;
  }

  DartType _unwrapFuture(DartType type) {
    if (type is InterfaceType &&
        type.element.name == 'Future' &&
        type.typeArguments.length == 1) {
      return type.typeArguments.single;
    }

    return type;
  }

  bool _isRpcContext(DartType type) => _rpcContextChecker.isExactlyType(type);

  bool _usesLuthorValidation(DartType type) {
    final element = type.element;
    if (element is! InterfaceElement) {
      return false;
    }

    return _luthorChecker.hasAnnotationOfExact(element);
  }

  String _rootClientNameFor(String moduleName) {
    if (moduleName.endsWith('Module') && moduleName.length > 'Module'.length) {
      return '${moduleName.substring(0, moduleName.length - 'Module'.length)}Client';
    }

    return '${moduleName}Client';
  }

  String _openApiTitleFor(String moduleName) {
    if (moduleName.endsWith('Module') && moduleName.length > 'Module'.length) {
      return '${moduleName.substring(0, moduleName.length - 'Module'.length)} API';
    }

    return '$moduleName API';
  }

  List<_ResolvedOpenApiSchemaComponent> _collectOpenApiSchemaComponents(
    List<_ControllerBinding> controllerBindings,
  ) {
    final components = <String, _ResolvedOpenApiSchemaComponent>{};

    void addComponent(String? typeName) {
      if (typeName == null || components.containsKey(typeName)) {
        return;
      }

      components[typeName] = _ResolvedOpenApiSchemaComponent(
        name: typeName,
        validatorExpression: '\$${typeName}Schema',
      );
    }

    for (final controller in controllerBindings) {
      for (final procedure in controller.procedures) {
        if (procedure.path == null) {
          continue;
        }

        if (procedure.outputUsesLuthor) {
          addComponent(procedure.outputTypeName);
        }

        if (procedure.inputUsesLuthor) {
          addComponent(procedure.inputTypeName);
        }

        for (final parameter in procedure.restInvocationParameters) {
          if (parameter.source != _InvocationParameterSourceKind.body ||
              !parameter.usesLuthor) {
            continue;
          }

          addComponent(parameter.typeName);
        }
      }
    }

    return components.values.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
  }

  String _clientClassNameFor(String controllerName) {
    if (controllerName.endsWith('Controller') &&
        controllerName.length > 'Controller'.length) {
      return '${controllerName.substring(0, controllerName.length - 'Controller'.length)}Client';
    }

    return '${controllerName}Client';
  }

  String _clientGetterNameFor(String namespace) {
    final candidate = namespace
        .split(RegExp(r'[./]'))
        .where((segment) => segment.isNotEmpty)
        .last;
    final sanitized = candidate.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    final prefixed = RegExp(r'^[A-Za-z_]').hasMatch(sanitized)
        ? sanitized
        : 'rpc_$sanitized';
    return _lowerCamel(prefixed);
  }

  String _uniqueName(String candidate, Set<String> usedNames) {
    var name = candidate;
    var suffix = 2;
    while (!usedNames.add(name)) {
      name = '$candidate$suffix';
      suffix += 1;
    }
    return name;
  }

  String _lowerCamel(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toLowerCase()}${value.substring(1)}';
  }

  String _typeKeyFor(DartType type) => type.getDisplayString();
}

final class _ResolvedInstantiation {
  const _ResolvedInstantiation({
    required this.typeKey,
    required this.variableName,
    required this.code,
  });

  final String typeKey;
  final String variableName;
  final String code;
}

final class _ControllerBinding {
  const _ControllerBinding({
    required this.instanceName,
    required this.instantiationCode,
    required this.clientClassName,
    required this.clientGetterName,
    required this.procedures,
  });

  final String instanceName;
  final String instantiationCode;
  final String clientClassName;
  final String clientGetterName;
  final List<_ResolvedProcedure> procedures;

  List<_ResolvedProcedure> get rpcCompatibleProcedures => procedures
      .where((procedure) => procedure.supportsRpcGeneration)
      .toList(growable: false);
}

final class _ResolvedProcedure {
  const _ResolvedProcedure({
    required this.controllerNamespace,
    required this.methodName,
    required this.rpcMethod,
    required this.parameters,
    required this.restInvocationParameters,
    this.restRpcInput,
    required this.hasInput,
    this.path,
    this.inputTypeCode,
    this.inputTypeName,
    this.inputParameterName,
    this.description,
    this.tags = const [],
    required this.inputUsesLuthor,
    required this.outputTypeCode,
    required this.outputTypeName,
    required this.outputUsesLuthor,
    required this.supportsRpcGeneration,
    required this.serverInvocationArguments,
  });

  final String controllerNamespace;
  final String methodName;
  final String rpcMethod;
  final _ResolvedPathMapping? path;
  final List<_ResolvedParameter> parameters;
  final List<_ResolvedInvocationParameter> restInvocationParameters;
  final _ResolvedRestRpcInput? restRpcInput;
  final bool hasInput;
  final String? inputTypeCode;
  final String? inputTypeName;
  final String? inputParameterName;
  final String? description;
  final List<String> tags;
  final bool inputUsesLuthor;
  final String outputTypeCode;
  final String outputTypeName;
  final bool outputUsesLuthor;
  final bool supportsRpcGeneration;
  final String serverInvocationArguments;
}

final class _ResolvedParameter {
  const _ResolvedParameter({
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

enum _InvocationParameterSourceKind {
  context,
  rpcInput,
  path,
  query,
  header,
  body,
}

enum _ResolvedRestRpcInputMode { query, body }

final class _ResolvedInvocationParameter {
  const _ResolvedInvocationParameter({
    required this.parameterName,
    required this.source,
    required this.typeCode,
    required this.wireName,
    required this.typeName,
    required this.usesLuthor,
  });

  final String parameterName;
  final _InvocationParameterSourceKind source;
  final String typeCode;
  final String? wireName;
  final String? typeName;
  final bool usesLuthor;
}

final class _ResolvedDtoField {
  const _ResolvedDtoField({
    required this.name,
    required this.typeCode,
    this.defaultSource,
    this.defaultWireName,
  });

  final String name;
  final String typeCode;
  final String? defaultSource;
  final String? defaultWireName;
}

final class _ResolvedDtoFieldBinding {
  const _ResolvedDtoFieldBinding({required this.source, this.wireName});

  final String source;
  final String? wireName;
}

final class _ResolvedDtoFieldBuilder {
  _ResolvedDtoFieldBuilder({required this.name, required this.typeCode});

  final String name;
  final String typeCode;
  String? defaultSource;
  String? defaultWireName;

  void applyBinding(
    _ResolvedDtoFieldBinding binding, {
    required String methodName,
    required Element element,
  }) {
    final nextWireName = binding.wireName ?? name;
    if (defaultSource != null) {
      if (defaultSource != binding.source || defaultWireName != nextWireName) {
        throw InvalidGenerationSourceError(
          'REST-enabled RPC method "$methodName" found conflicting source annotations for DTO field "$name".',
          element: element,
        );
      }
      return;
    }

    defaultSource = binding.source;
    defaultWireName = nextWireName;
  }

  _ResolvedDtoField build() {
    return _ResolvedDtoField(
      name: name,
      typeCode: typeCode,
      defaultSource: defaultSource,
      defaultWireName: defaultWireName,
    );
  }
}

final class _ResolvedRestInputField {
  const _ResolvedRestInputField({
    required this.name,
    required this.typeCode,
    required this.wireName,
  });

  final String name;
  final String typeCode;
  final String wireName;
}

final class _ResolvedRpcInputField {
  const _ResolvedRpcInputField({
    required this.fieldName,
    required this.wireName,
    required this.source,
  });

  final String fieldName;
  final String wireName;
  final String source;
}

final class _ResolvedRpcInputDetails {
  const _ResolvedRpcInputDetails({
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final List<_ResolvedRpcInputField> path;
  final List<_ResolvedRpcInputField> query;
  final List<_ResolvedRpcInputField> headers;
  final List<_ResolvedRpcInputField> body;
}

final class _ResolvedRestRpcInput {
  const _ResolvedRestRpcInput({
    required this.parameterName,
    required this.mode,
    required this.pathFields,
    required this.queryFields,
    required this.headerFields,
    required this.bodyFields,
    required this.metadataParameters,
  });

  final String parameterName;
  final _ResolvedRestRpcInputMode mode;
  final List<_ResolvedRestInputField> pathFields;
  final List<_ResolvedRestInputField> queryFields;
  final List<_ResolvedRestInputField> headerFields;
  final List<_ResolvedRestInputField> bodyFields;
  final List<_ResolvedParameter> metadataParameters;
}

final class _ResolvedPathMapping {
  const _ResolvedPathMapping({required this.method, required this.path});

  final String method;
  final String path;
}

final class _ResolvedOpenApiSchemaComponent {
  const _ResolvedOpenApiSchemaComponent({
    required this.name,
    required this.validatorExpression,
  });

  final String name;
  final String validatorExpression;
}
