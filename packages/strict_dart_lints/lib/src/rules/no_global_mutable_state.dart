import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

class NoGlobalMutableState extends AnalysisRule {
  NoGlobalMutableState()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_global_mutable_state',
    'Mutable top-level and static state is shared by everything and owned by '
        'nothing.',
    correctionMessage:
        'Make it `final` or `const`, or move the state into a provider that '
        'is injected where it is needed.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans non-final top-level variables and static fields outside tests.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addTopLevelVariableDeclaration(this, visitor)
      ..addFieldDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _reportIfMutable(node.variables);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic) {
      _reportIfMutable(node.fields);
    }
  }

  void _reportIfMutable(VariableDeclarationList declarations) {
    if (!context.isProductionSource ||
        declarations.isFinal ||
        declarations.isConst) {
      return;
    }
    for (final variable in declarations.variables) {
      rule.reportAtToken(variable.name);
    }
  }
}
