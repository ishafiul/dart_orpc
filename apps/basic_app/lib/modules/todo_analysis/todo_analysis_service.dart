import '../todo/todo_service.dart';
import 'todo_analysis_dtos.dart';

final class TodoAnalysisService {
  TodoAnalysisService(this.todoService);

  final TodoService todoService;

  Future<TodoAnalysisSummaryDto> summary() async {
    final list = await todoService.list();
    final items = list.items;
    final total = items.length;
    final completed = items.where((t) => t.completed).length;
    final pending = total - completed;
    final completionRate = total == 0 ? 0.0 : completed / total;
    return TodoAnalysisSummaryDto(
      total: total,
      completed: completed,
      pending: pending,
      completionRate: completionRate,
    );
  }
}
