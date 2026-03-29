import 'package:basic_app/guard/permission_guard.dart';
import 'package:dart_orpc/dart_orpc.dart';

import '../../database/app_database.dart';
import '../../guard/logger_guard.dart';
import 'todo_controller.dart';
import 'todo_service.dart';

@Module(
  controllers: [TodoController],
  providers: [
    AppDatabase,
    TodoService,
    TodoRouteLoggerGuard,
    TodoPermissionGuard,
  ],
  exports: [TodoService],
)
final class TodoModule {
  const TodoModule();
}
