import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rust_http/src/http/answer_channel.dart';
import 'package:rust_http/src/http/headers/response_headers.dart';
import 'package:rust_http/src/http/rust_http_request.dart';
import 'package:rust_http/src/protocol/inbound_record.dart';
import 'package:rust_http/src/protocol/kinds.dart';
import 'package:rust_http/src/websocket/websocket_host.dart';
import 'package:test/test.dart';

void main() {
  group('RustHttpRequest.detach', () {
    late Uint8List batch;

    RustHttpRequest request({Uint8List? ownBody}) {
      final record = RequestRecord(
        id: 1,
        method: 'POST',
        target: '/',
        rawHeaders: Uint8List.sublistView(batch, 0, 6),
        body: ownBody ?? Uint8List.sublistView(batch, 6, 8),
        remoteIp: Uint8List.sublistView(batch, 8, 24),
        remotePort: 0,
        http10: false,
        isWebSocketUpgrade: false,
      );
      return RustHttpRequest(_NoChannel(), _NoHost(), record);
    }

    setUp(() {
      batch = Uint8List.fromList([
        ...[1, 0, 1, 0, 0x78, 0x79], // header x: y
        ...[0x68, 0x69], // body "hi"
        ...List<int>.filled(16, 0)..[15] = 1, // ::1
      ]);
    });

    test('copies the views into the batch', () {
      final detached = request()..detach(batch);

      batch.fillRange(0, batch.length, 0);

      expect(detached.headers.value('x'), 'y');
      expect(utf8.decode(detached.body), 'hi');
      expect(
        detached.connectionInfo.remoteAddress,
        InternetAddress.loopbackIPv6,
      );
    });

    test('keeps decoded headers and bytes from elsewhere', () {
      final own = Uint8List.fromList([0x6f]);
      final detached = request(ownBody: own);
      detached.headers.value('x'); // decoded before the detach

      detached.detach(batch);
      batch.fillRange(0, batch.length, 0);

      expect(detached.headers.value('x'), 'y');
      expect(identical(detached.body, own), isTrue);
    });
  });

  test('IPv4-mapped peers are reported as IPv4, like dart:io', () {
    final record = RequestRecord(
      id: 1,
      method: 'GET',
      target: '/',
      rawHeaders: Uint8List(0),
      body: Uint8List(0),
      remoteIp: Uint8List.fromList([
        ...List.filled(10, 0),
        0xff,
        0xff,
        127,
        0,
        0,
        1,
      ]),
      remotePort: 5,
      http10: false,
      isWebSocketUpgrade: false,
    );

    final request = RustHttpRequest(_NoChannel(), _NoHost(), record);

    expect(request.connectionInfo.remoteAddress, InternetAddress.loopbackIPv4);
  });
}

final class _NoChannel implements AnswerChannel {
  @override
  final ResponseHeaders defaultResponseHeaders = ResponseHeaders.empty();

  @override
  int get localPort => 80;

  @override
  bool get isOpen => false;

  @override
  void sendAnswer(AnswerSource source) {}

  @override
  int startStream(AnswerSource s, List<int> f, StreamListener l) => 0;

  @override
  void sendStreamPart(int streamId, List<int> data) {}

  @override
  void endStream(int streamId, {required bool complete}) {}
}

final class _NoHost implements WebSocketHost {
  @override
  int nextWebSocketId() => 1;

  @override
  void registerWebSocket(int id, WebSocketReceiver socket) {}

  @override
  void unregisterWebSocket(int id) {}

  @override
  void sendWebSocketRecord(
    int id,
    OutboundKind kind,
    int status,
    List<int> body, {
    String? protocol,
  }) {}
}
