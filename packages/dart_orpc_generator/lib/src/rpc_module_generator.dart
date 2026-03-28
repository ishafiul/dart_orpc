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

    final rootClientName = _rootClientNameFor(moduleName);
    final createRegistryName = '_\$create${moduleName}ProcedureRegistry';
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
      for (final method in controller.methods) {
        final inputTypeCode = method.inputTypeCode ?? 'Null';
        buffer
          ..writeln(
            '    RpcProcedure<$inputTypeCode, ${method.outputTypeCode}>(',
          )
          ..writeln("      method: '${method.rpcMethod}',")
          ..writeln('      decodeInput: ${_decodeInputExpression(method)},')
          ..writeln('      encodeOutput: ${_encodeOutputExpression(method)},')
          ..writeln(
            '      handler: (context, input) => ${controller.instanceName}.${method.methodName}(${method.serverInvocationArguments}),',
          )
          ..writeln('    ),');
      }
    }

    buffer
      ..writeln('  ]);')
      ..writeln('}')
      ..writeln()
      ..writeln('RpcHttpApp $buildAppName() {')
      ..writeln('  return RpcHttpApp(procedures: $createRegistryName());')
      ..writeln('}')
      ..writeln()
      ..writeln('class $rootClientName {')
      ..writeln(
        '  $rootClientName({required RpcTransport transport}) : _caller = RpcCaller(transport);',
      )
      ..writeln()
      ..writeln('  final RpcCaller _caller;');

    if (controllerBindings.isNotEmpty) {
      buffer.writeln();
      for (final controller in controllerBindings) {
        buffer.writeln(
          '  late final ${controller.clientClassName} ${controller.clientGetterName} = ${controller.clientClassName}(_caller);',
        );
      }
    }

    buffer.writeln('}');

    for (final controller in controllerBindings) {
      buffer
        ..writeln()
        ..writeln('class ${controller.clientClassName} {')
        ..writeln('  ${controller.clientClassName}(this._caller);')
        ..writeln()
        ..writeln('  final RpcCaller _caller;');

      for (final method in controller.methods) {
        if (method.hasInput) {
          buffer
            ..writeln()
            ..writeln(
              '  Future<${method.outputTypeCode}> ${method.methodName}(${method.inputTypeCode!} ${method.inputParameterName!}) {',
            )
            ..writeln('    return _caller.call<${method.outputTypeCode}>(')
            ..writeln("      method: '${method.rpcMethod}',")
            ..writeln('      input: ${method.inputParameterName!}.toJson(),')
            ..writeln(
              '      decode: (json) => ${method.outputTypeCode}.fromJson(Map<String, dynamic>.from(expectJsonObject(json, context: \'RPC response for "${method.rpcMethod}"\'))),',
            )
            ..writeln('    );')
            ..writeln('  }');
          continue;
        }

        buffer
          ..writeln()
          ..writeln(
            '  Future<${method.outputTypeCode}> ${method.methodName}() {',
          )
          ..writeln('    return _caller.call<${method.outputTypeCode}>(')
          ..writeln("      method: '${method.rpcMethod}',")
          ..writeln(
            '      decode: (json) => ${method.outputTypeCode}.fromJson(Map<String, dynamic>.from(expectJsonObject(json, context: \'RPC response for "${method.rpcMethod}"\'))),',
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

    final methods = controllerElement.methods
        .where((method) => _rpcMethodChecker.hasAnnotationOfExact(method))
        .map((method) => _buildMethodBinding(namespace, method))
        .toList(growable: false);

    if (methods.isEmpty) {
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
      methods: methods,
    );
  }

  _ResolvedMethod _buildMethodBinding(String namespace, MethodElement method) {
    final methodAnnotation = _rpcMethodChecker.firstAnnotationOfExact(method);
    if (methodAnnotation == null) {
      throw InvalidGenerationSourceError(
        'RPC methods must be annotated with @RpcMethod.',
        element: method,
      );
    }

    final methodName = method.displayName;
    final inputParameters = method.formalParameters
        .where((parameter) => _rpcInputChecker.hasAnnotationOfExact(parameter))
        .toList(growable: false);

    if (inputParameters.length > 1) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" may declare at most one @RpcInput parameter.',
        element: method,
      );
    }

    final inputParameter = inputParameters.isEmpty
        ? null
        : inputParameters.single;
    final invocationArguments = <String>[];

    for (final parameter in method.formalParameters) {
      if (_rpcInputChecker.hasAnnotationOfExact(parameter)) {
        invocationArguments.add('input');
        continue;
      }

      if (_isRpcContext(parameter.type)) {
        invocationArguments.add('context');
        continue;
      }

      throw InvalidGenerationSourceError(
        'RPC method "$methodName" only supports an optional RpcContext and at most one @RpcInput parameter.',
        element: parameter,
      );
    }

    final outputType = _unwrapFuture(method.returnType);
    final wireName =
        ConstantReader(methodAnnotation).peek('name')?.stringValue ??
        methodName;

    return _ResolvedMethod(
      methodName: methodName,
      rpcMethod: '$namespace.$wireName',
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
      serverInvocationArguments: invocationArguments.join(', '),
    );
  }

  String _decodeInputExpression(_ResolvedMethod method) {
    if (method.hasInput) {
      if (method.inputUsesLuthor) {
        return '(rawInput) => decodeRpcInputWithLuthor<${method.inputTypeCode!}>(rawInput: rawInput, method: \'${method.rpcMethod}\', validate: \$${method.inputTypeName!}Validate)';
      }

      return '(rawInput) => ${method.inputTypeCode!}.fromJson(Map<String, dynamic>.from(expectJsonObject(rawInput, context: \'RPC method "${method.rpcMethod}" input\')))';
    }

    return '(rawInput) => expectNoRpcInput(rawInput, context: \'RPC method "${method.rpcMethod}"\')';
  }

  String _encodeOutputExpression(_ResolvedMethod method) {
    if (method.outputUsesLuthor) {
      return '(output) => encodeRpcOutputWithLuthor<${method.outputTypeCode}>(output: output, method: \'${method.rpcMethod}\', toJson: (output) => output.toJson(), validate: \$${method.outputTypeName}Validate)';
    }

    return '(output) => output.toJson()';
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
    required this.methods,
  });

  final String instanceName;
  final String instantiationCode;
  final String clientClassName;
  final String clientGetterName;
  final List<_ResolvedMethod> methods;
}

final class _ResolvedMethod {
  const _ResolvedMethod({
    required this.methodName,
    required this.rpcMethod,
    required this.hasInput,
    this.inputTypeCode,
    this.inputTypeName,
    this.inputParameterName,
    required this.inputUsesLuthor,
    required this.outputTypeCode,
    required this.outputTypeName,
    required this.outputUsesLuthor,
    required this.serverInvocationArguments,
  });

  final String methodName;
  final String rpcMethod;
  final bool hasInput;
  final String? inputTypeCode;
  final String? inputTypeName;
  final String? inputParameterName;
  final bool inputUsesLuthor;
  final String outputTypeCode;
  final String outputTypeName;
  final bool outputUsesLuthor;
  final String serverInvocationArguments;
}
