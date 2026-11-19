// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/controller_no_logic.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../orpc_rule_harness.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ControllerNoLogicTest);
  });
}

@reflectiveTest
class ControllerNoLogicTest extends OrpcRuleTest {
  @override
  void setUp() {
    rule = ControllerNoLogic();
    super.setUp();
  }

  Future<void> test_reports_loops_and_try_in_controller() async {
    const content = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

@Controller('todo')
final class TodoController {
  int total(List<int> values) {
    var sum = 0;
    for (final value in values) {
      sum += value;
    }
    while (sum > 100) {
      sum -= 100;
    }
    do {
      sum += 1;
    } while (sum < 0);
    try {
      return sum;
    } finally {
      sum = 0;
    }
  }

  List<int> doubled(List<int> values) => [for (final value in values) value * 2];
}
''';
    await assertDiagnostics(content, [
      lintOn(content, 'for (final value in values) {', length: 3),
      lintOn(content, 'while (sum > 100)', length: 5),
      lintOn(content, 'do {', length: 2),
      lintOn(content, 'try {', length: 3),
      lintOn(content, 'for (final value in values) value', length: 3),
    ]);
  }

  Future<void> test_allows_delegating_controller() async {
    await assertNoDiagnostics('''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

class TodoService {
  int count() => 1;
}

@Controller('todo')
final class TodoController {
  TodoController(this.service);

  final TodoService service;

  int count() => service.count();
}
''');
  }

  Future<void> test_allows_loops_outside_controllers() async {
    await assertNoDiagnostics('''
class TodoService {
  int total(List<int> values) {
    var sum = 0;
    for (final value in values) {
      sum += value;
    }
    return sum;
  }
}
''');
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

@Controller('fake')
final class FakeController {
  int total(List<int> values) {
    var sum = 0;
    for (final value in values) {
      sum += value;
    }
    return sum;
  }
}
''');
    await assertNoDiagnosticsInFile(path);
  }
}
