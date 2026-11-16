import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../answer_channel.dart';
import '../headers/header_validation.dart';
import '../headers/response_headers.dart';
import 'body_buffer.dart';
import 'streamed_body.dart';

/// [HttpResponse] of the Rust-backed server.
///
/// A body is buffered and sent in one piece on [close]. It is streamed
/// instead — the head goes out at once and the rest follows in parts —
/// when [addStream] passes [streamThreshold] bytes, when [bufferOutput] is
/// false, or on [flush].
final class RustHttpResponse implements HttpResponse, AnswerSource {
  /// The response to a request.
  RustHttpResponse(
    this._channel, {
    required this.requestId,
    required this.acceptEncoding,
    required HttpConnectionInfo connectionInfo,
  }) : headers = ResponseHeaders(_channel.defaultResponseHeaders),
       _connectionInfo = connectionInfo;

  /// [addStream] starts streaming once this many bytes are buffered.
  static const int streamThreshold = 64 * 1024;

  final AnswerChannel _channel;
  final HttpConnectionInfo _connectionInfo;

  @override
  final int requestId;

  @override
  final String? acceptEncoding;

  @override
  final ResponseHeaders headers;

  @override
  int statusCode = HttpStatus.ok;

  @override
  String reasonPhrase = '';

  bool _bufferOutput = true;
  Duration? _deadline;
  Timer? _deadlineTimer;
  List<Cookie>? _cookies;
  Encoding? _encoding;
  final BodyBuffer _body = BodyBuffer();
  StreamedBody? _stream;
  bool _closed = false;
  Completer<HttpResponse>? _done;

  /// Whether the response is sent or upgraded.
  bool get isClosed => _closed;

  /// Whether cookies were added.
  @override
  bool get hasCookies => _cookies?.isNotEmpty ?? false;

  @override
  List<Cookie> get cookies => _cookies ??= [];

  @override
  bool get bufferOutput => _bufferOutput;

  @override
  set bufferOutput(bool buffer) {
    _bufferOutput = buffer;
    if (!buffer && !_closed && !_body.isEmpty) _startStream();
  }

  @override
  Duration? get deadline => _deadline;

  /// When the deadline passes, the response is cut: the client sees an
  /// incomplete answer and later writes are dropped, like dart:io.
  @override
  set deadline(Duration? deadline) {
    _deadlineTimer?.cancel();
    _deadline = deadline;
    if (deadline == null || _closed) return;
    _deadlineTimer = Timer(deadline, _abort);
  }

  @override
  int get contentLength => headers.contentLength;

  @override
  set contentLength(int length) => headers.contentLength = length;

  @override
  bool get persistentConnection => headers.persistentConnection;

  @override
  set persistentConnection(bool keep) => headers.persistentConnection = keep;

  @override
  HttpConnectionInfo? get connectionInfo => _connectionInfo;

  @override
  Encoding get encoding {
    final chosen = _encoding;
    if (chosen != null) return chosen;
    if (headers.isShared) return utf8; // text/plain; charset=utf-8
    final charset = headers.contentType?.charset;
    if (charset == null) return latin1;
    return Encoding.getByName(charset) ?? latin1;
  }

  @override
  set encoding(Encoding value) => _encoding = value;

  @override
  List<int> takeBody() => _body.take();

  @override
  void add(List<int> data) {
    if (_closed) throw StateError('StreamSink is closed');
    if (data.isEmpty) return;
    final stream = _stream;
    if (stream == null) {
      _body.add(data);
      if (!_bufferOutput) _startStream();
      return;
    }
    if (stream.clientGone) return;
    stream.count(data.length);
    _channel.sendStreamPart(stream.id, data);
  }

  @override
  void write(Object? object) {
    final text = '$object';
    if (text.isNotEmpty) add(encoding.encode(text));
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      write(objects.join(separator));

  @override
  void writeln([Object? object = '']) => write('$object\n');

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    final done = _done ??= Completer<HttpResponse>();
    if (!done.isCompleted) done.completeError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> source) async {
    try {
      await for (final chunk in source) {
        add(chunk);
        if (_stream == null && _body.length >= streamThreshold) {
          _startStream();
        }
        final stream = _stream;
        if (stream == null) continue;
        await stream.roomToSend();
        if (stream.clientGone) break; // stop reading the source
      }
    } catch (_) {
      final stream = _stream;
      if (stream != null && !_closed) {
        // The head is out: cut the connection, the body is not whole.
        _finish(complete: false);
      }
      rethrow;
    }
  }

  /// Sends the head and the buffered body now; later writes stream.
  @override
  Future<void> flush() async {
    if (_closed) return;
    _startStream();
    await _stream?.roomToSend();
  }

  @override
  Future<HttpResponse> close() {
    end();
    return done;
  }

  /// Sends the response like [close], without creating a Future. A Future
  /// per response keeps the request alive until microtasks run, so use
  /// this when the result of [close] is not needed. Errors still reach
  /// [done].
  void end() {
    if (_closed) return;
    final stream = _stream;
    if (stream == null) {
      _checkCookies();
      _closed = true;
      _deadlineTimer?.cancel();
      _channel.sendAnswer(this);
      _done?.complete(this);
      return;
    }
    if (stream.isShort) {
      // Like dart:io: fewer bytes than declared is an error. The engine
      // cuts the connection, so the client sees it.
      _finish(complete: false);
      addError(
        HttpException(
          'Content size below specified contentLength. '
          '${stream.written} bytes written but expected '
          '${stream.declaredLength}.',
        ),
      );
      return;
    }
    _finish(complete: true);
  }

  @override
  Future<HttpResponse> get done {
    if (_closed && _done == null) return Future.value(this);
    return (_done ??= Completer<HttpResponse>()).future;
  }

  @override
  Future<void> redirect(
    Uri location, {
    int status = HttpStatus.movedTemporarily,
  }) {
    statusCode = status;
    headers.set(HttpHeaders.locationHeader, location.toString());
    return close();
  }

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) {
    throw UnsupportedError(
      'rust_http cannot detach the socket: Rust owns it. '
      'Use RustWebSocket.upgrade for a WebSocket.',
    );
  }

  /// Marks the response as answered by a WebSocket accept.
  void markUpgraded() {
    _closed = true;
    _deadlineTimer?.cancel();
    _done?.complete(this);
  }

  void _startStream() {
    if (_stream != null || _closed) return;
    _checkCookies();
    final declared = headers.contentLength;
    final first = _body.take();
    final stream = StreamedBody(declaredLength: declared, alreadySent: 0);
    stream.count(first.length);
    stream.id = _channel.startStream(this, first, stream);
    _stream = stream;
  }

  void _finish({required bool complete}) {
    final stream = _stream!;
    _closed = true;
    _deadlineTimer?.cancel();
    _channel.endStream(stream.id, complete: complete);
    final done = _done;
    if (complete && done != null && !done.isCompleted) done.complete(this);
  }

  void _abort() {
    if (_closed) return;
    _startStream();
    _finish(complete: false);
    final done = _done;
    if (done != null && !done.isCompleted) done.complete(this);
  }

  /// Cookie does not check its domain, so a line break there would inject
  /// a header. Checked before the head goes out.
  void _checkCookies() {
    if (!hasCookies) return;
    for (final cookie in cookies) {
      checkHeaderValue(cookie.toString());
    }
  }
}
