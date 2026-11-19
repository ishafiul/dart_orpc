import 'package:basic_app/guard/jwt_auth_guard.dart';
import 'package:basic_app/guard/logger_guard.dart';
import 'package:basic_app/guard/permission_guard.dart';
import 'package:basic_app/modules/todo/todo_controller.dart';
import 'package:basic_app/modules/todo/todo_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

@Module(
  controllers: [TodoController],
  providers: [
    TodoService,
    BasicAppJwtAuthGuard,
    TodoRouteLoggerGuard,
    TodoPermissionGuard,
  ],
  exports: [TodoService],
)
final class TodoModule {
  const TodoModule();
}
