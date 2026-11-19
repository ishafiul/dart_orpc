import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

const _lineDocPrefix = '///';
const _blockDocPrefix = '/**';

Iterable<Token> commentTokensOf(CompilationUnit unit) sync* {
  Token? token = unit.beginToken;
  while (token != null) {
    Token? comment = token.precedingComments;
    while (comment != null) {
      yield comment;
      comment = comment.next;
    }
    if (token.isEof) {
      return;
    }
    token = token.next;
  }
}

extension CommentTokenKind on Token {
  bool get isDocComment =>
      lexeme.startsWith(_lineDocPrefix) || lexeme.startsWith(_blockDocPrefix);
}
