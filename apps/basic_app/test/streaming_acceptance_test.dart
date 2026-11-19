import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:basic_app/basic_app.dart';
import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/environment/app_env.dart';
import 'package:basic_app/test_support/strip_module.orpc.dart';
import 'package:basic_app/utils/require_permissions.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  test('Given a strip DTO When RPC and REST receive extra keys then both drop them before deserialization', () async {
    final server = await const StripModule().buildRpcApp().listen(
      0,
      hostname: InternetAddress.loopbackIPv4.address,
    );
    addTearDown(() => server.close(gracePeriod: const Duration(seconds: 1)));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final baseUri = Uri.parse(
      'http://${server.address.address}:${server.port}',
    );
    const input = {'value': 'known', 'unknown': true};

    final rpc = await _send(client, 'POST', baseUri.resolve('/rpc'), {
      'method': 'strip.echo',
      'input': input,
    });
    final rest = await _send(client, 'POST', baseUri.resolve('/strip'), input);

    expect(rpc.statusCode, HttpStatus.ok, reason: rpc.body);
    expect(jsonDecode(rpc.body), containsPair('data', {'value': 'known'}));
    expect(rest.statusCode, HttpStatus.ok, reason: rest.body);
    expect(jsonDecode(rest.body), {'value': 'known'});
  });

  test('Given one generated application When every transport is used then contracts, guards, and streams stay aligned', () async {
    final temporaryDirectory = Directory.systemTemp.createTempSync(
      'dart-orpc-acceptance',
    );
    final env = AppEnv.fromMap({
      'JWT_SECRET': 'acceptance-secret',
      'JWT_ISSUER': 'basic_app_acceptance',
      'JWT_EXPIRES_IN_SECONDS': '3600',
    });
    final accessToken = _createAccessToken(env);
    final database = AppDatabase.atPath('${temporaryDirectory.path}/todos.db');
    final app = const TodoModule().buildRpcApp(
      appDatabase: database,
      openApi: const OpenApiDocumentOptions(title: 'Acceptance API'),
      webSocket: const RpcWebSocketServerOptions(),
      sseHeartbeatInterval: Duration.zero,
      contextFactory: _permissionContext,
      bindings: const RpcContextBindings.empty().withValue(appEnvKey, env),
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
      interceptors: [_PermissionInterceptor(_allPermissions, accessToken)],
    );
    final authorizedWebSocket = await WebSocketRpcTransport.connect(
      Uri.parse('ws://${server.address.address}:${server.port}/rpc/ws'),
      headers: {
        'x-permissions': _allPermissions,
        'authorization': 'Bearer $accessToken',
      },
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
      await database.close();
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
      authorization: accessToken,
    );
    final restMissing = await _get(
      httpClient,
      baseUri.resolve('/todos/999999'),
      permissions: _allPermissions,
      authorization: accessToken,
    );
    expect(restSuccess.statusCode, HttpStatus.ok);
    expect(
      (jsonDecode(restSuccess.body) as Map<String, Object?>)['id'],
      created.id,
    );
    expect(restMissing.statusCode, HttpStatus.notFound);

    Future<_HttpResult> send(String method, String path, Object? body) => _send(
      httpClient,
      method,
      baseUri.resolve(path),
      body,
      permissions: _allPermissions,
      authorization: accessToken,
    );
    final unknownKeyRequests = {
      'RPC todo.create': await send('POST', '/rpc', {
        'method': 'todo.create',
        'input': {'title': 'Extra key', 'unknown': true},
      }),
      'REST POST /todos': await send('POST', '/todos', {
        'title': 'Extra key',
        'unknown': true,
      }),
      'RPC todo.update': await send('POST', '/rpc', {
        'method': 'todo.update',
        'input': {'id': created.id, 'title': 'Extra key', 'unknown': true},
      }),
      'REST PATCH /todos/:id': await send('PATCH', '/todos/${created.id}', {
        'title': 'Extra key',
        'unknown': true,
      }),
    };
    for (final MapEntry(key: request, value: result)
        in unknownKeyRequests.entries) {
      expect(
        result.statusCode,
        HttpStatus.badRequest,
        reason: '$request must reject an unknown input key',
      );
      final error =
          (jsonDecode(result.body) as Map<String, Object?>)['error']!
              as Map<String, Object?>;
      expect(error['code'], 'BAD_REQUEST', reason: request);
      final issues = parseRpcValidationIssues(
        error['details'] as Map<String, Object?>?,
      );
      expect(issues, hasLength(1), reason: request);
      expect(issues.single.path, ['unknown'], reason: request);
      expect(issues.single.code, 'unrecognizedKey', reason: request);
    }
    final badIdRequests = {
      'REST GET /todos/nope': await send('GET', '/todos/nope', null),
      'RPC todo.getById': await send('POST', '/rpc', {
        'method': 'todo.getById',
        'input': {'id': 'nope'},
      }),
    };
    for (final MapEntry(key: request, value: result) in badIdRequests.entries) {
      expect(result.statusCode, HttpStatus.badRequest, reason: request);
      final error =
          (jsonDecode(result.body) as Map<String, Object?>)['error']!
              as Map<String, Object?>;
      final issues = parseRpcValidationIssues(
        error['details'] as Map<String, Object?>?,
      );
      expect(issues, hasLength(1), reason: request);
      expect(issues.single.path, ['id'], reason: request);
      expect(
        issues.single.code,
        'invalidType',
        reason: '$request: REST decoding and validation report one issue',
      );
    }

    final emptyTitle = RpcValidationIssue(
      path: ['title'],
      code: 'tooShort',
      message: 'title must be at least 1 character long',
    );
    for (final (transport, client) in [
      ('HTTP', splitClient),
      ('WebSocket', duplexClient),
    ]) {
      await expectLater(
        client.todo.create(const CreateTodoDto(title: '')),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.badRequest)
              .having(
                (error) => error.validationIssues,
                '$transport validationIssues',
                [emptyTitle],
              ),
        ),
      );
    }
    final restEmptyTitle = await send('POST', '/todos', {'title': ''});
    expect(restEmptyTitle.statusCode, HttpStatus.badRequest);
    expect(
      parseRpcValidationIssues(
        ((jsonDecode(restEmptyTitle.body) as Map<String, Object?>)['error']!
                as Map<String, Object?>)['details']
            as Map<String, Object?>?,
      ),
      [emptyTitle],
      reason: 'REST sends the same issue shape as the generated clients',
    );

    final issueSchema =
        ((((((app.openApiDocument!['components']!
                                    as Map<String, Object?>)['schemas']!
                                as Map<String, Object?>)['RpcErrorBody']!
                            as Map<String, Object?>)['properties']!
                        as Map<String, Object?>)['details']!
                    as Map<String, Object?>)['properties']!
                as Map<String, Object?>)['issues']!
            as Map<String, Object?>;
    expect(
      (issueSchema['items']! as Map<String, Object?>)['required'],
      emptyTitle.toJson().keys,
      reason: 'OpenAPI describes the same validation issue shape',
    );

    final unchanged = await send('POST', '/rpc', {
      'method': 'todo.getById',
      'input': {'id': created.id},
    });
    expect(
      ((jsonDecode(unchanged.body) as Map<String, Object?>)['data']!
          as Map<String, Object?>)['title'],
      'Production stream',
    );

    final webSocketEvents = await splitClient.todo.watch().toList();
    expect(webSocketEvents.map((event) => event.id), contains(created.id));

    final sse = await _get(
      httpClient,
      baseUri.resolve('/todos/events'),
      permissions: _allPermissions,
      authorization: accessToken,
    );
    expect(sse.statusCode, HttpStatus.ok);
    expect(sse.contentType, contains('text/event-stream'));
    expect(sse.body, contains('"id":${created.id}'));
    expect(sse.body, endsWith('event: dart-orpc-complete\ndata: {}\n\n'));

    final openApi = await _get(httpClient, baseUri.resolve('/openapi.json'));
    final document = jsonDecode(openApi.body) as Map<String, Object?>;
    final paths = document['paths']! as Map<String, Object?>;
    final eventPath = paths['/todos/events']! as Map<String, Object?>;
    final eventOperation = eventPath['get']! as Map<String, Object?>;
    expect(
      eventOperation['x-dart-orpc-stream'],
      containsPair('kind', 'server-stream'),
    );
    expect(
      (document['components']! as Map<String, Object?>)['securitySchemes'],
      containsPair('bearerAuth', containsPair('scheme', 'bearer')),
    );
    expect(
      eventOperation['security'],
      equals([
        {'bearerAuth': <String>[]},
      ]),
    );

    final liveEvents = <TodoChangeResponseDto>[];
    final liveEventArrivals = _ArrivalSignal();
    final liveSubscription = duplexClient.todo.watchLive().listen((change) {
      liveEvents.add(change);
      liveEventArrivals.notify();
    });
    Future<void> probeUntilServerSideSubscriptionIsActive() async {
      for (var probe = 0; liveEvents.isEmpty; probe++) {
        if (probe == _maxLiveProbes) {
          fail('The live todo stream never delivered an event.');
        }
        await duplexClient.todo.create(
          CreateTodoDto(title: 'Live probe $probe'),
        );
        await liveEventArrivals.waitFor(
          () => liveEvents.isNotEmpty,
          within: _liveProbeWindow,
        );
      }
    }

    await probeUntilServerSideSubscriptionIsActive();
    final liveTodo = await duplexClient.todo.create(
      const CreateTodoDto(title: 'Live change'),
    );
    await duplexClient.todo.update(
      UpdateTodoDto(id: liveTodo.id, completed: true),
    );
    await duplexClient.todo.delete(GetTodoDto(id: liveTodo.id));
    List<TodoChangeResponseDto> liveTodoChanges() => [
      for (final change in liveEvents)
        if (change.todo.id == liveTodo.id) change,
    ];
    final allChangesArrived = await liveEventArrivals.waitFor(
      () => liveTodoChanges().length >= TodoChangeType.values.length,
      within: _liveDeliveryDeadline,
    );
    if (!allChangesArrived) {
      fail('Live changes of todo ${liveTodo.id}: ${liveTodoChanges()}');
    }
    final receivedChanges = liveTodoChanges();
    _cancelWithoutAwaitingTransportClose(liveSubscription);
    expect(
      receivedChanges.map((change) => change.type),
      orderedEquals(TodoChangeType.values),
    );
    expect(
      receivedChanges.map((change) => change.todo.id),
      everyElement(liveTodo.id),
    );

    final deniedHttpTransport = HttpRpcTransport(
      baseUrl: baseUri.toString(),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    final deniedHttpClient = const TodoModule().createClient(
      transports: RpcClientTransports.unary(deniedHttpTransport),
    );
    addTearDown(deniedHttpTransport.close);
    await expectLater(
      deniedHttpClient.todo.list(),
      throwsA(_forbiddenRpcError),
    );

    final unauthenticatedHttpTransport = HttpRpcTransport(
      baseUrl: baseUri.toString(),
    );
    final unauthenticatedClient = const TodoModule().createClient(
      transports: RpcClientTransports.unary(unauthenticatedHttpTransport),
    );
    addTearDown(unauthenticatedHttpTransport.close);
    await expectLater(
      unauthenticatedClient.todo.list(),
      throwsA(_unauthorizedRpcError),
    );

    final deniedRest = await _get(
      httpClient,
      baseUri.resolve('/todos'),
      authorization: accessToken,
    );
    final deniedSse = await _get(
      httpClient,
      baseUri.resolve('/todos/events'),
      authorization: accessToken,
    );
    expect(deniedRest.statusCode, HttpStatus.forbidden);
    expect(deniedSse.statusCode, HttpStatus.forbidden);
    expect(deniedSse.contentType, contains('application/json'));

    final unauthenticatedRest = await _get(
      httpClient,
      baseUri.resolve('/todos'),
    );
    expect(unauthenticatedRest.statusCode, HttpStatus.unauthorized);

    final deniedWebSocket = await WebSocketRpcTransport.connect(
      Uri.parse('ws://${server.address.address}:${server.port}/rpc/ws'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    addTearDown(deniedWebSocket.close);
    final deniedWebSocketClient = const TodoModule().createClient(
      transports: RpcClientTransports.duplex(deniedWebSocket),
    );
    await expectLater(
      deniedWebSocketClient.todo.list(),
      throwsA(_forbiddenRpcError),
    );
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('Given a missing todo When every transport reports it then error details stay aligned', () async {
    const missingId = 999999;
    const expectedDetails = {'todoId': missingId};
    final temporaryDirectory = Directory.systemTemp.createTempSync(
      'dart-orpc-details-acceptance',
    );
    final env = AppEnv.fromMap({
      'JWT_SECRET': 'acceptance-secret',
      'JWT_ISSUER': 'basic_app_acceptance',
      'JWT_EXPIRES_IN_SECONDS': '3600',
    });
    final accessToken = _createAccessToken(env);
    final database = AppDatabase.atPath('${temporaryDirectory.path}/todos.db');
    final server = await const TodoModule()
        .buildRpcApp(
          appDatabase: database,
          openApi: const OpenApiDocumentOptions(title: 'Acceptance API'),
          webSocket: const RpcWebSocketServerOptions(),
          sseHeartbeatInterval: Duration.zero,
          contextFactory: _permissionContext,
          bindings: const RpcContextBindings.empty().withValue(appEnvKey, env),
        )
        .listen(0, hostname: InternetAddress.loopbackIPv4.address);
    final baseUri = Uri.parse(
      'http://${server.address.address}:${server.port}',
    );
    final httpClient = HttpClient();
    final httpTransport = HttpRpcTransport(
      baseUrl: baseUri.toString(),
      interceptors: [_PermissionInterceptor(_allPermissions, accessToken)],
    );
    final webSocketTransport = await WebSocketRpcTransport.connect(
      Uri.parse('ws://${server.address.address}:${server.port}/rpc/ws'),
      headers: {
        'x-permissions': _allPermissions,
        'authorization': 'Bearer $accessToken',
      },
    );
    final httpClientApi = const TodoModule().createClient(
      transports: RpcClientTransports.split(
        unary: httpTransport,
        streaming: webSocketTransport,
      ),
    );
    final webSocketClientApi = const TodoModule().createClient(
      transports: RpcClientTransports.duplex(webSocketTransport),
    );
    addTearDown(() async {
      httpClient.close(force: true);
      httpTransport.close();
      await webSocketTransport.close();
      await server.close(gracePeriod: const Duration(seconds: 1));
      await database.close();
      if (temporaryDirectory.existsSync()) {
        temporaryDirectory.deleteSync(recursive: true);
      }
    });
    final missing = isA<RpcException>()
        .having((error) => error.code, 'code', RpcErrorCode.notFound)
        .having((error) => error.details, 'details', expectedDetails);

    await expectLater(
      httpClientApi.todo.getById(const GetTodoDto(id: missingId)),
      throwsA(missing),
      reason: 'generated client over HTTP RPC',
    );
    await expectLater(
      webSocketClientApi.todo.getById(const GetTodoDto(id: missingId)),
      throwsA(missing),
      reason: 'generated client over WebSocket',
    );
    await expectLater(
      httpClientApi.todo.watchById(const GetTodoDto(id: missingId)),
      emitsError(missing),
      reason: 'generated client streaming over WebSocket',
    );
    final rest = await _get(
      httpClient,
      baseUri.resolve('/todos/$missingId'),
      permissions: _allPermissions,
      authorization: accessToken,
    );
    expect(rest.statusCode, HttpStatus.notFound, reason: 'REST');
    final restError =
        (jsonDecode(rest.body) as Map<String, Object?>)['error']!
            as Map<String, Object?>;
    expect(restError['details'], expectedDetails);

    final sse = await _get(
      httpClient,
      baseUri.resolve('/todos/$missingId/events'),
      permissions: _allPermissions,
      authorization: accessToken,
    );
    final sseError = RegExp(r'event: dart-orpc-error\ndata: (.*)\n\n$')
        .firstMatch(sse.body);
    expect(
      sseError,
      isNotNull,
      reason: 'SSE must end with a terminal error event: ${sse.body}',
    );
    final sseEnvelope =
        (jsonDecode(sseError!.group(1)!) as Map<String, Object?>)['error']!
            as Map<String, Object?>;
    expect(sseEnvelope['code'], 'NOT_FOUND');
    expect(sseEnvelope['details'], expectedDetails);

    expect(
      sseEnvelope,
      restError,
      reason: 'REST and SSE carry the same error object',
    );

    final openApi = await _get(httpClient, baseUri.resolve('/openapi.json'));
    final schemas =
        ((jsonDecode(openApi.body) as Map<String, Object?>)['components']!
                as Map<String, Object?>)['schemas']!
            as Map<String, Object?>;
    final errorBody = schemas['RpcErrorBody']! as Map<String, Object?>;
    expect(errorBody['required'], ['code', 'message']);
    expect(
      (errorBody['properties']! as Map<String, Object?>)['details'],
      containsPair('type', 'object'),
      reason: 'OpenAPI documents the optional error details',
    );
  }, timeout: const Timeout(Duration(seconds: 20)));
}

const _allPermissions = 'todo.read,todo.write,todo.admin,tenant.active';

String _createAccessToken(AppEnv env) {
  return JWT(
    {'sub': 'acceptance-user'},
    issuer: env.jwtIssuer,
  ).sign(SecretKey(env.jwtSecret), expiresIn: env.jwtLifetime);
}

final TypeMatcher<RpcException> _forbiddenRpcError = isA<RpcException>().having(
  (error) => error.code,
  'code',
  RpcErrorCode.forbidden,
);

final TypeMatcher<RpcException> _unauthorizedRpcError = isA<RpcException>()
    .having(
      (error) => error.code,
      'code',
      RpcErrorCode.unauthorized,
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
    attributes: {grantedPermissionsAttribute: permissions},
  );
}

final class _PermissionInterceptor implements RpcInterceptorCore {
  const _PermissionInterceptor(this.permissions, this.accessToken);

  final String permissions;
  final String accessToken;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) {
    return next.next(
      request.copyWith(
        headers: {
          ...request.headers,
          'x-permissions': permissions,
          'authorization': 'Bearer $accessToken',
        },
      ),
    );
  }
}

