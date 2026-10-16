import 'package:dart_orpc_generator/src/contracts/rest_route_pattern.dart';
import 'package:test/test.dart';

void main() {
  group('REST route patterns', () {
    test('adds a leading slash without changing published path spelling', () {
      for (final (input, expected) in [
        ('', '/'),
        ('/', '/'),
        ('items', '/items'),
        ('items/:id/', '/items/:id/'),
        ('/items//:id', '/items//:id'),
      ]) {
        expect(RestRoutePattern.parse(input).path, expected);
      }
    });

    test('retains parameter occurrences in route order', () {
      final route = RestRoutePattern.parse('/teams/:teamId/items/:id/:id');
      expect(route.parameterNames, ['teamId', 'id', 'id']);
    });

    test('uses existing identifier boundaries for parameter extraction', () {
      final route = RestRoutePattern.parse('/:_id/:9ignored/:valid-name');
      expect(route.parameterNames, ['_id', 'valid']);
    });

    test('literal routes and root have no parameters', () {
      expect(RestRoutePattern.parse('').parameterNames, isEmpty);
      expect(RestRoutePattern.parse('/health').parameterNames, isEmpty);
    });

    test(
      'collision signatures ignore parameter names and one trailing slash',
      () {
        final first = RestRoutePattern.parse('items/:id');
        final second = RestRoutePattern.parse('/items/:itemId/');
        expect(first.signature('get'), 'GET /items/:');
        expect(first.signature('get'), second.signature('GET'));
        expect(first.signature('POST'), isNot(first.signature('GET')));
        expect(second.path, '/items/:itemId/');
      },
    );

    test(
      'collision signatures retain literal segments and repeated slashes',
      () {
        expect(
          RestRoutePattern.parse('/items/list').collisionPath,
          '/items/list',
        );
        expect(RestRoutePattern.parse('/items///').collisionPath, '/items//');
        expect(RestRoutePattern.parse('/').signature('GET'), 'GET /');
      },
    );

    test('legacy embedded parameter spelling is not silently rewritten', () {
      final route = RestRoutePattern.parse('/items/prefix-:id');
      expect(route.parameterNames, ['id']);
      expect(route.collisionPath, '/items/prefix-:id');
    });

    test('parsed parameter names cannot be mutated by binding consumers', () {
      final route = RestRoutePattern.parse('/items/:id');
      expect(() => route.parameterNames.add('other'), throwsUnsupportedError);
    });
  });
}
