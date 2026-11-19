import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/module_boundary.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

class NoCrossModuleInternalImport extends AnalysisRule {
  NoCrossModuleInternalImport()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_cross_module_internal_import',
    "'{0}' is internal to {1}: it is not in {1}'s exports.",
    correctionMessage:
        'Depend on a provider that {1} exports. If other modules are meant to '
        "use '{0}', add it to {1}'s @Module(exports: [...]). Controllers are "
        'entry points and are never shared.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      "Bans using another module's controllers and non-exported providers.";

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
    if (_boundary?.crossingFor(node.element)
        case ForeignController(:final typeName, :final owner) ||
            UnexportedProvider(:final typeName, :final owner)) {
      rule.reportAtNode(node, arguments: [typeName, owner.name]);
    }
  }
}
