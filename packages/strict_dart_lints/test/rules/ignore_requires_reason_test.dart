// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/ignore_requires_reason.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(IgnoreRequiresReasonTest);
  });
}

@reflectiveTest
class IgnoreRequiresReasonTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = IgnoreRequiresReason();
    super.setUp();
  }

  Future<void> test_reports_ignore_without_reason() async {
    const content = '''
// ignore: unused_element
int _f() => 1;
''';
    await assertDiagnostics(content, [
      lintOn(content, '// ignore: unused_element'),
    ]);
  }

  Future<void> test_reports_ignore_for_file_without_reason() async {
    const content = '''
// ignore_for_file: unused_element
int _f() => 1;
''';
    await assertDiagnostics(content, [
      lintOn(content, '// ignore_for_file: unused_element'),
    ]);
  }

  Future<void> test_reports_reason_that_is_too_short() async {
    const content = '''
// ignore: unused_element -- ok
int _f() => 1;
''';
    await assertDiagnostics(content, [
      lintOn(content, '// ignore: unused_element -- ok'),
    ]);
  }

  Future<void> test_allows_ignore_with_reason() async {
    await assertNoDiagnostics('''
// ignore: unused_element -- referenced by the generated registry only
int _f() => 1;
''');
  }

  Future<void> test_allows_plugin_codes_with_reason() async {
    await assertNoDiagnostics('''
// ignore: strict_dart_lints/no_null_assertion, unused_element -- value is set by the native bridge
int _f() => 1;
''');
  }
}
