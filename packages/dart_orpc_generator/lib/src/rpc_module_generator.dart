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
    final buildAppName = '_\$build${moduleName}RpcApp';

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

        for (final parameter in procedure.restInvocationParameters) {
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
      ..writeln('RpcHttpApp $buildAppName() {')
      ..writeln(
        '  return RpcHttpApp(procedures: $createRegistryName(), restRoutes: $createRestRouteRegistryName());',
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

    if (path != null &&
        rpcInputParameters.isNotEmpty &&
        !hasRestSourceParameters) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" does not yet support @RpcInput; use explicit @PathParam, @QueryParam, and @Body parameters.',
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

    if (path != null) {
      _validateRestPathBindings(
        path.path,
        pathParameters,
        methodName: methodName,
      );
    }

    final inputParameter = rpcInputParameters.isEmpty
        ? null
        : rpcInputParameters.single;
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
        parameters.add(
          _ResolvedParameter(
            parameterName: parameter.displayName,
            wireName: parameter.displayName,
            source: ProcedureParameterSourceKind.rpcInput,
            typeCode: parameter.type.getDisplayString(),
          ),
        );
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

enum _InvocationParameterSourceKind { context, rpcInput, path, query, body }

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

final class _ResolvedPathMapping {
  const _ResolvedPathMapping({required this.method, required this.path});

  final String method;
  final String path;
}
