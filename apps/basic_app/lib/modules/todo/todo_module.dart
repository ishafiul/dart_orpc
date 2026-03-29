import 'package:dart_orpc/dart_orpc.dart';

import '../../database/app_database.dart';
import 'todo_controller.dart';
import 'todo_route_logger_guard.dart';
import 'todo_service.dart';

@Module(
  controllers: [TodoController],
  providers: [AppDatabase, TodoService, TodoRouteLoggerGuard],
  exports: [TodoService],
)
final class TodoModule {
  const TodoModule();
}
