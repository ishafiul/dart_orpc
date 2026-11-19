import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

class NoNullAssertion extends AnalysisRule {
  NoNullAssertion()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_null_assertion',
    'The `!` operator silences a nullability problem instead of fixing it.',
    correctionMessage:
        'Fix the model: make the value non-nullable where it is produced, or '
        'handle the null case explicitly with a pattern or an early return.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans null assertions (`value!`, `case x!`) outside tests.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addPostfixExpression(this, visitor)
      ..addNullAssertPattern(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (context.isProductionSource && node.operator.type == TokenType.BANG) {
      rule.reportAtToken(node.operator);
    }
  }

  @override
  void visitNullAssertPattern(NullAssertPattern node) {
    if (context.isProductionSource) {
      rule.reportAtToken(node.operator);
    }
  }
}
