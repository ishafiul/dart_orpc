/// Native HTTP/1.1 server for Dart.
///
/// Rust owns the sockets and parses HTTP on the thread of the isolate.
/// Handlers stay in Dart and use the `dart:io` `HttpServer` API.
library;
