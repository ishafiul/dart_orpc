import 'dart:async';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/modules/todo/todo_dtos.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:drift/drift.dart';

const _todoIdDetail = 'todoId';
const _emptyTitle = 'title must not be empty.';

String _todoNotFound(int id) => 'Todo $id was not found.';

RpcException _todoNotFoundError(int id) =>
    RpcException.notFound(_todoNotFound(id), details: {_todoIdDetail: id});

final class TodoService {
  TodoService(this.db);

  final AppDatabase db;
  final StreamController<TodoChangeResponseDto> _changes =
      StreamController<TodoChangeResponseDto>.broadcast(sync: true);

  Stream<TodoChangeResponseDto> watchChanges() => _changes.stream;

  Stream<TodoResponseDto> watchSnapshot(
    RpcCancellationSignal cancellation,
  ) async* {
    final snapshot = await list();
    for (final todo in snapshot.items) {
      cancellation.throwIfCancelled();
      yield todo;
    }
  }

  Future<TodoListResponseDto> list() async {
    final rows = await db.select(db.todos).get();
    return TodoListResponseDto(items: [for (final row in rows) _toDto(row)]);
  }

  Future<TodoResponseDto> getById(int id) async {
    final row = await (db.select(
      db.todos,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw _todoNotFoundError(id);
    }
    return _toDto(row);
  }

  Future<TodoResponseDto> create(String title) async {
    final id = await db
        .into(db.todos)
        .insert(TodosCompanion.insert(title: title));
    final todo = await getById(id);
    _changes.add(
      TodoChangeResponseDto(type: TodoChangeType.created, todo: todo),
    );
    return todo;
  }

  Future<TodoResponseDto> update({
    required int id,
    String? title,
    bool? completed,
  }) async {
    await getById(id);
    if (title == null && completed == null) {
      return getById(id);
    }
    if (title != null && title.isEmpty) {
      throw RpcException.badRequest(_emptyTitle);
    }
    await (db.update(db.todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        title: title == null ? const Value.absent() : Value(title),
        completed: completed == null ? const Value.absent() : Value(completed),
      ),
    );
    final todo = await getById(id);
    _changes.add(
      TodoChangeResponseDto(type: TodoChangeType.updated, todo: todo),
    );
    return todo;
  }

  Future<DeleteTodoResponseDto> deleteById(int id) async {
    final todo = await getById(id);
    final deleted = await (db.delete(
      db.todos,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) {
      throw _todoNotFoundError(id);
    }
    _changes.add(
      TodoChangeResponseDto(type: TodoChangeType.deleted, todo: todo),
    );
    return const DeleteTodoResponseDto();
  }

  TodoResponseDto _toDto(Todo row) {
    return TodoResponseDto(
      id: row.id,
      title: row.title,
      completed: row.completed,
      createdAt: row.createdAt,
    );
  }
}
