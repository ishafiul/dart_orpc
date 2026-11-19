// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_late_without_initializer.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoLateWithoutInitializerTest);
  });
}

@reflectiveTest
class NoLateWithoutInitializerTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoLateWithoutInitializer();
    super.setUp();
  }

  Future<void> test_reports_late_field() async {
    const content = '''
class Service {
  late int count;
}
''';
    await assertDiagnostics(content, [lintOn(content, 'count')]);
  }

  Future<void> test_reports_late_final_local() async {
    const content = '''
int f() {
  late final int value;
  value = 1;
  return value;
}
''';
    await assertDiagnostics(content, [lintOn(content, 'value')]);
  }

  Future<void> test_allows_lazy_initializer() async {
    await assertNoDiagnostics('''
int computeCount() => 1;

class Service {
  late final int count = computeCount();
}
''');
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
class Fixture {
  late int count;
}
''');
    await assertNoDiagnosticsInFile(path);
  }
}
