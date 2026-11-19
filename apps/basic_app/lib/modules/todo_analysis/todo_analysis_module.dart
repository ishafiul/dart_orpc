import 'package:basic_app/modules/todo/todo_module.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_controller.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

@Module(
  imports: [TodoModule],
  controllers: [TodoAnalysisController],
  providers: [TodoAnalysisService],
)
final class TodoAnalysisModule {
  const TodoAnalysisModule();
}
