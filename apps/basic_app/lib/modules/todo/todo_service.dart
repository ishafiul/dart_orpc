import 'dart:async';

import 'package:dart_orpc/dart_orpc.dart';
import 'package:drift/drift.dart';

import '../../database/app_database.dart';
import 'todo_dtos.dart';

final class TodoService {
  TodoService(this.db);

  final AppDatabase db;
  final StreamController<TodoChangeResponseDto> _changes =
      StreamController<TodoChangeResponseDto>.broadcast(sync: true);

  Stream<TodoChangeResponseDto> watchChanges() => _changes.stream;

  Future<TodoListResponseDto> list() async {
    final rows = await db.select(db.todos).get();
    return TodoListResponseDto(items: [for (final row in rows) _toDto(row)]);
  }

  Future<TodoResponseDto> getById(int id) async {
    final row = await (db.select(
      db.todos,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw RpcException.notFound('Todo $id was not found.');
    }
    return _toDto(row);
  }

  Future<TodoResponseDto> create(String title) async {
    final id = await db
        .into(db.todos)
        .insert(TodosCompanion.insert(title: title));
    final todo = await getById(id);
    _changes.add(TodoChangeResponseDto(type: 'created', todo: todo));
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
      throw RpcException.badRequest('title must not be empty.');
    }
    await (db.update(db.todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        title: title == null ? const Value.absent() : Value(title),
        completed: completed == null ? const Value.absent() : Value(completed),
      ),
    );
    final todo = await getById(id);
    _changes.add(TodoChangeResponseDto(type: 'updated', todo: todo));
    return todo;
  }

  Future<DeleteTodoResponseDto> deleteById(int id) async {
    final todo = await getById(id);
    final deleted = await (db.delete(
      db.todos,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) {
      throw RpcException.notFound('Todo $id was not found.');
    }
    _changes.add(TodoChangeResponseDto(type: 'deleted', todo: todo));
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
