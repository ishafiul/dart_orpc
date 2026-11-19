import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

class NoUncheckedCast extends AnalysisRule {
  NoUncheckedCast()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_unchecked_cast',
    'An `as` downcast hides a missing type and throws at runtime when wrong.',
    correctionMessage:
        'Give the value its real type at the source, or match it with a '
        'pattern (`if (value case Foo foo)`, `switch`) and handle the '
        'other cases.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans `as` downcasts and cast patterns outside tests.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addAsExpression(this, visitor)
      ..addCastPattern(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitAsExpression(AsExpression node) {
    if (_isDowncast(node.expression.staticType, node.type.type)) {
      rule.reportAtToken(node.asOperator);
    }
  }

  @override
  void visitCastPattern(CastPattern node) {
    if (_isDowncast(node.matchedValueType, node.type.type)) {
      rule.reportAtToken(node.asToken);
    }
  }

  bool _isDowncast(DartType? from, DartType? to) {
    if (!context.isProductionSource || from == null || to == null) {
      return false;
    }
    return !context.typeSystem.isSubtypeOf(from, to);
  }
}
