// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_doc_comments.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoDocCommentsTest);
  });
}

@reflectiveTest
class NoDocCommentsTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoDocComments();
    super.setUp();
  }

  Future<void> test_reports_line_doc_comment() async {
    const content = '''
/// Returns one.
int f() => 1;
''';
    await assertDiagnostics(content, [lintOn(content, '/// Returns one.')]);
  }

  Future<void> test_reports_block_doc_comment() async {
    const content = '''
/** Returns one. */
int f() => 1;
''';
    await assertDiagnostics(content, [lintOn(content, '/** Returns one. */')]);
  }

  Future<void> test_allows_declarations_without_docs() async {
    await assertNoDiagnostics('''
int one() => 1;
''');
  }
}
