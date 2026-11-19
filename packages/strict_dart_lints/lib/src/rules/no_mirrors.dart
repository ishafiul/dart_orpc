import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

const _mirrorsLibrary = 'dart:mirrors';

class NoMirrors extends AnalysisRule {
  NoMirrors() : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_mirrors',
    '`dart:mirrors` is runtime reflection; behaviour must be known at '
        'compile time.',
    correctionMessage:
        'Generate the code with build_runner, or pass the behaviour in '
        'explicitly through a typed API.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description = 'Bans importing `dart:mirrors`.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addImportDirective(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitImportDirective(ImportDirective node) {
    if (node.uri.stringValue == _mirrorsLibrary) {
      rule.reportAtNode(node.uri);
    }
  }
}
