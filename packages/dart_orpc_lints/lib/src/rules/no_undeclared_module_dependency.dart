import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/module_boundary.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

class NoUndeclaredModuleDependency extends AnalysisRule {
  NoUndeclaredModuleDependency()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_undeclared_module_dependency',
    "'{0}' is exported by {1}, which {2} does not import.",
    correctionMessage:
        'Add {1} to the @Module(imports: [...]) of {2}, so the module graph '
        'states the dependency the code already has.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Requires a module to import every module whose providers its code uses.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addNamedType(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;
  late final ModuleBoundary? _boundary = ModuleBoundary.of(context);

  @override
  void visitNamedType(NamedType node) {
    if (!context.isProductionSource) {
      return;
    }
    if (_boundary?.crossingFor(node.element) case UndeclaredModuleDependency(
      :final typeName,
      :final owner,
      :final consumer,
    )) {
      rule.reportAtNode(node, arguments: [typeName, owner.name, consumer.name]);
    }
  }
}
