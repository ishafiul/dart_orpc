import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/orpc_elements.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

class LayerDependencies extends AnalysisRule {
  LayerDependencies()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'layer_dependencies',
    "A {0} may not depend on the {1} '{2}'.",
    correctionMessage:
        'Controllers use services, services use services and repositories, '
        'and repositories use infrastructure from bindings. Move the call '
        'into the layer that may make it.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Enforces controller -> service -> repository layering by role.';

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

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!context.isProductionSource) {
      return;
    }
    final self = node.declaredFragment?.element;
    final role = roleOf(self);
    if (self == null || role == null) {
      return;
    }
    node.accept(_ReferenceChecker(rule, self, role));
  }
}

class _ReferenceChecker extends RecursiveAstVisitor<void> {
  _ReferenceChecker(this.rule, this.self, this.role);

  final AnalysisRule rule;
  final Object self;
  final ProviderRole role;

  @override
  void visitAnnotation(Annotation node) {}

  @override
  void visitNamedType(NamedType node) {
    final referenced = node.element;
    final dependency = roleOf(referenced);
    if (dependency != null &&
        !identical(referenced, self) &&
        !mayDependOn(role, dependency)) {
      rule.reportAtNode(
        node,
        arguments: [role.label, dependency.label, node.name.lexeme],
      );
    }
    super.visitNamedType(node);
  }
}
