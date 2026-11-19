// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_null_assertion.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoNullAssertionTest);
  });
}

@reflectiveTest
class NoNullAssertionTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoNullAssertion();
    super.setUp();
  }

  Future<void> test_reports_postfix_bang() async {
    const content = '''
int f(int? value) => value!;
''';
    await assertDiagnostics(content, [lintOn(content, '!')]);
  }

  Future<void> test_reports_null_assert_pattern() async {
    const content = '''
int f((int?,) record) {
  final (known!,) = record;
  return known;
}
''';
    await assertDiagnostics(content, [lintOn(content, '!')]);
  }

  Future<void> test_allows_explicit_null_handling() async {
    await assertNoDiagnostics('''
int f(int? value) => value ?? 0;
''');
  }

  Future<void> test_allows_not_operator() async {
    await assertNoDiagnostics('''
bool f(bool value) => !value;
''');
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
int f(int? value) => value!;
''');
    await assertNoDiagnosticsInFile(path);
  }
}
