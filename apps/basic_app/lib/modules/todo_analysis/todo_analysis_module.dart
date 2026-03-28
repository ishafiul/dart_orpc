import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/modules/todo/todo_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

import 'todo_analysis_controller.dart';
import 'todo_analysis_service.dart';

@Module(
  controllers: [TodoAnalysisController],
  providers: [TodoAnalysisService, AppDatabase, TodoService],
)
final class TodoAnalysisModule {
  const TodoAnalysisModule();
}
