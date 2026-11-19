// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/throw_framework_errors.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../orpc_rule_harness.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ThrowFrameworkErrorsTest);
  });
}

@reflectiveTest
class ThrowFrameworkErrorsTest extends OrpcRuleTest {
  @override
  void setUp() {
    rule = ThrowFrameworkErrors();
    super.setUp();
  }

  Future<void> test_reports_custom_exception() async {
    const content = '''
class PaymentDeclined implements Exception {
  const PaymentDeclined();
}

void charge() => throw const PaymentDeclined();
''';
    await assertDiagnostics(content, [
      lint(content.lastIndexOf('const PaymentDeclined()'), 23),
    ]);
  }

  Future<void> test_reports_thrown_string() async {
    const content = '''
void charge() => throw 'declined';
''';
    await assertDiagnostics(content, [lintOn(content, "'declined'")]);
  }

  Future<void> test_reports_rethrowing_a_caught_object() async {
    const content = '''
void charge(void Function() pay) {
  try {
    pay();
  } on Object catch (error) {
    throw error;
  }
}
''';
    await assertDiagnostics(content, [lintOn(content, 'error;', length: 5)]);
  }

  Future<void> test_allows_rpc_exception() async {
    await assertNoDiagnostics('''
import 'package:dart_orpc_core/dart_orpc_core.dart';

void find() => throw RpcException.notFound('missing');
''');
  }

  Future<void> test_allows_error_subtypes() async {
    await assertNoDiagnostics('''
class BrokenInvariant extends Error {}

void check() => throw BrokenInvariant();
''');
  }

  Future<void> test_allows_rethrow() async {
    await assertNoDiagnostics('''
void charge(void Function() pay) {
  try {
    pay();
  } on Object {
    rethrow;
  }
}
''');
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
void fail() => throw 'boom';
''');
    await assertNoDiagnosticsInFile(path);
  }
}
