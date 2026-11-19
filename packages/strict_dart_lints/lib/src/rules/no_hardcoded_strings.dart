import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

class NoHardcodedStrings extends AnalysisRule {
  NoHardcodedStrings()
    : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_hardcoded_strings',
    'String literals in executable code are hidden contracts that drift and '
        'get duplicated.',
    correctionMessage:
        'Move the value to a named `const`, an enum, or typed configuration, '
        'and reference it by name. Text built from values belongs in a named '
        'function whose body is the string, such as `String notFound(int id)`.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Requires string literals to live in constant declarations, named '
      'message builders, annotations or patterns outside tests.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addSimpleStringLiteral(this, visitor)
      ..addStringInterpolation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.value.isNotEmpty && _isHardcoded(node)) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    final hasText = node.elements.whereType<InterpolationString>().any(
      (part) => part.value.trim().isNotEmpty,
    );
    if (hasText && _isHardcoded(node)) {
      rule.reportAtNode(node);
    }
  }

  bool _isHardcoded(StringLiteral node) {
    if (!context.isProductionSource ||
        node.inConstantContext ||
        _isNamedMessageBuilderBody(node)) {
      return false;
    }
    var ancestor = node.parent;
    while (ancestor != null) {
      if (ancestor is Annotation ||
          ancestor is Directive ||
          ancestor is DartPattern ||
          ancestor is FormalParameterDefaultClause) {
        return false;
      }
      ancestor = ancestor.parent;
    }
    return true;
  }

  bool _isNamedMessageBuilderBody(StringLiteral node) {
    final whole = switch (node.parent) {
      final AdjacentStrings adjacent => adjacent,
      _ => node,
    };
    final body = whole.parent;
    if (body is! ExpressionFunctionBody) {
      return false;
    }
    final owner = body.parent;
    return owner is MethodDeclaration ||
        (owner is FunctionExpression && owner.parent is FunctionDeclaration);
  }
}
