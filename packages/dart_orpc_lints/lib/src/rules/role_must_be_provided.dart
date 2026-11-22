import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/module_boundary.dart';
import 'package:dart_orpc_lints/src/orpc_elements.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

class RoleMustBeProvided extends AnalysisRule {
  RoleMustBeProvided()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'role_must_be_provided',
    "{0} '{1}' is not provided by {2}.",
    correctionMessage:
        "Add '{1}' to @Module(providers: [...]) of {2}. A {0} that no "
        'module provides cannot be injected, and constructing it by hand '
        'creates an unmanaged instance.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _noOwner = 'the module that owns its folder (none found)';

  static const _description =
      'Requires every @Service and @Repository to be provided by the module '
      'that owns its folder.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;
  late final ModuleBoundary? _boundary = ModuleBoundary.of(context);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!context.isProductionSource) {
      return;
    }
    final role = roleOf(node.declaredFragment?.element);
    if (role != ProviderRole.service && role != ProviderRole.repository) {
      return;
    }
    final name = node.className;
    final owner = _boundary?.currentModule;
    if (owner == null) {
      rule.reportAtToken(
        node.namePart.typeName,
        arguments: [role?.label ?? '', name, RoleMustBeProvided._noOwner],
      );
      return;
    }
    if (!owner.providers.contains(name)) {
      rule.reportAtToken(
        node.namePart.typeName,
        arguments: [role?.label ?? '', name, owner.name],
      );
    }
  }
}
