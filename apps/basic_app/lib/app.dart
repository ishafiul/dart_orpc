import 'package:basic_app/modules/todo/todo_module.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_module.dart';
import 'package:dart_orpc/dart_orpc.dart';

@Module(imports: [TodoModule, TodoAnalysisModule])
final class AppModule {
  const AppModule();
}
