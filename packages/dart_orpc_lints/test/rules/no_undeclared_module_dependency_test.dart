// ignore_for_file: non_constant_identifier_names -- test_reflective_loader finds tests by their test_ prefix

import 'package:dart_orpc_lints/src/rules/no_undeclared_module_dependency.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../module_fixture.dart';
import '../orpc_rule_harness.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoUndeclaredModuleDependencyTest);
  });
}

@reflectiveTest
class NoUndeclaredModuleDependencyTest extends OrpcRuleTest with ModuleFixture {
  @override
  void setUp() {
    rule = NoUndeclaredModuleDependency();
    super.setUp();
    writeModules();
  }

  Future<void> test_reports_provider_of_unimported_module() async {
    const content = '''
import '../billing/billing_service.dart';

class ReportsService {
  ReportsService(this.billing);

  final BillingService billing;
}
''';
    final path = writeReportsService(content);
    await assertDiagnosticsInFile(path, [
      lintOn(content, 'BillingService billing', length: 14),
    ]);
  }

  Future<void> test_allows_provider_of_imported_module() async {
    final path = writeOrdersService('''
import '../billing/billing_service.dart';

class OrdersService {
  OrdersService(this.billing);

  final BillingService billing;
}
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_allows_provider_of_global_module() async {
    final path = writeReportsService('''
import '../clock/clock.dart';

class ReportsService {
  ReportsService(this.clock);

  final Clock clock;
}
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_leaves_unexported_providers_to_the_internal_rule() async {
    final path = writeReportsService('''
import '../billing/invoice_repository.dart';

class ReportsService {
  ReportsService(this.invoices);

  final InvoiceRepository invoices;
}
''');
    await assertNoDiagnosticsInFile(path);
  }
}
