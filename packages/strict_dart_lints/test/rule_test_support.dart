import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart';

const _analyzerTodoCode = 'todo';
const _uriDoesNotExistCode = 'uri_does_not_exist';

mixin LintLocator on AnalysisRuleTest {
  ExpectedDiagnostic lintOn(
    String content,
    String target, {
    int skip = 0,
    int? length,
  }) => lint(_offsetOf(content, target, skip), length ?? target.length);

  ExpectedDiagnostic analyzerTodoOn(String content, String todoText) => lint(
    _offsetOf(content, todoText, 0),
    todoText.length,
    name: _analyzerTodoCode,
  );

  ExpectedDiagnostic missingMockLibraryOn(String content, String uri) =>
      lint(_offsetOf(content, uri, 0), uri.length, name: _uriDoesNotExistCode);

  String writeTestDirectoryFile(String content) => newFile(
    convertPath('$testPackageRootPath/test/sample_test.dart'),
    content,
  ).path;

  int _offsetOf(String content, String target, int skip) {
    var offset = content.indexOf(target);
    for (var remaining = skip; remaining > 0; remaining--) {
      offset = content.indexOf(target, offset + target.length);
    }
    return offset;
  }
}
