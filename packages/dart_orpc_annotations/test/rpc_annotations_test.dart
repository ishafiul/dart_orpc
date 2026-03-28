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
      'When constructing an RpcMethod with path metadata then it stores the optional path mapping and docs fields',
      () {
        const method = RpcMethod(
          name: 'getById',
          path: RestMapping.get('users/:id'),
          description: 'Fetch a user by id.',
          tags: ['user', 'read'],
        );

        expect(method.name, 'getById');
        expect(method.path, isNotNull);
        expect(method.path!.method, 'GET');
        expect(method.path!.path, '/users/:id');
        expect(method.description, 'Fetch a user by id.');
        expect(method.tags, ['user', 'read']);
      },
    );

    test(
      'When constructing RestMapping then verb constructors normalize method and path',
      () {
        const get = RestMapping.get('users/:id');
        const post = RestMapping.post('/users');
        const put = RestMapping.put('');
        const patch = RestMapping.patch('users/:id');
        const delete = RestMapping.delete('users/:id');

        expect(get.method, 'GET');
        expect(get.path, '/users/:id');
        expect(post.method, 'POST');
        expect(post.path, '/users');
        expect(put.method, 'PUT');
        expect(put.path, '/');
        expect(patch.method, 'PATCH');
        expect(delete.method, 'DELETE');
      },
    );

    test(
      'When constructing an RpcInput then it creates a marker annotation',
      () {
        const annotation = RpcInput();

        expect(annotation, isA<RpcInput>());
      },
    );

    test(
      'When constructing REST parameter annotations then they store their optional wire names',
      () {
        const path = PathParam('id');
        const unnamedQuery = QueryParam();
        const body = Body();

        expect(path.name, 'id');
        expect(unnamedQuery.name, isNull);
        expect(body, isA<Body>());
      },
    );
  });
}
