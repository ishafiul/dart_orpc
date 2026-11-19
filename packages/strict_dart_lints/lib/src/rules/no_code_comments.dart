import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:strict_dart_lints/src/comment_tokens.dart';
import 'package:strict_dart_lints/src/rule_scope.dart';

const _allowedCommentPatterns = [
  r'^//\s*ignore(_for_file)?:',
  r'^//\s*TODO\(#\d+\):?\s+\S',
  r'^//\s*coverage:ignore-(line|start|end|file)\s*$',
];

class NoCodeComments extends AnalysisRule {
  NoCodeComments() : super(name: code.lowerCaseName, description: _description);

  static const LintCode code = LintCode(
    'no_code_comments',
    'Code comments are not allowed: they go stale and get read as '
        'justification for wrong behaviour.',
    correctionMessage:
        'Say it in code: a clearer name, a type, or a smaller well-named '
        'function. Only `// ignore: rule -- reason`, `// TODO(#issue) text` '
        'and coverage markers are allowed.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _description =
      'Bans `//` and `/* */` comments except machine-read markers.';

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  static final List<RegExp> _allowed = [
    for (final pattern in _allowedCommentPatterns) RegExp(pattern),
  ];

  @override
  void visitCompilationUnit(CompilationUnit node) {
    if (!context.isHandWrittenSource) {
      return;
    }
    for (final comment in commentTokensOf(node)) {
      if (comment.isDocComment) {
        continue;
      }
      if (_allowed.any((pattern) => pattern.hasMatch(comment.lexeme))) {
        continue;
      }
      rule.reportAtToken(comment);
    }
  }
}
