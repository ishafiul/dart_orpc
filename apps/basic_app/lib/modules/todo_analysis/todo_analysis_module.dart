import 'package:basic_app/modules/todo/todo_module.dart';
import 'package:dart_orpc/dart_orpc.dart';

import 'todo_analysis_controller.dart';
import 'todo_analysis_service.dart';

@Module(
  imports: [TodoModule],
  controllers: [TodoAnalysisController],
  providers: [TodoAnalysisService],
)
final class TodoAnalysisModule {
  const TodoAnalysisModule();
}
