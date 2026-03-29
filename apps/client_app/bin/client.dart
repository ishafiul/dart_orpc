import 'dart:convert';

import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';

Future<void> main(List<String> args) async {
  final baseUrl = args.isNotEmpty ? args.first : 'http://127.0.0.1:3000';
  final title = args.length > 1 ? args[1] : 'Client app RPC smoke test';
  final transport = HttpRpcTransport(baseUrl: baseUrl);
  final client = const AppModule().createClient(transport: transport);

  try {
    final initialList = await client.todo.list();
    _printStep('todo.list (before)', initialList.toJson());

    final created = await client.todo.create(CreateTodoDto(title: title));
    _printStep('todo.create', created.toJson());

    final fetched = await client.todo.getById(GetTodoDto(id: created.id));
    _printStep('todo.getById', fetched.toJson());

    final updated = await client.todo.update(
      UpdateTodoDto(id: created.id, completed: true),
    );
    _printStep('todo.update', updated.toJson());

    final summary = await client.todoAnalysis.summary();
    _printStep('todoAnalysis.summary', summary.toJson());

    final deleted = await client.todo.delete(GetTodoDto(id: created.id));
    _printStep('todo.delete', deleted.toJson());

    final finalList = await client.todo.list();
    _printStep('todo.list (after)', finalList.toJson());
  } on RpcException catch (error) {
    _printStep('rpc.error', {
      'error': {'code': error.code.wireName, 'message': error.message},
    });
  } finally {
    transport.close();
  }
}

final JsonEncoder _encoder = const JsonEncoder.withIndent('  ');

void _printStep(String label, Object? payload) {
  print('$label:');
  print(_encoder.convert(payload));
}
