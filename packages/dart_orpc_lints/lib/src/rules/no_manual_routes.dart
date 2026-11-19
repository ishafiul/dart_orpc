import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/orpc_elements.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

const _httpServerClass = 'HttpServer';
const _rustHttpLibraryPrefix = 'package:rust_http/';

class NoManualRoutes extends AnalysisRule {
  NoManualRoutes() : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_manual_routes',
    'A hand-run HttpServer creates routes that RPC, REST, OpenAPI and the '
        'generated client do not know about.',
    correctionMessage:
        'Declare the endpoint as an @RpcMethod on a @Controller (with a '
        'RestMapping for REST), and serve it with buildRpcApp().listen().',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans using HttpServer directly instead of controllers.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addNamedType(this, visitor)
      ..addSimpleIdentifier(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitNamedType(NamedType node) {
    if (_isHttpServer(node.element)) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_isHttpServer(node.element)) {
      rule.reportAtNode(node);
    }
  }

  bool _isHttpServer(Element? element) =>
      context.isProductionSource &&
      element is InterfaceElement &&
      element.name == _httpServerClass &&
      (isIoElement(element) ||
          isDeclaredUnder(element, _rustHttpLibraryPrefix));
}
