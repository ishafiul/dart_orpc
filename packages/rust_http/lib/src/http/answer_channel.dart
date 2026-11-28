import 'dart:io';

import 'headers/response_headers.dart';

/// What a request and its response need from their server.
///
/// `RustHttpServer` implements it; responses never see the engine.
abstract interface class AnswerChannel {
  /// The headers every response starts with.
  ResponseHeaders get defaultResponseHeaders;

  /// The port the server listens on; 0 on a Unix domain socket.
  int get localPort;

  /// Whether the server listens on a Unix domain socket, whose peers have
  /// no address.
  bool get isUnixSocket;

  /// Whether the server still talks to the engine.
  bool get isOpen;

  /// Sends the whole answer of [source].
  void sendAnswer(AnswerSource source);

  /// Starts a streamed answer with [first] as its first part. Returns the
  /// stream id for [sendStreamPart] and [endStream].
  int startStream(
    AnswerSource source,
    List<int> first,
    StreamListener listener,
  );

  /// Sends one part of stream [streamId].
  void sendStreamPart(int streamId, List<int> data);

  /// Ends stream [streamId]. When not [complete], the connection is cut so
  /// the client sees a short body.
  void endStream(int streamId, {required bool complete});
}

/// Everything about an answer that goes on the wire.
abstract interface class AnswerSource {
  /// The id of the request in the engine.
  int get requestId;

  /// The request's `accept-encoding`, for automatic compression.
  String? get acceptEncoding;

  /// The status code.
  int get statusCode;

  /// The response headers.
  ResponseHeaders get headers;

  /// The cookies to set.
  List<Cookie> get cookies;

  /// Whether any cookie was added, without creating the list.
  bool get hasCookies;

  /// Takes the buffered body, leaving it empty.
  List<int> takeBody();
}

/// Told about a streamed body's progress.
abstract interface class StreamListener {
  /// [bytes] reached the client's socket.
  void onSent(int bytes);

  /// The client is gone; stop sending.
  void onClientGone();
}
