import 'package:dart_orpc_logger/dart_orpc_logger.dart';
import 'package:test/test.dart';

const _traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
final _at = DateTime(2026, 11, 19, 10);

String _format(RpcLogRecord record) {
  final out = StringBuffer();
  const RpcPrettyFormat(colors: false).write(out, record);
  return out.toString();
}

RpcLogRecord _access(
  RpcAttributes attributes, {
  RpcLogSeverity severity = RpcLogSeverity.info,
}) => RpcLogRecord(
  timestamp: _at,
  severity: severity,
  message: 'unused by the pretty format',
  scope: 'dart_orpc.access',
  attributes: attributes,
  traceId: _traceId,
);

void main() {
  group('Given the pretty format', () {
    test('When an HTTP call is logged then it reads as aligned columns', () {
      expect(
        _format(
          _access({
            'network.transport': 'http',
            'http.request.method': 'POST',
            'url.path': '/rpc',
            'rpc.method': 'todo.list',
            'http.response.status_code': 401,
            'http.server.request.duration': 0.0021,
            'error.type': 'UNAUTHORIZED',
          }, severity: RpcLogSeverity.warn),
        ),
        '10:00:00.000  WARN   POST    /rpc              todo.list         '
        '401     2.1 ms  UNAUTHORIZED  4bf92f35\n',
      );
    });

    test(
      'When a WebSocket call is logged then it shows WS and its outcome',
      () {
        expect(
          _format(
            _access({
              'network.transport': 'websocket',
              'http.request.method': 'GET',
              'url.path': '/rpc/ws',
              'rpc.method': 'todo.create',
              'http.server.request.duration': 1.5,
            }),
          ),
          '10:00:00.000  INFO   WS      /rpc/ws           todo.create       '
          'ok     1.50 s  4bf92f35\n',
        );
      },
    );

    test('When the server starts then a banner lists every endpoint', () {
      expect(
        _format(
          RpcLogRecord(
            timestamp: _at,
            severity: RpcLogSeverity.info,
            message: 'server.started',
            scope: 'dart_orpc.server',
            attributes: {
              'service.name': 'basic_app',
              'server.port': 3000,
              'url.rpc': 'http://127.0.0.1:3000/rpc',
              'url.websocket': 'ws://127.0.0.1:3000/rpc/ws',
            },
          ),
        ),
        '\n'
        '  dart_orpc  basic_app is listening\n'
        '\n'
        '  ➜  rpc        http://127.0.0.1:3000/rpc\n'
        '  ➜  websocket  ws://127.0.0.1:3000/rpc/ws\n'
        '\n',
      );
    });

    test(
      'When an app record is logged then scope, message and attributes follow',
      () {
        expect(
          _format(
            RpcLogRecord(
              timestamp: _at,
              severity: RpcLogSeverity.info,
              message: 'todo.created',
              scope: 'todo',
              attributes: {
                'todo.id': 3,
                'todo.tags': ['a', 'b'],
              },
              traceId: _traceId,
            ),
          ),
          '10:00:00.000  INFO   todo  todo.created  todo.id=3  '
          'todo.tags=[a, b]  4bf92f35\n',
        );
      },
    );

    test('When a record has a long stack trace then the frames are indented and capped', () {
      final frames = [for (var index = 0; index < 15; index++) '#$index frame'];
      final output = _format(
        RpcLogRecord(
          timestamp: _at,
          severity: RpcLogSeverity.error,
          message: 'job.failed',
          scope: 'job',
          stackTrace: StackTrace.fromString(frames.join('\n')),
        ),
      );

      final lines = output.trimRight().split('\n');
      expect(lines.first, '10:00:00.000  ERROR  job  job.failed');
      expect(lines.skip(1).first, '    #0 frame');
      expect(lines, hasLength(14));
      expect(lines.last, '    … 3 more frames');
    });

    test('When colours are on then levels and statuses are painted', () {
      final out = StringBuffer();
      const RpcPrettyFormat(colors: true).write(
        out,
        _access({
          'http.request.method': 'GET',
          'url.path': '/docs',
          'http.response.status_code': 500,
        }, severity: RpcLogSeverity.error),
      );

      expect('$out', contains('\x1B[1;31mERROR\x1B[0m'));
      expect('$out', contains('\x1B[1;31m500\x1B[0m'));
    });
  });
}
