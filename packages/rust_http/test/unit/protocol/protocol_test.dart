import 'dart:convert';
import 'dart:typed_data';

import 'package:rust_http/src/protocol/inbound_record.dart';
import 'package:rust_http/src/protocol/kinds.dart';
import 'package:rust_http/src/protocol/outbound_record_writer.dart';
import 'package:rust_http/src/protocol/record_buffer.dart';
import 'package:test/test.dart';

void main() {
  group('InboundBatchReader', () {
    const reader = InboundBatchReader(_FakeExternalBodies());

    test('reads a request record', () {
      final batch = _inbound(
        id: 7,
        flags: RequestFlags.http10 | RequestFlags.webSocketUpgrade,
        method: 'GET',
        target: '/a?b=1',
        headers: [_header('x-test', 'yes')],
        body: utf8.encode('hi'),
        port: 8080,
      );

      final record = reader.read(batch).single as RequestRecord;

      expect(record.id, 7);
      expect(record.method, 'GET');
      expect(record.target, '/a?b=1');
      expect(record.rawHeaders, _header('x-test', 'yes'));
      expect(utf8.decode(record.body), 'hi');
      expect(record.remotePort, 8080);
      expect(record.remoteIp, hasLength(16));
      expect(record.http10, isTrue);
      expect(record.isWebSocketUpgrade, isTrue);
    });

    test('keeps every byte of an unknown method', () {
      for (final method in ['GOT', 'POOL', 'PUX', 'DELETX', 'PATCH']) {
        final record =
            reader.read(_inbound(method: method)).single as RequestRecord;
        expect(record.method, method);
      }
    });

    test('reads WebSocket and stream records', () {
      final batch = Uint8List.fromList([
        ..._inbound(id: 1, kind: InboundKind.webSocketText, body: [104]),
        ..._inbound(
          id: 2,
          kind: InboundKind.webSocketClosed,
          port: 1001,
          body: utf8.encode('bye'),
        ),
        ..._inbound(
          id: 3,
          kind: InboundKind.streamSent,
          body: (ByteData(
            8,
          )..setUint64(0, 99, Endian.little)).buffer.asUint8List(),
        ),
        ..._inbound(id: 4, kind: InboundKind.streamGone),
      ]);

      final records = reader.read(batch).toList();

      expect(records[0], isA<WebSocketRecord>());
      expect((records[0] as WebSocketRecord).kind, InboundKind.webSocketText);
      final closed = records[1] as WebSocketRecord;
      expect((closed.closeCode, utf8.decode(closed.payload)), (1001, 'bye'));
      expect((records[2] as StreamProgressRecord).sentBytes, 99);
      expect((records[3] as StreamProgressRecord).clientGone, isTrue);
    });

    test('resolves an external body', () {
      final reference = ByteData(24)
        ..setUint64(0, 1000, Endian.little)
        ..setUint64(8, 2000, Endian.little)
        ..setUint64(16, 5, Endian.little);
      final batch = _inbound(
        flags: RequestFlags.externalBody,
        body: reference.buffer.asUint8List(),
      );

      final record = reader.read(batch).single as RequestRecord;

      expect(record.body, [1000 % 256, 2000 % 256, 5]);
    });
  });

  group('OutboundRecordWriter', () {
    test('writes a record with header lines and a body', () {
      final writer = OutboundRecordWriter(HeapRecordBuffer(8));

      final start = writer.start(5, 201, OutboundKind.answer);
      writer.headerLine('x-a', 'b');
      writer.addFlags(start, AnswerFlags.gzip);
      writer.finish(start, utf8.encode('body'));

      final data = ByteData.sublistView(writer.buffer.bytes);
      expect(data.getUint64(0, Endian.little), 5);
      expect(data.getUint16(8, Endian.little), 201);
      expect(data.getUint16(10, Endian.little), AnswerFlags.gzip);
      expect(data.getUint32(12, Endian.little), 'x-a: b\r\n'.length);
      expect(data.getUint32(16, Endian.little), 4);
      expect(
        latin1.decode(writer.buffer.bytes.sublist(20, writer.length)),
        'x-a: b\r\nbody',
      );
    });

    test('puts a prefix word before the body', () {
      final writer = OutboundRecordWriter(HeapRecordBuffer());

      final start = writer.start(1, 200, OutboundKind.streamStart);
      writer.finish(start, [9], prefix: 42);

      final data = ByteData.sublistView(writer.buffer.bytes);
      expect(data.getUint16(10, Endian.little), OutboundKind.streamStart.wire);
      expect(data.getUint32(16, Endian.little), 9);
      expect(data.getUint64(20, Endian.little), 42);
      expect(writer.buffer.bytes[28], 9);
    });

    test('reset forgets what was written', () {
      final writer = OutboundRecordWriter(HeapRecordBuffer());
      writer.finish(writer.start(1, 200, OutboundKind.answer), [1, 2]);

      writer.reset();

      expect(writer.isEmpty, isTrue);
    });
  });

  test('outbound kinds that answer a request', () {
    expect(
      [
        for (final kind in OutboundKind.values)
          if (kind.answersRequest) kind,
      ],
      [
        OutboundKind.answer,
        OutboundKind.webSocketAccept,
        OutboundKind.streamStart,
      ],
    );
  });
}

final class _FakeExternalBodies implements ExternalBodyResolver {
  const _FakeExternalBodies();

  @override
  Uint8List resolve(int address, int token, int length) =>
      Uint8List.fromList([address % 256, token % 256, length]);
}

List<int> _header(String name, String value) => [
  name.length,
  0,
  value.length,
  0,
  ...latin1.encode(name),
  ...latin1.encode(value),
];

/// A record the way Rust writes it.
Uint8List _inbound({
  int id = 1,
  int flags = 0,
  InboundKind kind = InboundKind.request,
  String method = '',
  String target = '',
  List<List<int>> headers = const [],
  List<int> body = const [],
  int port = 0,
}) {
  final headerBytes = [for (final h in headers) ...h];
  final head = ByteData(inboundHeadLength)
    ..setUint64(0, id, Endian.little)
    ..setUint32(
      8,
      flags | (kind.index << RequestFlags.kindShift),
      Endian.little,
    )
    ..setUint16(12, method.length, Endian.little)
    ..setUint16(14, target.length, Endian.little)
    ..setUint32(16, headerBytes.length, Endian.little)
    ..setUint32(20, body.length, Endian.little)
    ..setUint16(24, port, Endian.little);
  return Uint8List.fromList([
    ...head.buffer.asUint8List(),
    ...latin1.encode(method),
    ...latin1.encode(target),
    ...headerBytes,
    ...body,
  ]);
}
