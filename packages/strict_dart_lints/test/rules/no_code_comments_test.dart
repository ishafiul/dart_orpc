// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_code_comments.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoCodeCommentsTest);
  });
}

@reflectiveTest
class NoCodeCommentsTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoCodeComments();
    super.setUp();
  }

  Future<void> test_reports_line_comment() async {
    const content = '''
int f() {
  // explains why
  return 1;
}
''';
    await assertDiagnostics(content, [lintOn(content, '// explains why')]);
  }

  Future<void> test_reports_block_comment() async {
    const content = '''
int f(int a) => a /* trust me */ + 1;
''';
    await assertDiagnostics(content, [lintOn(content, '/* trust me */')]);
  }

  Future<void> test_reports_commented_out_code() async {
    const content = '''
int f() {
  // return 2;
  return 1;
}
''';
    await assertDiagnostics(content, [lintOn(content, '// return 2;')]);
  }

  Future<void> test_reports_todo_without_issue() async {
    const content = '''
// TODO: fix later
int f() => 1;
''';
    await assertDiagnostics(content, [
      lintOn(content, '// TODO: fix later'),
      analyzerTodoOn(content, 'TODO: fix later'),
    ]);
  }

  Future<void> test_allows_doc_comments() async {
    await assertNoDiagnostics('''
/// Doc comments are handled by no_doc_comments.
int f() => 1;
''');
  }

  Future<void> test_allows_machine_read_markers() async {
    const content = '''
// TODO(#123) replace with the typed client
// coverage:ignore-line
// ignore: unused_element -- kept for the generated client to reference
int _f() => 1;
int g() => _f();
''';
    await assertDiagnostics(content, [
      analyzerTodoOn(content, 'TODO(#123) replace with the typed client'),
    ]);
  }

  Future<void> test_skips_generated_files() async {
    await assertNoDiagnostics('''
// GENERATED CODE - DO NOT MODIFY BY HAND
// a generator wrote this
int f() => 1;
''');
  }
}
