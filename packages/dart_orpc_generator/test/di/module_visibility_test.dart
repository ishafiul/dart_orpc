import 'package:dart_orpc_generator/src/di/di.dart';
import 'package:test/test.dart';

import 'support/module_graph_fixtures.dart';

void main() {
  group('Given imports and exports', () {
    test('When a module imports an exported provider Then it injects the exporter\'s instance', () {
      final graph = resolveGraph('App', [
        module(
          'Database',
          providers: [provider('Db')],
          exports: [exportsProvider('Db')],
        ),
        module(
          'App',
          imports: ['Database'],
          providers: [
            provider('Repo', [needs('Db')]),
          ],
        ),
      ]);

      expect(constructionsOf(scopeOf(graph, 'App')), ['Repo(Db@Database)']);
    });

    test('When a provider is not exported Then importers cannot see it and must be given it', () {
      final graph = resolveGraph('App', [
        module('Database', providers: [provider('Db')]),
        module(
          'App',
          imports: ['Database'],
          providers: [
            provider('Repo', [needs('Db')]),
          ],
        ),
      ]);

      expect(constructionsOf(scopeOf(graph, 'App')), [
        'Repo(Db@App (external))',
      ]);
    });

    test('When a module re-exports an imported module Then importers see that module\'s exports', () {
      final graph = resolveGraph('App', [
        module(
          'Database',
          providers: [provider('Db')],
          exports: [exportsProvider('Db')],
        ),
        module(
          'Core',
          imports: ['Database'],
          exports: [exportsModule('Database')],
        ),
        module(
          'App',
          imports: ['Core'],
          providers: [
            provider('Repo', [needs('Db')]),
          ],
        ),
      ]);

      expect(constructionsOf(scopeOf(graph, 'App')), ['Repo(Db@Database)']);
    });

    test('When a module is imported along two paths Then every importer shares one instance', () {
      final graph = resolveGraph('App', [
        module(
          'Todo',
          providers: [provider('TodoService')],
          exports: [exportsProvider('TodoService')],
        ),
        module(
          'Analysis',
          imports: ['Todo'],
          providers: [
            provider('AnalysisService', [needs('TodoService')]),
          ],
        ),
        module(
          'App',
          imports: ['Todo', 'Analysis'],
          controllers: [
            controller('AppController', [needs('TodoService')]),
          ],
        ),
      ]);

      expect(graph.modules.map((scope) => scope.key), [
        'Todo',
        'Analysis',
        'App',
      ]);
      expect(constructionsOf(scopeOf(graph, 'Analysis')), [
        'AnalysisService(TodoService@Todo)',
      ]);
      expect(controllerConstructionsOf(graph.root), [
        'AppController(TodoService@Todo)',
      ]);
    });

    test('When a module exports something it does not have Then the error names the export', () {
      expect(
        () => resolveGraph('App', [
          module('App', exports: [exportsProvider('Missing')]),
        ]),
        throwsA(
          isA<UnknownExportError>().having(
            (error) => error.message,
            'message',
            'Module "App" may only export its own providers or '
                'providers/modules from @Module.imports. Unknown export '
                '"Missing".',
          ),
        ),
      );
    });

    test('When a module exports a module it does not import Then the error says so', () {
      expect(
        () => resolveGraph('App', [
          module('Other'),
          module('App', exports: [exportsModule('Other')]),
        ]),
        throwsA(
          isA<UnknownExportError>().having(
            (error) => error.message,
            'message',
            'Module "App" may only export modules listed in @Module.imports. '
                'Unknown module export "Other".',
          ),
        ),
      );
    });

    test('When a module declares a provider it also imports Then the error names both sources', () {
      expect(
        () => resolveGraph('App', [
          module(
            'Database',
            providers: [provider('Db')],
            exports: [exportsProvider('Db')],
          ),
          module('App', imports: ['Database'], providers: [provider('Db')]),
        ]),
        throwsA(
          isA<ImportedProviderConflictError>()
              .having(
                (error) => error.message,
                'message',
                'Module "App" declares provider "Db" that conflicts with '
                    'provider "Db" from module "Database".',
              )
              .having((error) => error.origin, 'origin', 'provider Db'),
        ),
      );
    });

    test('When two imports export different providers of one type Then the error names both', () {
      expect(
        () => resolveGraph('App', [
          module(
            'Primary',
            providers: [provider('Db')],
            exports: [exportsProvider('Db')],
          ),
          module(
            'Replica',
            providers: [provider('Db')],
            exports: [exportsProvider('Db')],
          ),
          module('App', imports: ['Primary', 'Replica']),
        ]),
        throwsA(
          isA<AmbiguousProviderError>().having(
            (error) => error.message,
            'message',
            'Module "App" resolves provider type "Db" from more than one '
                'source (provider "Db" from module "Primary", provider "Db" '
                'from module "Replica").',
          ),
        ),
      );
    });
  });

  group('Given a global module', () {
    List<ModuleDeclaration> appWithGlobalDatabase({
      List<String> appImports = const ['Database', 'Users'],
    }) => [
      module(
        'Database',
        global: true,
        providers: [provider('Db'), provider('Pool')],
        exports: [exportsProvider('Db')],
      ),
      module(
        'Users',
        providers: [
          provider('UserService', [needs('Db')]),
        ],
      ),
      module('App', imports: appImports),
    ];

    test('When a module needs its export without importing it Then it gets the global instance', () {
      final graph = resolveGraph('App', appWithGlobalDatabase());

      expect(constructionsOf(scopeOf(graph, 'Users')), [
        'UserService(Db@Database)',
      ]);
      expect(graph.globalExports.map((instance) => instance.token.key), ['Db']);
    });

    test('When the global module is not in the graph Then its provider must be passed in', () {
      final graph = resolveGraph(
        'App',
        appWithGlobalDatabase(appImports: ['Users']),
      );

      expect(
        scopeOf(graph, 'Users').externalRequirements.single.type.name,
        'Db',
      );
    });

    test('When a module needs a provider the global module keeps private Then the error says to export it', () {
      expect(
        () => resolveGraph('App', [
          module('Database', global: true, providers: [provider('Pool')]),
          module(
            'Users',
            providers: [
              provider('UserService', [needs('Pool')]),
            ],
          ),
          module('App', imports: ['Database', 'Users']),
        ]),
        throwsA(
          isA<PrivateGlobalProviderError>().having(
            (error) => error.message,
            'message',
            'Module "Users" requires a private provider that is declared by a '
                'global module. Export the provider from that module.',
          ),
        ),
      );
    });

    test('When another module declares the same provider Then the error says it shadows the global one', () {
      expect(
        () => resolveGraph('App', [
          module(
            'Database',
            global: true,
            providers: [provider('Db')],
            exports: [exportsProvider('Db')],
          ),
          module('Users', providers: [provider('Db')]),
          module('App', imports: ['Database', 'Users']),
        ]),
        throwsA(
          isA<GlobalProviderShadowedError>().having(
            (error) => error.message,
            'message',
            'Module "Users" declares provider "Db" that shadows a global '
                'provider.',
          ),
        ),
      );
    });

    test('When two global modules export the same type Then the error names both', () {
      expect(
        () => resolveGraph('App', [
          module(
            'Primary',
            global: true,
            providers: [provider('Db')],
            exports: [exportsProvider('Db')],
          ),
          module(
            'Replica',
            global: true,
            providers: [provider('Db')],
            exports: [exportsProvider('Db')],
          ),
          module('App', imports: ['Primary', 'Replica']),
        ]),
        throwsA(
          isA<GlobalExportConflictError>().having(
            (error) => error.message,
            'message',
            'Global provider "Db" is exported by both "Primary" and "Replica".',
          ),
        ),
      );
    });
  });
}
