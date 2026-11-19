import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

const _exceptionClass = 'Exception';

class NoBroadCatch extends AnalysisRule {
  NoBroadCatch() : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_broad_catch',
    'Catching every error without rethrowing hides failures whose cause '
        'was never understood.',
    correctionMessage:
        'Catch the specific error type you can handle, or rethrow / throw a '
        'typed error after handling.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans catch clauses for Object, Exception or anything that neither '
      'rethrow nor throw.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCatchClause(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitCatchClause(CatchClause node) {
    if (!context.isHandWrittenSource || !_isBroad(node.exceptionType?.type)) {
      return;
    }
    final escapes = _EscapeFinder();
    node.body.accept(escapes);
    if (!escapes.found) {
      rule.reportAtToken(node.onKeyword ?? node.beginToken);
    }
  }

  bool _isBroad(DartType? caught) {
    if (caught == null) {
      return true;
    }
    return caught is DynamicType ||
        caught.isDartCoreObject ||
        _isDartCoreException(caught);
  }

  bool _isDartCoreException(DartType caught) {
    final element = caught.element;
    return element != null &&
        element.name == _exceptionClass &&
        (element.library?.isDartCore ?? false);
  }
}

class _EscapeFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitThrowExpression(ThrowExpression node) {
    found = true;
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    found = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}
}
