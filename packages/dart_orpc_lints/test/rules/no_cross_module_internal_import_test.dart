// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/no_cross_module_internal_import.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../module_fixture.dart';
import '../orpc_rule_harness.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoCrossModuleInternalImportTest);
  });
}

@reflectiveTest
class NoCrossModuleInternalImportTest extends OrpcRuleTest with ModuleFixture {
  @override
  void setUp() {
    rule = NoCrossModuleInternalImport();
    super.setUp();
    writeModules();
  }

  Future<void> test_reports_unexported_provider() async {
    const content = '''
import '../billing/invoice_repository.dart';

class OrdersService {
  OrdersService(this.invoices);

  final InvoiceRepository invoices;
}
''';
    final path = writeOrdersService(content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'InvoiceRepository invoices', length: 17),
    ]);
  }

  Future<void> test_reports_other_module_controller() async {
    const content = '''
import '../billing/billing_controller.dart';

class OrdersService {
  OrdersService(this.billing);

  final BillingController billing;
}
''';
    final path = writeOrdersService(content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'BillingController billing', length: 17),
    ]);
  }

  Future<void> test_allows_exported_provider() async {
    final path = writeOrdersService('''
import '../billing/billing_service.dart';

class OrdersService {
  OrdersService(this.billing);

  final BillingService billing;
}
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_allows_global_module_provider() async {
    final path = writeOrdersService('''
import '../clock/clock.dart';

class OrdersService {
  OrdersService(this.clock);

  final Clock clock;
}
''');
    await assertNoDiagnosticsInFile(path);
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

  Future<void> test_allows_same_module_internals() async {
    final path = writeLibFile('billing/billing_facade.dart', '''
import 'invoice_repository.dart';

class BillingFacade {
  BillingFacade(this.invoices);

  final InvoiceRepository invoices;
}
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_allows_tests() async {
    final path = writeTestDirectoryFile('''
import 'package:test/billing/invoice_repository.dart';

InvoiceRepository? fake;
''');
    await assertNoDiagnosticsInFile(path);
  }
}