Future<_HttpResult> _get(
  HttpClient client,
  Uri uri, {
  String? permissions,
  String? authorization,
}) async {
  final request = await client.getUrl(uri);
  if (permissions != null) {
    request.headers.set('x-permissions', permissions);
  }
  if (authorization != null) {
    request.headers.set('authorization', 'Bearer $authorization');
  }
  final response = await request.close();
  return _HttpResult(
    statusCode: response.statusCode,
    contentType: response.headers.contentType?.toString() ?? '',
    body: await utf8.decodeStream(response),
  );
}

Future<_HttpResult> _send(
  HttpClient client,
  String method,
  Uri uri,
  Object? body, {
  String? permissions,
  String? authorization,
}) async {
  final request = await client.openUrl(method, uri);
  request.headers.contentType = ContentType.json;
  if (permissions != null) {
    request.headers.set('x-permissions', permissions);
  }
  if (authorization != null) {
    request.headers.set('authorization', 'Bearer $authorization');
  }
  if (body != null) request.write(jsonEncode(body));
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

const _maxLiveProbes = 50;
const _liveProbeWindow = Duration(milliseconds: 100);
const _liveDeliveryDeadline = Duration(seconds: 5);

void _cancelWithoutAwaitingTransportClose(
  StreamSubscription<Object?> subscription,
) => subscription.cancel().ignore();

final class _ArrivalSignal {
  final List<({bool Function() condition, Completer<void> done})> _waiters = [];

  void notify() {
    for (final waiter in [..._waiters]) {
      if (waiter.condition()) {
        _waiters.remove(waiter);
        waiter.done.complete();
      }
    }
  }

  Future<bool> waitFor(
    bool Function() condition, {
    required Duration within,
  }) async {
    if (condition()) {
      return true;
    }
    final waiter = (condition: condition, done: Completer<void>());
    _waiters.add(waiter);
    return waiter.done.future
        .then((_) => true)
        .timeout(
          within,
          onTimeout: () {
            _waiters.remove(waiter);
            return false;
          },
        );
  }
}
