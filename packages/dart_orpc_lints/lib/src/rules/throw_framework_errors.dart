import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/orpc_elements.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

class ThrowFrameworkErrors extends AnalysisRule {
  ThrowFrameworkErrors()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'throw_framework_errors',
    'Only RpcException reaches clients with a declared error code; anything '
        'else becomes an anonymous internal error.',
    correctionMessage:
        'Throw an RpcException with the code that matches the failure '
        '(RpcException.notFound, .badRequest, .conflict, ...). Throw an Error '
        'subtype only for programming bugs.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Requires thrown values to be RpcException or an Error subtype.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addThrowExpression(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!context.isProductionSource) {
      return;
    }
    final thrown = node.expression.staticType;
    if (thrown == null || thrown.isRpcException || thrown.isDartCoreError) {
      return;
    }
    rule.reportAtNode(node.expression);
  }
}
