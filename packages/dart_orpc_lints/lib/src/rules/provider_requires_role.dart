import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/orpc_elements.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

const _moduleAnnotation = 'Module';
const _providersArgument = 'providers';
const _annotationsLibraryPrefix = 'package:dart_orpc_annotations/';

class ProviderRequiresRole extends AnalysisRule {
  ProviderRequiresRole()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'provider_requires_role',
    "'{0}' is listed in providers but does not declare its role.",
    correctionMessage:
        "Annotate '{0}' with @Service() or @Repository(), or implement "
        'RpcGuard for a guard. Controllers belong in controllers, and '
        'third-party or infrastructure types in bindings.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Requires every class in @Module(providers:) to declare its role.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addAnnotation(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitAnnotation(Annotation node) {
    if (!context.isProductionSource || !_isModuleAnnotation(node)) {
      return;
    }
    final providers = node.arguments?.arguments
        .whereType<NamedArgument>()
        .where((argument) => argument.name.lexeme == _providersArgument)
        .map((argument) => argument.argumentExpression)
        .whereType<ListLiteral>()
        .firstOrNull;
    for (final entry in providers?.elements ?? const <CollectionElement>[]) {
      final (element, name) = switch (entry) {
        TypeLiteral(:final type) => (type.element, type.name.lexeme),
        SimpleIdentifier(:final element, :final name) => (element, name),
        _ => (null, null),
      };
      if (name == null) {
        continue;
      }
      final role = roleOf(element);
      if (role == null || role == ProviderRole.controller) {
        rule.reportAtNode(entry, arguments: [name]);
      }
    }
  }

  bool _isModuleAnnotation(Annotation node) {
    final element = node.element;
    return element is ConstructorElement &&
        element.enclosingElement.name == _moduleAnnotation &&
        isDeclaredUnder(element, _annotationsLibraryPrefix);
  }
}
