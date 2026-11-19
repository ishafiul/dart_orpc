import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart';

const _annotationsStub = '''
final class Module {
  const Module({
    this.imports = const [],
    this.controllers = const [],
    this.providers = const [],
    this.exports = const [],
    this.global = false,
  });

  final List<Type> imports;
  final List<Type> controllers;
  final List<Type> providers;
  final List<Type> exports;
  final bool global;
}

final class Controller {
  const Controller(this.namespace);

  final String namespace;
}
''';

const _coreStub = '''
final class RpcException implements Exception {
  const RpcException(this.message);

  factory RpcException.notFound(String message) => RpcException(message);

  final String message;
}
''';

const _rustHttpStub = '''
abstract class HttpServer {
  static HttpServer? bind(int port) => null;
}
''';

abstract class OrpcRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('dart_orpc_annotations').addFile(
      'lib/dart_orpc_annotations.dart',
      _annotationsStub,
    );
    newPackage('dart_orpc_core').addFile('lib/dart_orpc_core.dart', _coreStub);
    newPackage('rust_http').addFile('lib/rust_http.dart', _rustHttpStub);
    super.setUp();
  }

  ExpectedDiagnostic lintOn(String content, String target, {int? length}) =>
      lint(content.indexOf(target), length ?? target.length);

  String writeLibFile(String relativePath, String content) => newFile(
    convertPath('$testPackageRootPath/lib/$relativePath'),
    content,
  ).path;

  String writeTestDirectoryFile(String content) => newFile(
    convertPath('$testPackageRootPath/test/sample_test.dart'),
    content,
  ).path;
}
