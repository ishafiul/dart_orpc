import 'package:benchmark_workloads/benchmark_workloads.dart';
import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  try {
    final query = context.request.uri.queryParameters;
    return Response.json(
      body: buildCatalog(
        category: query['category'] ?? '',
        page: int.parse(query['page'] ?? ''),
        limit: int.parse(query['limit'] ?? ''),
      ),
    );
  } on FormatException catch (error) {
    return Response.json(statusCode: 400, body: {'error': error.message});
  }
}
