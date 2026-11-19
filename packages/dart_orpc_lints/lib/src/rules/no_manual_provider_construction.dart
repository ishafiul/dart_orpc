import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/module_boundary.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

class NoManualProviderConstruction extends AnalysisRule {
  NoManualProviderConstruction()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_manual_provider_construction',
    "'{0}' is a provider; constructing it by hand bypasses dependency "
        'injection and creates a second, unmanaged instance.',
    correctionMessage:
        "Take '{0}' as a constructor parameter and let its module provide it. "
        'Only the provider itself may construct its instances, for example '
        'in a static factory used by RpcProviderBinding.useFactory.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans constructing module providers and controllers outside DI.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;
  late final ModuleBoundary? _boundary = ModuleBoundary.of(context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!context.isProductionSource) {
      return;
    }
    final type = node.constructorName.type;
    final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
    final constructsItself =
        enclosingClass != null &&
        enclosingClass.declaredFragment?.element == type.element;
    if (!constructsItself && (_boundary?.isProvider(type.element) ?? false)) {
      rule.reportAtNode(node.constructorName, arguments: [type.name.lexeme]);
    }
  }
}
