import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

const _asyncLibrary = 'dart:async';
const _ioLibrary = 'dart:io';
const _futureClass = 'Future';
const _delayedConstructor = 'delayed';
const _sleepFunction = 'sleep';

class NoDelayAsFix extends AnalysisRule {
  NoDelayAsFix() : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_delay_as_fix',
    'Waiting a fixed time hides an ordering problem and makes behaviour '
        'depend on timing.',
    correctionMessage:
        'Await the event or future the code actually depends on. When waiting '
        'is the intent (retry backoff, rate limit, polling), inject a delay '
        'abstraction such as Delay from dart_orpc, or its RetryPolicy, so '
        'tests can replace real time.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans `Future.delayed` and `sleep` from `dart:io`, including in tests.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addInstanceCreationExpression(this, visitor)
      ..addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructor = node.constructorName.element;
    if (!context.isHandWrittenSource || constructor == null) {
      return;
    }
    if (constructor.name == _delayedConstructor &&
        constructor.enclosingElement.name == _futureClass &&
        _isFrom(constructor, _asyncLibrary)) {
      rule.reportAtNode(node.constructorName);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final function = node.methodName.element;
    if (!context.isHandWrittenSource || function == null) {
      return;
    }
    if (function is TopLevelFunctionElement &&
        function.name == _sleepFunction &&
        _isFrom(function, _ioLibrary)) {
      rule.reportAtNode(node.methodName);
    }
  }

  bool _isFrom(Element element, String libraryUri) =>
      element.library?.uri.toString() == libraryUri;
}
