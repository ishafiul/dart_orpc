import 'package:basic_app/modules/auth/auth_module.dart';
import 'package:basic_app/modules/todo/todo_module.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_module.dart';
import 'package:dart_orpc/dart_orpc.dart';

@Module(imports: [AuthModule, TodoModule, TodoAnalysisModule])
final class AppModule {
  const AppModule();
}
