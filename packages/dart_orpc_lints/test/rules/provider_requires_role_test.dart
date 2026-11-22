// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/provider_requires_role.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../orpc_rule_harness.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ProviderRequiresRoleTest);
  });
}

@reflectiveTest
class ProviderRequiresRoleTest extends OrpcRuleTest {
  @override
  void setUp() {
    rule = ProviderRequiresRole();
    super.setUp();
  }

  Future<void> test_reports_provider_without_role() async {
    const content = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

class Plain {}

@Module(providers: [Plain])
final class AppModule {
  const AppModule();
}
''';
    await assertDiagnostics(content, [
      lint(content.lastIndexOf('Plain'), 5),
    ]);
  }

  Future<void> test_reports_controller_listed_as_provider() async {
    const content = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

@Controller('todo')
final class TodoController {}

@Module(providers: [TodoController])
final class AppModule {
  const AppModule();
}
''';
    await assertDiagnostics(content, [
      lint(content.lastIndexOf('TodoController'), 14),
    ]);
  }

  Future<void> test_allows_services_repositories_and_guards() async {
    await assertNoDiagnostics('''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

@Service()
final class TodoService {}

@Repository()
final class TodoRepository {}

final class AuthGuard implements RpcGuard {
  @override
  void canActivate(Object context) {}
}

@Module(providers: [TodoService, TodoRepository, AuthGuard])
final class AppModule {
  const AppModule();
}
''');
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

class Plain {}

@Module(providers: [Plain])
final class FakeModule {
  const FakeModule();
}
''');
    await assertNoDiagnosticsInFile(path);
  }
}
