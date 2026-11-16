/// Native HTTP/1.1 server for Dart.
///
/// Rust owns the sockets and parses HTTP on the thread of the isolate.
/// Handlers stay in Dart and use the `dart:io` `HttpServer` API.
library;

export 'src/http/headers/rust_http_headers.dart' show RustHttpHeaders;
export 'src/http/response/rust_http_response.dart' show RustHttpResponse;
export 'src/http/rust_http_request.dart'
    show RustHttpBodyException, RustHttpRequest;
export 'src/http/rust_http_server.dart' show RustHttpServer;
export 'src/websocket/rust_websocket.dart' show RustWebSocket;
