// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/no_manual_provider_construction.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../module_fixture.dart';
import '../orpc_rule_harness.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoManualProviderConstructionTest);
  });
}

@reflectiveTest
class NoManualProviderConstructionTest extends OrpcRuleTest with ModuleFixture {
  @override
  void setUp() {
    rule = NoManualProviderConstruction();
    super.setUp();
    writeModules();
  }

  Future<void> test_reports_other_module_provider() async {
    const content = '''
import '../billing/billing_service.dart';
import '../billing/invoice_repository.dart';

class OrdersService {
  BillingService billing() => BillingService(InvoiceRepository());
}
''';
    final path = writeOrdersService(content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'BillingService(', length: 14),
      lintOn(content, 'InvoiceRepository()', length: 17),
    ]);
  }

  Future<void> test_reports_own_module_provider_built_elsewhere() async {
    writeOrdersService('''
class OrdersService {}
''');
    const content = '''
import 'orders_service.dart';

class OrdersReport {
  OrdersService source() => OrdersService();
}
''';
    final path = writeLibFile('orders/orders_report.dart', content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'OrdersService()', length: 13),
    ]);
  }

  Future<void> test_reports_controller() async {
    const content = '''
import '../billing/billing_controller.dart';

class OrdersService {
  BillingController controller() => BillingController();
}
''';
    final path = writeOrdersService(content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'BillingController()', length: 17),
    ]);
  }

  Future<void> test_reports_unregistered_service() async {
    const content = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

@Service()
final class AuditService {}

class OrdersService {
  AuditService audit() => AuditService();
}
''';
    final path = writeOrdersService(content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'AuditService()', length: 12),
    ]);
  }

  Future<void> test_allows_non_provider_types() async {
    final path = writeOrdersService('''
import '../billing/invoice_dto.dart';

class OrdersService {
  InvoiceDto latest() => const InvoiceDto(1);
}
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_allows_provider_constructing_itself() async {
    final path = writeOrdersService('''
class OrdersService {
  OrdersService();

  factory OrdersService.empty() => OrdersService();

  static OrdersService open() => OrdersService.empty();
}
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
import 'package:test/billing/invoice_repository.dart';

final repository = InvoiceRepository();
''');
    await assertNoDiagnosticsInFile(path);
  }
}
