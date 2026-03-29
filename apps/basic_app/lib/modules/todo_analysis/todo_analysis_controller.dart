import 'package:dart_orpc/dart_orpc.dart';

import 'todo_analysis_dtos.dart';
import 'todo_analysis_service.dart';

@Controller('todoAnalysis')
final class TodoAnalysisController {
  TodoAnalysisController(this.todoAnalysisService);

  final TodoAnalysisService todoAnalysisService;

  @RpcMethod(
    name: 'summary',
    path: RestMapping.get('/todos/analysis/summary'),
    description: 'Aggregate todo counts and completion rate.',
    tags: ['analysis'],
  )
  Future<TodoAnalysisSummaryDto> summary(RpcContext _) {
    return todoAnalysisService.summary();
  }
}
