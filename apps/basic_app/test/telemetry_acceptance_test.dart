import 'dart:io';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/environment/app_env.dart';
import 'package:basic_app/modules/todo/todo_module.orpc.dart';
import 'package:basic_app/utils/require_permissions.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

const _permissions = 'todo.read,todo.write,todo.admin,tenant.active';

final class _CapturingExporter implements RpcTelemetryExporter {
  final List<RpcLogRecord> logs = [];
  final List<RpcSpanRecord> spans = [];

  @override
  Future<void> export(RpcTelemetryBatch batch) async {
    logs.addAll(batch.logs);
    spans.addAll(batch.spans);
  }

  @override
  Future<void> shutdown() async {}
}

RpcContext _permissionContext(RpcHttpRequest request) => RpcContext(
  headers: request.headers,
  httpMethod: request.method,
  path: request.path,
  attributes: {
    grantedPermissionsAttribute: _permissions.split(',').toSet(),
  },
);

void main() {
  test('Given an app observed by RpcLogger When calls arrive over HTTP and WebSocket then each call is logged and traced with its own trace context', () async {
    final directory = Directory.systemTemp.createTempSync(
      'basic-app-telemetry',
    );
    final env = AppEnv.fromMap({'JWT_SECRET': 'telemetry-secret'});
    final token = JWT(
      {'sub': 'telemetry-user'},
      issuer: env.jwtIssuer,
    ).sign(SecretKey(env.jwtSecret), expiresIn: env.jwtLifetime);
    final exporter = _CapturingExporter();
    final database = AppDatabase.atPath('${directory.path}/todos.db');
    final server = await const TodoModule()
        .buildRpcApp(
          appDatabase: database,
          webSocket: const RpcWebSocketServerOptions(),
          contextFactory: _permissionContext,
          bindings: const RpcContextBindings.empty().withValue(appEnvKey, env),
          observer: RpcLogger(
            backgroundExport: false,
            minSeverity: RpcLogSeverity.debug,
            exporters: [exporter],
          ),
        )
        .listen(0, hostname: InternetAddress.loopbackIPv4.address);
    final headers = {'authorization': 'Bearer $token'};
    final http = HttpRpcTransport(
      baseUrl: 'http://127.0.0.1:${server.port}',
      headers: headers,
    );
    final webSocket = await WebSocketRpcTransport.connect(
      Uri.parse('ws://127.0.0.1:${server.port}/rpc/ws'),
      headers: headers,
    );
    final overWebSocket = const TodoModule().createClient(
      transports: RpcClientTransports.duplex(webSocket),
    );
    final overHttp = const TodoModule().createClient(
      transports: RpcClientTransports.split(unary: http, streaming: webSocket),
    );

    await overWebSocket.todo.create(const CreateTodoDto(title: 'Traced'));
    await overHttp.todo.list();
    http.close();
    await webSocket.close();
    await server.close(gracePeriod: const Duration(seconds: 1));
    await database.close();
    directory.deleteSync(recursive: true);

    final access = exporter.logs.where(
      (record) => record.scope == 'dart_orpc.access',
    );
    final webSocketCreate = access.singleWhere(
      (record) =>
          record.attributes['network.transport'] == 'websocket' &&
          record.attributes['rpc.method'] == 'todo.create',
    );
    final httpList = access.singleWhere(
      (record) =>
          record.attributes['network.transport'] == 'http' &&
          record.attributes['rpc.method'] == 'todo.list',
    );
    final guardRecords = exporter.logs.where(
      (record) => record.scope == 'todo.guard',
    );
    expect(webSocketCreate.severity, RpcLogSeverity.info);
    expect(httpList.attributes['http.response.status_code'], HttpStatus.ok);
    expect(
      guardRecords.map((record) => record.traceId),
      containsAll([webSocketCreate.traceId, httpList.traceId]),
      reason: 'a Logger inside the guard joins the trace of its call',
    );
    expect(webSocketCreate.traceId, isNot(httpList.traceId));
    expect(
      exporter.spans.map((span) => span.name),
      containsAll(['todo.create', 'todo.list']),
    );
  });
}
