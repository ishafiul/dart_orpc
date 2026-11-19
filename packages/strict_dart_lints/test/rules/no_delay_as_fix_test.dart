// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_delay_as_fix.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoDelayAsFixTest);
  });
}

@reflectiveTest
class NoDelayAsFixTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoDelayAsFix();
    super.setUp();
  }

  Future<void> test_reports_future_delayed() async {
    const content = '''
Future<void> f() => Future<void>.delayed(Duration.zero);
''';
    await assertDiagnostics(content, [
      lintOn(content, 'Future<void>.delayed'),
    ]);
  }

  Future<void> test_reports_in_tests_too() async {
    const content = '''
Future<void> f() => Future<void>.delayed(Duration.zero);
''';
    final path = writeTestDirectoryFile(content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'Future<void>.delayed'),
    ]);
  }

  Future<void> test_allows_other_future_constructors() async {
    await assertNoDiagnostics('''
Future<int> f() => Future<int>.value(1);
''');
  }

  Future<void> test_allows_user_functions_named_sleep() async {
    await assertNoDiagnostics('''
void sleep(Duration duration) {}

void f() => sleep(Duration.zero);
''');
  }
}
