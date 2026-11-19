// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:strict_dart_lints/src/rules/no_broad_catch.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoBroadCatchTest);
  });
}

@reflectiveTest
class NoBroadCatchTest extends AnalysisRuleTest with LintLocator {
  @override
  void setUp() {
    rule = NoBroadCatch();
    super.setUp();
  }

  Future<void> test_reports_catch_all() async {
    const content = '''
int? f(int Function() read) {
  try {
    return read();
  } catch (error) {
    return null;
  }
}
''';
    await assertDiagnostics(content, [lintOn(content, 'catch')]);
  }

  Future<void> test_reports_on_object() async {
    const content = '''
int? f(int Function() read) {
  try {
    return read();
  } on Object catch (error) {
    print(error);
    return null;
  }
}
''';
    await assertDiagnostics(content, [
      lintOn(content, 'on Object', length: 2),
    ]);
  }

  Future<void> test_reports_on_exception() async {
    const content = '''
int? f(int Function() read) {
  try {
    return read();
  } on Exception {
    return null;
  }
}
''';
    await assertDiagnostics(content, [
      lintOn(content, 'on Exception', length: 2),
    ]);
  }

  Future<void> test_reports_throw_only_inside_closure() async {
    const content = '''
class ReadFailure implements Exception {
  const ReadFailure();
}

int? f(int Function() read, void Function(void Function()) later) {
  try {
    return read();
  } catch (error) {
    later(() => throw const ReadFailure());
    return null;
  }
}
''';
    await assertDiagnostics(content, [lintOn(content, 'catch')]);
  }

  Future<void> test_allows_broad_catch_that_rethrows() async {
    await assertNoDiagnostics('''
int f(int Function() read, void Function(Object) log) {
  try {
    return read();
  } catch (error) {
    log(error);
    rethrow;
  }
}
''');
  }

  Future<void> test_allows_broad_catch_that_throws_typed_error() async {
    await assertNoDiagnostics('''
class ReadFailure implements Exception {
  const ReadFailure(this.cause);

  final Object cause;
}

int f(int Function() read) {
  try {
    return read();
  } on Object catch (error) {
    throw ReadFailure(error);
  }
}
''');
  }

  Future<void> test_allows_specific_catch() async {
    await assertNoDiagnostics('''
int? f(String input) {
  try {
    return int.parse(input);
  } on FormatException {
    return null;
  }
}
''');
  }
}
