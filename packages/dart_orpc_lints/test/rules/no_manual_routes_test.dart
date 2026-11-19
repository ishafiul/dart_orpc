// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/no_manual_routes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../orpc_rule_harness.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoManualRoutesTest);
  });
}

@reflectiveTest
class NoManualRoutesTest extends OrpcRuleTest {
  @override
  void setUp() {
    rule = NoManualRoutes();
    super.setUp();
  }

  Future<void> test_reports_static_bind_call() async {
    const content = '''
import 'package:rust_http/rust_http.dart';

void serve() => HttpServer.bind(8080);
''';
    await assertDiagnostics(content, [
      lintOn(content, 'HttpServer.', length: 10),
    ]);
  }

  Future<void> test_reports_type_annotation() async {
    const content = '''
import 'package:rust_http/rust_http.dart';

HttpServer? server() => null;
''';
    await assertDiagnostics(content, [
      lintOn(content, 'HttpServer?'),
    ]);
  }

  Future<void> test_allows_other_classes_named_http_server() async {
    await assertNoDiagnostics('''
class HttpServer {}

HttpServer server() => HttpServer();
''');
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
import 'package:rust_http/rust_http.dart';

HttpServer? server() => null;
''');
    await assertNoDiagnosticsInFile(path);
  }
}
