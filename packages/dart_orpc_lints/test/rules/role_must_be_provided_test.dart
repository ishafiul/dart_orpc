// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/role_must_be_provided.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../module_fixture.dart';
import '../orpc_rule_harness.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RoleMustBeProvidedTest);
  });
}

@reflectiveTest
class RoleMustBeProvidedTest extends OrpcRuleTest with ModuleFixture {
  @override
  void setUp() {
    rule = RoleMustBeProvided();
    super.setUp();
    writeModules();
  }

  Future<void> test_reports_service_missing_from_its_module() async {
    const content = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

@Service()
final class RefundService {}
''';
    final path = writeLibFile('billing/refund_service.dart', content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'RefundService'),
    ]);
  }

  Future<void> test_reports_repository_outside_any_module() async {
    const content = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

@Repository()
final class AuditRepository {}
''';
    final path = writeLibFile('audit/audit_repository.dart', content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'AuditRepository'),
    ]);
  }

  Future<void> test_allows_provided_service() async {
    final path = writeLibFile('billing/billing_service.dart', '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

@Service()
class BillingService {}
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_ignores_classes_without_a_role() async {
    final path = writeLibFile('billing/invoice_mapper.dart', '''
class InvoiceMapper {}
''');
    await assertNoDiagnosticsInFile(path);
  }
}
