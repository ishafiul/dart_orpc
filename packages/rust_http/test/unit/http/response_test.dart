import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rust_http/src/http/answer_channel.dart';
import 'package:rust_http/src/http/headers/response_headers.dart';
import 'package:rust_http/src/http/response/rust_http_response.dart';
import 'package:test/test.dart';

void main() {
  late _RecordingChannel channel;
  late RustHttpResponse response;

  setUp(() {
    channel = _RecordingChannel();
    response = RustHttpResponse(
      channel,
      requestId: 7,
      acceptEncoding: null,
      connectionInfo: _Info(),
    );
  });

  test('a buffered body goes out whole on close', () async {
    response
      ..write('a')
      ..write('b');

    final done = await response.close();

    expect(channel.events, ['answer 7 ab']);
    expect(done, same(response));
  });

  test('bufferOutput false streams every write at once', () async {
    response
      ..bufferOutput = false
      ..write('one')
      ..write('two');
    await response.close();

    expect(channel.events, ['start 7 one', 'part 1 two', 'end 1 complete']);
  });

  test('flush starts streaming what was written', () async {
    response.write('head');
    await response.flush();
    response.write('tail');
    await response.close();

    expect(channel.events, ['start 7 head', 'part 1 tail', 'end 1 complete']);
  });

  test('a deadline cuts the response', () async {
    response
      ..bufferOutput = false
      ..write('partial')
      ..deadline = Duration.zero;
    await Future<void>.delayed(Duration.zero);

    expect(channel.events, ['start 7 partial', 'end 1 cut']);
    expect(() => response.write('late'), throwsStateError);
  });

  test('a streamed body may not exceed its content length', () {
    response
      ..contentLength = 3
      ..bufferOutput = false
      ..write('abc');

    expect(() => response.write('d'), throwsA(isA<HttpException>()));
  });

  test('a short streamed body fails done and cuts the connection', () async {
    response
      ..contentLength = 5
      ..bufferOutput = false
      ..write('abc');

    await expectLater(response.close(), throwsA(isA<HttpException>()));
    expect(channel.events.last, 'end 1 cut');
  });

  test('a stream waits while the engine holds a full window', () async {
    final source = StreamController<List<int>>();
    final sending = response.addStream(source.stream);
    source.add(List.filled(RustHttpResponse.streamThreshold, 0));
    source.add(List.filled(2 << 20, 0));
    await Future<void>.delayed(Duration.zero);
    var finished = false;
    unawaited(sending.then((_) => finished = true));
    unawaited(source.close());
    await Future<void>.delayed(Duration.zero);

    expect(finished, isFalse, reason: 'waits for room');
    channel.listener!.onSent(3 << 20);
    await sending;
  });
}

final class _RecordingChannel implements AnswerChannel {
  final List<String> events = [];
  StreamListener? listener;

  @override
  final ResponseHeaders defaultResponseHeaders = ResponseHeaders.empty();

  @override
  int get localPort => 80;

  @override
  bool get isOpen => true;

  @override
  void sendAnswer(AnswerSource source) => events.add(
    'answer ${source.requestId} ${latin1.decode(source.takeBody())}',
  );

  @override
  int startStream(AnswerSource source, List<int> first, StreamListener l) {
    listener = l;
    events.add('start ${source.requestId} ${latin1.decode(first)}');
    return 1;
  }

  @override
  void sendStreamPart(int streamId, List<int> data) {
    if (data.length < 100) events.add('part $streamId ${latin1.decode(data)}');
  }

  @override
  void endStream(int streamId, {required bool complete}) =>
      events.add('end $streamId ${complete ? 'complete' : 'cut'}');
}

final class _Info implements HttpConnectionInfo {
  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  @override
  int get remotePort => 1;

  @override
  int get localPort => 80;
}
