import 'dart:convert';

import 'package:http/http.dart' as http;

const rpcTestBaseUrl = 'http://localhost:3000';
const rpcTestEndpoint = '$rpcTestBaseUrl/rpc';

String rpcDataBody(Object? data) => jsonEncode({'data': data});

http.Response rpcJsonResponse(
  Object? body, {
  int statusCode = 200,
  Map<String, String> headers = const {'content-type': 'application/json'},
}) {
  return http.Response(jsonEncode(body), statusCode, headers: headers);
}

http.Response rpcDataResponse(Object? data, {int statusCode = 200}) {
  return http.Response(
    rpcDataBody(data),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}
