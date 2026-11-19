// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_global_mutable_state.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoGlobalMutableStateTest);
  });
}

@reflectiveTest
class NoGlobalMutableStateTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoGlobalMutableState();
    super.setUp();
  }

  Future<void> test_reports_mutable_top_level_variable() async {
    const content = '''
int requestCount = 0;
''';
    await assertDiagnostics(content, [lintOn(content, 'requestCount')]);
  }

  Future<void> test_reports_mutable_static_field() async {
    const content = '''
class Cache {
  static Map<String, int> entries = {};
}
''';
    await assertDiagnostics(content, [lintOn(content, 'entries')]);
  }

  Future<void> test_allows_final_const_and_instance_state() async {
    await assertNoDiagnostics('''
const limit = 10;
final startedAt = DateTime.now();

class Counter {
  static const step = 1;
  static final created = DateTime.now();

  int value = 0;
}
''');
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
int calls = 0;
''');
    await assertNoDiagnosticsInFile(path);
  }
}
