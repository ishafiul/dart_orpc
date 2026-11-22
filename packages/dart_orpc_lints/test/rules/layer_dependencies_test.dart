// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/layer_dependencies.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../orpc_rule_harness.dart';

const _layers = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

@Repository()
final class TodoRepository {}

@Service()
final class TodoService {
  TodoService(this.todos);

  final TodoRepository todos;
}

''';

String _withLayers(String body) => '$_layers$body';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(LayerDependenciesTest);
  });
}

@reflectiveTest
class LayerDependenciesTest extends OrpcRuleTest {
  @override
  void setUp() {
    rule = LayerDependencies();
    super.setUp();
  }

  Future<void> test_reports_controller_using_repository() async {
    final content = _withLayers('''
@Controller('todo')
final class TodoController {
  TodoController(this.todos);

  final TodoRepository todos;
}
''');
    await assertDiagnostics(content, [
      lint(content.lastIndexOf('TodoRepository todos'), 14),
    ]);
  }

  Future<void> test_reports_repository_using_service() async {
    final content = _withLayers('''
@Repository()
final class AuditRepository {
  AuditRepository(this.service);

  final TodoService service;
}
''');
    await assertDiagnostics(content, [
      lint(content.lastIndexOf('TodoService service'), 11),
    ]);
  }

  Future<void> test_reports_reference_inside_method_bodies() async {
    final content = _withLayers('''
@Controller('todo')
final class TodoController {
  int count(Object value) => value is TodoRepository ? 1 : 0;
}
''');
    await assertDiagnostics(content, [
      lint(content.lastIndexOf('TodoRepository'), 14),
    ]);
  }

  Future<void> test_allows_the_layer_order() async {
    await assertNoDiagnostics(
      _withLayers('''
@Controller('todo')
final class TodoController {
  TodoController(this.service);

  final TodoService service;

  TodoController copy() => TodoController(service);
}
'''),
    );
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile(
      _withLayers('''
@Controller('fake')
final class FakeController {
  FakeController(this.todos);

  final TodoRepository todos;
}
'''),
    );
    await assertNoDiagnosticsInFile(path);
  }
}
