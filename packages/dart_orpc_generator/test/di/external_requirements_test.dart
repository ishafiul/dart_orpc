import 'package:dart_orpc_generator/src/di/di.dart';
import 'package:test/test.dart';

import 'support/module_graph_fixtures.dart';

void main() {
  group('Given ExternalRequirements', () {
    const requirements = ExternalRequirements();

    test('When providers and controllers need unprovided types Then each is required once, in first-use order', () {
      final found = requirements.collect(
        module(
          'Users',
          providers: [
            provider('UserService', [needs('Db'), needs('Clock')]),
            provider('AuditService', [needs('Db')]),
          ],
          controllers: [
            controller('UserController', [needs('Mailer')]),
          ],
        ),
        visibleKeys: const {},
        privateGlobalKeys: const {},
      );

      expect(found.map((requirement) => requirement.type.name), [
        'Db',
        'Clock',
        'Mailer',
      ]);
      expect(
        found.map((requirement) => requirement.instance.kind),
        everyElement(InstanceKind.external),
      );
    });

    test('When a type is visible, local, optional or cannot be passed in Then it is not required', () {
      final found = requirements.collect(
        module(
          'Users',
          providers: [
            provider('Repo'),
            provider('UserService', [
              needs('Db'),
              needs('Repo'),
              needs('Metrics', kind: ParameterKind.optionalNamed),
              needs('Callback', injectableFromOutside: false),
            ]),
          ],
        ),
        visibleKeys: const {'Db'},
        privateGlobalKeys: const {},
      );

      expect(found, isEmpty);
    });

    test('When the type is private Then generated code could not name it', () {
      expect(
        () => requirements.collect(
          module(
            'Users',
            providers: [
              provider('UserService', [needs('_Secret')]),
            ],
          ),
          visibleKeys: const {},
          privateGlobalKeys: const {},
        ),
        throwsA(
          isA<PrivateDependencyError>().having(
            (error) => error.message,
            'message',
            'Module "Users" requires private dependency "_Secret", which '
                'generated code cannot reference from another library.',
          ),
        ),
      );
    });
  });
}
