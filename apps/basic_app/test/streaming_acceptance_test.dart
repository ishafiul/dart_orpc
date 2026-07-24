import 'dart:convert';
import 'dart:io';

import 'package:basic_app/basic_app.dart';
import 'package:basic_app/database/database_open.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given one generated application When every transport is used then contracts, guards, and streams stay aligned',
    () async {
      final temporaryDirectory = Directory.systemTemp.createTempSync(
        'dart-orpc-acceptance',
      );
      databasePathOverride = '${temporaryDirectory.path}/todos.db';
      final app = const TodoModule().buildRpcApp(
        openApi: const OpenApiDocumentOptions(title: 'Acceptance API'),
        webSocket: const RpcWebSocketServerOptions(),
        sseHeartbeatInterval: Duration.zero,
        contextFactory: _permissionContext,
      );
      final server = await app.listen(
        0,
        hostname: InternetAddress.loopbackIPv4.address,
      );
      final baseUri = Uri.parse(
        'http://${server.address.address}:${server.port}',
      );
      final httpClient = HttpClient();
      final authorizedHttp = HttpRpcTransport(
        baseUrl: baseUri.toString(),
        interceptors: const [_PermissionInterceptor(_allPermissions)],
      );
      final authorizedWebSocket = await WebSocketRpcTransport.connect(
        Uri.parse('ws://${server.address.address}:${server.port}/rpc/ws'),
        headers: const {'x-permissions': _allPermissions},
      );
      final splitClient = const TodoModule().createClient(
        transports: RpcClientTransports.split(
          unary: authorizedHttp,
          streaming: authorizedWebSocket,
        ),
      );
      final duplexClient = const TodoModule().createClient(
        transports: RpcClientTransports.duplex(authorizedWebSocket),
      );

      addTearDown(() async {
        httpClient.close(force: true);
        authorizedHttp.close();
        await authorizedWebSocket.close();
        await server.close(gracePeriod: const Duration(seconds: 1));
        databasePathOverride = null;
        if (temporaryDirectory.existsSync()) {
          temporaryDirectory.deleteSync(recursive: true);
        }
      });

      final created = await splitClient.todo.create(
        const CreateTodoDto(title: 'Production stream'),
      );
      expect(created.id, greaterThan(0));

      final rpcResult = await duplexClient.todo.getById(
        GetTodoDto(id: created.id),
      );
      expect(rpcResult.title, 'Production stream');
      await expectLater(
        splitClient.todo.getById(const GetTodoDto(id: 999999)),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.notFound,
          ),
        ),
      );

      final restSuccess = await _get(
        httpClient,
        baseUri.resolve('/todos/${created.id}'),
        permissions: _allPermissions,
      );
      final restMissing = await _get(
        httpClient,
        baseUri.resolve('/todos/999999'),
        permissions: _allPermissions,
      );
      expect(restSuccess.statusCode, HttpStatus.ok);
      expect(
        (jsonDecode(restSuccess.body) as Map<String, Object?>)['id'],
        created.id,
      );
      expect(restMissing.statusCode, HttpStatus.notFound);

      final webSocketEvents = await splitClient.todo.watch().toList();
      expect(webSocketEvents.map((event) => event.id), contains(created.id));

      final sse = await _get(
        httpClient,
        baseUri.resolve('/todos/events'),
        permissions: _allPermissions,
      );
      expect(sse.statusCode, HttpStatus.ok);
      expect(sse.contentType, contains('text/event-stream'));
      expect(sse.body, contains('"id":${created.id}'));
      expect(sse.body, endsWith('event: dart-orpc-complete\ndata: {}\n\n'));

      final openApi = await _get(httpClient, baseUri.resolve('/openapi.json'));
      final document = jsonDecode(openApi.body) as Map<String, Object?>;
      final paths = document['paths'] as Map<String, Object?>;
      final eventPath = paths['/todos/events'] as Map<String, Object?>;
      final eventOperation = eventPath['get'] as Map<String, Object?>;
      expect(
        eventOperation['x-dart-orpc-stream'],
        containsPair('kind', 'server-stream'),
      );

      final liveChanges = duplexClient.todo.watchLive().take(3).toList();
      final liveTodo = await duplexClient.todo.create(
        const CreateTodoDto(title: 'Live change'),
      );
      await duplexClient.todo.update(
        UpdateTodoDto(id: liveTodo.id, completed: true),
      );
      await duplexClient.todo.delete(GetTodoDto(id: liveTodo.id));
      final receivedChanges = await liveChanges;
      expect(
        receivedChanges.map((change) => change.type),
        orderedEquals(['created', 'updated', 'deleted']),
      );
      expect(
        receivedChanges.map((change) => change.todo.id),
        everyElement(liveTodo.id),
      );

      final deniedHttpTransport = HttpRpcTransport(baseUrl: baseUri.toString());
      final deniedHttpClient = const TodoModule().createClient(
        transports: RpcClientTransports.unary(deniedHttpTransport),
      );
      addTearDown(deniedHttpTransport.close);
      await expectLater(
        deniedHttpClient.todo.list(),
        throwsA(_forbiddenRpcError),
      );

      final deniedRest = await _get(httpClient, baseUri.resolve('/todos'));
      final deniedSse = await _get(
        httpClient,
        baseUri.resolve('/todos/events'),
      );
      expect(deniedRest.statusCode, HttpStatus.forbidden);
      expect(deniedSse.statusCode, HttpStatus.forbidden);
      expect(deniedSse.contentType, contains('application/json'));

      final deniedWebSocket = await WebSocketRpcTransport.connect(
        Uri.parse('ws://${server.address.address}:${server.port}/rpc/ws'),
      );
      addTearDown(deniedWebSocket.close);
      final deniedWebSocketClient = const TodoModule().createClient(
        transports: RpcClientTransports.duplex(deniedWebSocket),
      );
      await expectLater(
        deniedWebSocketClient.todo.list(),
        throwsA(_forbiddenRpcError),
      );
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}

const _allPermissions = 'todo.read,todo.write,todo.admin,tenant.active';

final _forbiddenRpcError = isA<RpcException>().having(
  (error) => error.code,
  'code',
  RpcErrorCode.forbidden,
);

RpcContext _permissionContext(RpcHttpRequest request) {
  final header = lookupRestHeader(request.headers, 'x-permissions') ?? '';
  final permissions = header
      .split(',')
      .map((permission) => permission.trim())
      .where((permission) => permission.isNotEmpty)
      .toSet();
  return RpcContext(
    headers: request.headers,
    httpMethod: request.method,
    path: request.path,
    attributes: {'permissions': permissions},
  );
}

final class _PermissionInterceptor implements RpcInterceptorCore {
  const _PermissionInterceptor(this.permissions);

  final String permissions;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) {
    return next.next(
      request.copyWith(
        headers: {...request.headers, 'x-permissions': permissions},
      ),
    );
  }
}

Future<_HttpResult> _get(
  HttpClient client,
  Uri uri, {
  String? permissions,
}) async {
  final request = await client.getUrl(uri);
  if (permissions != null) {
    request.headers.set('x-permissions', permissions);
  }
  final response = await request.close();
  return _HttpResult(
    statusCode: response.statusCode,
    contentType: response.headers.contentType?.toString() ?? '',
    body: await utf8.decodeStream(response),
  );
}

final class _HttpResult {
  const _HttpResult({
    required this.statusCode,
    required this.contentType,
    required this.body,
  });

  final int statusCode;
  final String contentType;
  final String body;
}
