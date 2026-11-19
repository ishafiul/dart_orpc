import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_orpc_lints/src/orpc_elements.dart';
import 'package:dart_orpc_lints/src/orpc_scope.dart';

class ControllerNoLogic extends AnalysisRule {
  ControllerNoLogic()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'controller_no_logic',
    'Controllers only map a procedure to a service call; loops, error '
        'handling and I/O here are business logic in the wrong layer.',
    correctionMessage:
        'Move this into a service method and call it from the controller. '
        'Errors are mapped centrally, so controllers need no try/catch.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans loops, try statements and dart:io inside @Controller classes.';

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
    if (context.isProductionSource && node.isOrpcController) {
      node.body.accept(_LogicFinder(rule));
    }
  }
}

class _LogicFinder extends RecursiveAstVisitor<void> {
  _LogicFinder(this.rule);

  final AnalysisRule rule;

  @override
  void visitForStatement(ForStatement node) {
    rule.reportAtToken(node.forKeyword);
    super.visitForStatement(node);
  }

  @override
  void visitForElement(ForElement node) {
    rule.reportAtToken(node.forKeyword);
    super.visitForElement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    rule.reportAtToken(node.whileKeyword);
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    rule.reportAtToken(node.doKeyword);
    super.visitDoStatement(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    rule.reportAtToken(node.tryKeyword);
    super.visitTryStatement(node);
  }

  @override
  void visitNamedType(NamedType node) {
    if (_isFromIo(node.element)) {
      rule.reportAtNode(node);
    }
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_isFromIo(node.element)) {
      rule.reportAtNode(node);
    }
    super.visitSimpleIdentifier(node);
  }

  bool _isFromIo(Element? element) => isIoElement(element);
}
