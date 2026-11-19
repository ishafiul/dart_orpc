import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

class NoLateWithoutInitializer extends AnalysisRule {
  NoLateWithoutInitializer()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_late_without_initializer',
    '`late` without an initializer moves an initialization-order bug from '
        'compile time to runtime.',
    correctionMessage:
        'Initialize the value through the constructor (constructor '
        'injection), or give `late` a lazy initializer.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans `late` variables and fields without an initializer outside tests.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addVariableDeclarationList(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    if (!context.isProductionSource || node.lateKeyword == null) {
      return;
    }
    for (final variable in node.variables) {
      if (variable.initializer == null) {
        rule.reportAtToken(variable.name);
      }
    }
  }
}
