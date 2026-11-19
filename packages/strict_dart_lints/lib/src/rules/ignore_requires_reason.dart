import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/comment_tokens.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

const _ignorePattern = r'^//\s*ignore(_for_file)?:';
const _reasonedIgnorePattern =
    r'^//\s*ignore(_for_file)?:\s*[\w/]+(\s*,\s*[\w/]+)*\s+--\s+\S.{9,}$';

class IgnoreRequiresReason extends AnalysisRule {
  IgnoreRequiresReason()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'ignore_requires_reason',
    'An ignore comment must state why the rule cannot be satisfied.',
    correctionMessage:
        'Fix the root cause instead. If the rule truly cannot apply, write '
        '`// ignore: rule_name -- reason of at least ten characters`.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Requires `// ignore:` and `// ignore_for_file:` to carry a reason.';

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

  static final _ignore = RegExp(_ignorePattern);
  static final _reasonedIgnore = RegExp(_reasonedIgnorePattern);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    if (!context.isHandWrittenSource) {
      return;
    }
    for (final comment in commentTokensOf(node)) {
      final text = comment.lexeme.trimRight();
      if (_ignore.hasMatch(text) && !_reasonedIgnore.hasMatch(text)) {
        rule.reportAtToken(comment);
      }
    }
  }
}
