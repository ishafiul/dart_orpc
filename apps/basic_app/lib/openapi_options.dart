import 'package:dart_orpc/dart_orpc.dart';

/// OpenAPI document options for the basic_app server.
///
/// Shared by `bin/server.dart` and the golden OpenAPI test, so the golden
/// snapshot matches the document the server serves at `/openapi.json`.
const basicAppOpenApiOptions = OpenApiDocumentOptions(
  title: 'Basic App API',
  description: 'Example todo API built with dart_orpc.',
);
