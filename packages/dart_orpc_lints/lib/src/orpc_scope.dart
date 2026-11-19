import 'dart:math';

import 'package:analyzer/analysis_rule/rule_context.dart';

const _generatedSuffixes = [
  '.g.dart',
  '.orpc.dart',
  '.freezed.dart',
  '.gr.dart',
  '.mocks.dart',
  '.config.dart',
];
const _generatedMarker = 'GENERATED CODE';
const _headerLength = 600;

extension OrpcScope on RuleContext {
  bool get isGeneratedSource {
    final unit = currentUnit;
    if (unit == null) {
      return false;
    }
    if (_generatedSuffixes.any(unit.file.path.endsWith)) {
      return true;
    }
    final content = unit.content;
    return content
        .substring(0, min(content.length, _headerLength))
        .contains(_generatedMarker);
  }

  bool get isProductionSource => !isInTestDirectory && !isGeneratedSource;
}
