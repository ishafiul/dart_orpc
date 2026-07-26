import 'package:benchmark_workloads/benchmark_workloads.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  try {
    return Response.json(body: processCheckout(await context.request.json()));
  } on FormatException catch (error) {
    return Response.json(statusCode: 400, body: {'error': error.message});
  }
}
