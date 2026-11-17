import 'package:dart_orpc_generator/src/di/di.dart';
import 'package:test/test.dart';

import 'support/module_graph_fixtures.dart';

void main() {
  group('Given ModuleOrdering', () {
    const ordering = ModuleOrdering();

    test(
      'When modules import each other Then each comes after its imports',
      () {
        final catalog = InMemoryModuleCatalog([
          module('App', imports: ['Users', 'Billing']),
          module('Users', imports: ['Database']),
          module('Billing', imports: ['Database']),
          module('Database'),
        ]);

        final ordered = ordering.order('App', catalog);

        expect(ordered.map((module) => module.key), [
          'Database',
          'Users',
          'Billing',
          'App',
        ]);
      },
    );

    test('When a module is reached along two paths Then it is read once', () {
      final catalog = InMemoryModuleCatalog([
        module('App', imports: ['Users', 'Billing']),
        module('Users', imports: ['Database']),
        module('Billing', imports: ['Database']),
        module('Database'),
      ]);

      ordering.order('App', catalog);

      expect(catalog.headerReads, ['App', 'Users', 'Database', 'Billing']);
      expect(catalog.declarationReads, ['Database', 'Users', 'Billing', 'App']);
    });

    test('When imports form a loop Then the error names the loop and declarations are not read', () {
      final catalog = InMemoryModuleCatalog([
        module('App', imports: ['Users']),
        module('Users', imports: ['Billing']),
        module('Billing', imports: ['Users']),
      ]);

      expect(
        () => ordering.order('App', catalog),
        throwsA(
          isA<ImportCycleError>()
              .having(
                (error) => error.message,
                'message',
                'Detected circular @Module.imports chain: '
                    'Users -> Billing -> Users.',
              )
              .having((error) => error.origin, 'origin', 'module Users'),
        ),
      );
      expect(catalog.declarationReads, isEmpty);
    });
  });
}
