// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_unchecked_cast.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoUncheckedCastTest);
  });
}

@reflectiveTest
class NoUncheckedCastTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoUncheckedCast();
    super.setUp();
  }

  Future<void> test_reports_downcast() async {
    const content = '''
int f(Object value) => value as int;
''';
    await assertDiagnostics(content, [lintOn(content, 'as int', length: 2)]);
  }

  Future<void> test_reports_cast_from_dynamic() async {
    const content = '''
int f(dynamic value) => value as int;
''';
    await assertDiagnostics(content, [lintOn(content, 'as int', length: 2)]);
  }

  Future<void> test_reports_nullable_to_non_nullable_cast() async {
    const content = '''
int f(int? value) => value as int;
''';
    await assertDiagnostics(content, [lintOn(content, 'as int', length: 2)]);
  }

  Future<void> test_reports_cast_pattern() async {
    const content = '''
int f(Object value) {
  final (known as int) = value;
  return known;
}
''';
    await assertDiagnostics(content, [lintOn(content, 'as int', length: 2)]);
  }

  Future<void> test_allows_type_test_pattern() async {
    await assertNoDiagnostics('''
int f(Object value) => switch (value) {
  final int known => known,
  _ => 0,
};
''');
  }

  Future<void> test_allows_import_prefix() async {
    await assertNoDiagnostics('''
import 'dart:math' as math;

int f() => math.max(1, 2);
''');
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
int f(Object value) => value as int;
''');
    await assertNoDiagnosticsInFile(path);
  }
}
