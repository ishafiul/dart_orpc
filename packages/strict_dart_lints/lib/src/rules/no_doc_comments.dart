import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/comment_tokens.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

class NoDocComments extends AnalysisRule {
  NoDocComments() : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_doc_comments',
    'Doc comments are not allowed in application code.',
    correctionMessage:
        'Make the declaration self-explanatory through its name, its types '
        'and its structure. Doc comments belong only on the public API of '
        'published library packages.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans `///` and `/** */` doc comments; enable it for applications.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    if (!context.isHandWrittenSource) {
      return;
    }
    commentTokensOf(
      node,
    ).where((comment) => comment.isDocComment).forEach(rule.reportAtToken);
  }
}
