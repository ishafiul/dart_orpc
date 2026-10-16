/// A parsed REST path shared by binding analysis and contract validation.
///
/// Published paths retain their spelling, including trailing slashes. Collision
/// paths follow the existing generator policy: ignore one trailing slash and
/// erase names of colon-prefixed segments. Parameter occurrences retain order
/// and duplicates so each binding consumer can apply its own validation rules.
final class RestRoutePattern {
  RestRoutePattern._({
    required this.path,
    required this.collisionPath,
    required Iterable<String> parameterNames,
  }) : parameterNames = List.unmodifiable(parameterNames);

  factory RestRoutePattern.parse(String rawPath) {
    final path = rawPath.isEmpty
        ? '/'
        : rawPath.startsWith('/')
        ? rawPath
        : '/$rawPath';
    final parameterNames = [
      for (final match in _parameter.allMatches(path)) match.group(1)!,
    ];
    final collisionBase = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final collisionPath = collisionBase
        .split('/')
        .map((segment) => segment.startsWith(':') ? ':' : segment)
        .join('/');
    return RestRoutePattern._(
      path: path,
      collisionPath: collisionPath,
      parameterNames: parameterNames,
    );
  }

  static final _parameter = RegExp(r':([A-Za-z_][A-Za-z0-9_]*)');

  final String path;
  final String collisionPath;
  final List<String> parameterNames;

  String signature(String method) => '${method.toUpperCase()} $collisionPath';
}
