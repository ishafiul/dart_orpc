// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_mirrors.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoMirrorsTest);
  });
}

@reflectiveTest
class NoMirrorsTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoMirrors();
    super.setUp();
  }

  Future<void> test_reports_mirrors_import() async {
    const content = '''
// ignore: unused_import -- the import itself is what this test checks
import 'dart:mirrors';
''';
    await assertDiagnostics(content, [
      lintOn(content, "'dart:mirrors'"),
      missingMockLibraryOn(content, "'dart:mirrors'"),
    ]);
  }

  Future<void> test_allows_other_imports() async {
    await assertNoDiagnostics('''
import 'dart:math';

int f() => max(1, 2);
''');
  }
}
