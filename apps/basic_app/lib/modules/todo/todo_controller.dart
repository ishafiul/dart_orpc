import 'package:dart_orpc/dart_orpc.dart';

import 'todo_dtos.dart';
import 'todo_route_logger_guard.dart';
import 'todo_service.dart';

@UseGuards([TodoRouteLoggerGuard])
@Controller('todo')
final class TodoController {
  TodoController(this.todoService);

  final TodoService todoService;

  @RpcMethod(
    name: 'list',
    path: RestMapping.get('/todos'),
    description: 'List all todos.',
    tags: ['todo'],
  )
  Future<TodoListResponseDto> list(RpcContext _) {
    return todoService.list();
  }

  @RpcMethod(
    name: 'getById',
    path: RestMapping.get('/todos/:id'),
    description: 'Get a single todo by id.',
    tags: ['todo'],
  )
  Future<TodoResponseDto> getById(
    RpcContext _,
    @RpcInput() GetTodoDto input,
  ) {
    return todoService.getById(input.id);
  }

  @RpcMethod(
    name: 'create',
    path: RestMapping.post('/todos'),
    description: 'Create a todo.',
    tags: ['todo'],
  )
  Future<TodoResponseDto> create(
    RpcContext _,
    @RpcInput() CreateTodoDto input,
  ) {
    return todoService.create(input.title);
  }

  @RpcMethod(
    name: 'update',
    path: RestMapping.patch('/todos/:id'),
    description: 'Update a todo.',
    tags: ['todo'],
  )
  Future<TodoResponseDto> update(
    RpcContext _,
    @RpcInput() UpdateTodoDto input,
  ) {
    return todoService.update(
      id: input.id,
      title: input.title,
      completed: input.completed,
    );
  }

  @RpcMethod(
    name: 'delete',
    path: RestMapping.delete('/todos/:id'),
    description: 'Delete a todo.',
    tags: ['todo'],
  )
  Future<DeleteTodoResponseDto> delete(
    RpcContext _,
    @RpcInput() GetTodoDto input,
  ) {
    return todoService.deleteById(input.id);
  }
}
