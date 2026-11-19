// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_hardcoded_strings.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoHardcodedStringsTest);
  });
}

@reflectiveTest
class NoHardcodedStringsTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoHardcodedStrings();
    super.setUp();
  }

  Future<void> test_reports_literal_in_expression() async {
    const content = '''
String f() => 'user not found'.toUpperCase();
''';
    await assertDiagnostics(content, [lintOn(content, "'user not found'")]);
  }

  Future<void> test_reports_interpolation_with_text() async {
    const content = r'''
String f(int id) => 'user $id not found'.toUpperCase();
''';
    await assertDiagnostics(content, [
      lintOn(content, r"'user $id not found'"),
    ]);
  }

  Future<void> test_reports_literal_in_final_variable() async {
    const content = '''
final message = 'user not found';
''';
    await assertDiagnostics(content, [lintOn(content, "'user not found'")]);
  }

  Future<void> test_allows_const_declarations() async {
    await assertNoDiagnostics('''
const userNotFound = 'user not found';

class Messages {
  static const missing = 'missing';
}

String f() => userNotFound;
''');
  }

  Future<void> test_allows_const_constructor_arguments() async {
    await assertNoDiagnostics('''
class Route {
  const Route(this.path);

  final String path;
}

Route f() => const Route('/users');
''');
  }

  Future<void> test_allows_annotations_and_directives() async {
    await assertNoDiagnostics('''
import 'dart:math';

class Controller {
  const Controller(this.path);

  final String path;
}

@Controller('users')
class UsersController {}

int f() => max(1, 2);
''');
  }

  Future<void> test_allows_patterns_and_default_values() async {
    await assertNoDiagnostics('''
const fallback = 0;

int f(String value, {String mode = 'strict'}) => switch (value) {
  'admin' => 1,
  _ => fallback,
};
''');
  }

  Future<void> test_allows_empty_and_interpolation_only_strings() async {
    await assertNoDiagnostics(r'''
String f(int a, int b) => '$a$b';

String g() => '';
''');
  }

  Future<void> test_allows_named_message_builders() async {
    await assertNoDiagnostics(r'''
String todoNotFound(int id) => 'Todo $id was not found.';

String metadataError(String field) =>
    'Field "$field" must be ' 'a list of strings.';

class Messages {
  String greeting(String name) => 'Hello $name';

  String get title => 'Todos';
}
''');
  }

  Future<void> test_reports_strings_inside_builder_expressions() async {
    const content = r'''
String describe(int id) => format('Todo $id');

String format(String text) => text;
''';
    await assertDiagnostics(content, [lintOn(content, r"'Todo $id'")]);
  }

  Future<void> test_reports_strings_in_block_bodies() async {
    const content = r'''
String describe(int id) {
  return 'Todo $id';
}
''';
    await assertDiagnostics(content, [lintOn(content, r"'Todo $id'")]);
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
String f() => 'user not found';
''');
    await assertNoDiagnosticsInFile(path);
  }
}
