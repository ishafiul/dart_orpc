import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return (context) async {
    final response = await handler(context);
    final contentType = response.headers[HttpHeaders.contentTypeHeader];
    if (response.statusCode == HttpStatus.notFound &&
        (contentType == null || !contentType.startsWith('application/json'))) {
      return Response.json(
        statusCode: HttpStatus.notFound,
        body: const {'error': 'not found'},
      );
    }
    return response;
  };
}
