import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('Given the public annotation types', () {
    test(
      'When constructing a Module then it stores controllers and providers',
      () {
        const module = Module(controllers: [String], providers: [int]);

        expect(module.controllers, [String]);
        expect(module.providers, [int]);
      },
    );

    test('When constructing a Controller then it stores the namespace', () {
      const controller = Controller('user');

      expect(controller.namespace, 'user');
    });

    test('When constructing an RpcMethod then it stores the optional name', () {
      const namedMethod = RpcMethod(name: 'getById');
      const unnamedMethod = RpcMethod();

      expect(namedMethod.name, 'getById');
      expect(unnamedMethod.name, isNull);
    });

    test(
      'When constructing an RpcInput then it creates a marker annotation',
      () {
        const annotation = RpcInput();

        expect(annotation, isA<RpcInput>());
      },
    );
  });
}
