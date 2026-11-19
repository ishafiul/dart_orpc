import 'orpc_rule_harness.dart';

const _billingModule = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

import 'billing_controller.dart';
import 'billing_service.dart';
import 'invoice_repository.dart';

@Module(
  controllers: [BillingController],
  providers: [BillingService, InvoiceRepository],
  exports: [BillingService],
)
final class BillingModule {
  const BillingModule();
}
''';

const _billingService = '''
import 'invoice_repository.dart';

class BillingService {
  BillingService(this.invoices);

  final InvoiceRepository invoices;
}
''';

const _invoiceRepository = '''
class InvoiceRepository {}
''';

const _billingController = '''
class BillingController {}
''';

const _invoiceDto = '''
class InvoiceDto {
  const InvoiceDto(this.total);

  final int total;
}
''';

const _clockModule = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

import 'clock.dart';

@Module(global: true, providers: [Clock], exports: [Clock])
final class ClockModule {
  const ClockModule();
}
''';

const _clock = '''
class Clock {}
''';

const _ordersModule = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

import '../billing/billing_module.dart';
import 'orders_service.dart';

@Module(imports: [BillingModule], providers: [OrdersService])
final class OrdersModule {
  const OrdersModule();
}
''';

const _reportsModule = '''
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

import 'reports_service.dart';

@Module(providers: [ReportsService])
final class ReportsModule {
  const ReportsModule();
}
''';

mixin ModuleFixture on OrpcRuleTest {
  void writeModules() {
    writeLibFile('billing/billing_module.dart', _billingModule);
    writeLibFile('billing/billing_service.dart', _billingService);
    writeLibFile('billing/invoice_repository.dart', _invoiceRepository);
    writeLibFile('billing/billing_controller.dart', _billingController);
    writeLibFile('billing/invoice_dto.dart', _invoiceDto);
    writeLibFile('clock/clock_module.dart', _clockModule);
    writeLibFile('clock/clock.dart', _clock);
    writeLibFile('orders/orders_module.dart', _ordersModule);
    writeLibFile('reports/reports_module.dart', _reportsModule);
  }

  String writeOrdersService(String content) =>
      writeLibFile('orders/orders_service.dart', content);

  String writeReportsService(String content) =>
      writeLibFile('reports/reports_service.dart', content);
}
