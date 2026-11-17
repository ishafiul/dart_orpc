import 'package:dart_orpc_generator/src/di/di.dart';
import 'package:test/test.dart';

import 'support/module_graph_fixtures.dart';

void main() {
  group('Given a module with local providers', () {
    test('When providers depend on each other Then each is built after its dependencies', () {
      final graph = resolveGraph('App', [
        module(
          'App',
          providers: [
            provider('UserService', [needs('UserRepository')]),
            provider('UserRepository', [needs('Database')]),
            provider('Database'),
          ],
        ),
      ]);

      expect(constructionsOf(graph.root), [
        'Database()',
        'UserRepository(Database@App)',
        'UserService(UserRepository@App)',
      ]);
    });

    test('When parameters are named Then arguments keep their names', () {
      final graph = resolveGraph('App', [
        module(
          'App',
          providers: [
            provider('Clock'),
            provider('Cache', [
              needs('Clock', kind: ParameterKind.requiredNamed, name: 'clock'),
            ]),
          ],
        ),
      ]);

      expect(constructionsOf(graph.root), [
        'Clock()',
        'Cache(clock: Clock@App)',
      ]);
    });

    test('When an optional dependency is missing Then it is left out', () {
      final graph = resolveGraph('App', [
        module(
          'App',
          providers: [
            provider('Logger'),
            provider('Service', [
              needs('Metrics', kind: ParameterKind.optionalNamed),
              needs('Logger', kind: ParameterKind.optionalNamed),
            ]),
          ],
        ),
      ]);

      expect(constructionsOf(graph.root), [
        'Logger()',
        'Service(logger: Logger@App)',
      ]);
    });

    test('When an optional positional dependency is missing Then later optional positional ones are left out too', () {
      final graph = resolveGraph('App', [
        module(
          'App',
          providers: [
            provider('Logger'),
            provider('Service', [
              needs('Metrics', kind: ParameterKind.optionalPositional),
              needs('Logger', kind: ParameterKind.optionalPositional),
            ]),
          ],
        ),
      ]);

      expect(constructionsOf(graph.root), ['Logger()', 'Service()']);
    });

    test(
      'When providers only depend on each other optionally Then both are built',
      () {
        final graph = resolveGraph('App', [
          module(
            'App',
            providers: [
              provider('First', [
                needs('Second', kind: ParameterKind.optionalNamed),
              ]),
              provider('Second', [
                needs('First', kind: ParameterKind.optionalNamed),
              ]),
            ],
          ),
        ]);

        expect(constructionsOf(graph.root), [
          'First()',
          'Second(first: First@App)',
        ]);
      },
    );

    test('When providers depend on each other in a loop Then the error names the loop', () {
      expect(
        () => resolveGraph('App', [
          module(
            'App',
            providers: [
              provider('First', [needs('Second')]),
              provider('Second', [needs('First')]),
            ],
          ),
        ]),
        throwsA(
          isA<ProviderCycleError>()
              .having(
                (error) => error.message,
                'message',
                'Provider dependency cycle: First -> Second -> First.',
              )
              .having((error) => error.origin, 'origin', 'module App'),
        ),
      );
    });

    test('When a dependency cannot be provided or passed in Then the error names the provider', () {
      expect(
        () => resolveGraph('App', [
          module(
            'App',
            providers: [
              provider('Service', [
                needs('Callback', injectableFromOutside: false),
              ]),
            ],
          ),
        ]),
        throwsA(
          isA<UnresolvedProvidersError>().having(
            (error) => error.message,
            'message',
            'Unable to resolve provider dependencies for: Service.',
          ),
        ),
      );
    });

    test('When a provider is listed twice Then the error points at it', () {
      expect(
        () => resolveGraph('App', [
          module('App', providers: [provider('Service'), provider('Service')]),
        ]),
        throwsA(
          isA<DuplicateProviderError>()
              .having(
                (error) => error.message,
                'message',
                'Module "App" declares provider "Service" more than once.',
              )
              .having((error) => error.origin, 'origin', 'provider Service'),
        ),
      );
    });
  });

  group('Given a module with controllers', () {
    test('When a controller injects providers Then it receives them', () {
      final graph = resolveGraph('App', [
        module(
          'App',
          providers: [provider('UserService')],
          controllers: [
            controller('UserController', [needs('UserService')]),
          ],
        ),
      ]);

      expect(controllerConstructionsOf(graph.root), [
        'UserController(UserService@App)',
      ]);
    });

    test('When a controller needs something nobody provides Then the error points at the controller', () {
      expect(
        () => resolveGraph('App', [
          module(
            'App',
            controllers: [
              controller('UserController', [
                needs('Callback', injectableFromOutside: false),
              ]),
            ],
          ),
        ]),
        throwsA(
          isA<UnresolvedControllerError>()
              .having(
                (error) => error.message,
                'message',
                'Unable to resolve controller constructor dependencies for '
                    '"UserController".',
              )
              .having(
                (error) => error.origin,
                'origin',
                'controller UserController',
              ),
        ),
      );
    });
  });
}
