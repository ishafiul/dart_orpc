import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  final diagnostic = RpcOutputValidationDiagnostic(
    method: 'todo.getById',
    issues: [
      RpcValidationIssue(
        path: ['title'],
        code: 'tooShort',
        message: 'title must be at least 1 character long',
      ),
    ],
  );

  group('Given an output validation diagnostic', () {
    test('When read then it names the procedure and its issues', () {
      expect(diagnostic.method, 'todo.getById');
      expect(diagnostic.issues.single.path, ['title']);
      expect(
        () => diagnostic.issues.add(diagnostic.issues.single),
        throwsUnsupportedError,
      );
    });

    test('When printed then it shows each issue path and message', () {
      expect(
        diagnostic.toString(),
        'RpcOutputValidationDiagnostic(todo.getById): '
        'title: title must be at least 1 character long',
      );
    });
  });

  group('Given an RpcException with a server diagnostic', () {
    final exception = RpcException(
      code: RpcErrorCode.internalError,
      message: 'Internal server error.',
      diagnostic: diagnostic,
    );

    test('When encoded then the wire envelope has no trace of it', () {
      final expected = {
        'error': {
          'code': 'INTERNAL_ERROR',
          'message': 'Internal server error.',
        },
      };

      expect(encodeRpcError(exception).json, expected);
      expect(exception.toResponse().toJson(), expected);
      expect(exception.details, isNull);
    });

    test('When printed for server logs then the diagnostic is included', () {
      expect(
        exception.toString(),
        'RpcException(INTERNAL_ERROR): Internal server error. '
        '[$diagnostic]',
      );
    });

    test('When it has no diagnostic then it prints as before', () {
      expect(
        RpcException.internalError().toString(),
        'RpcException(INTERNAL_ERROR): Internal server error.',
      );
      expect(RpcException.internalError().diagnostic, isNull);
    });

    test('When built with the constructor then the diagnostic is kept', () {
      expect(
        RpcException(
          code: RpcErrorCode.internalError,
          message: 'Internal server error.',
          diagnostic: diagnostic,
        ).diagnostic,
        same(diagnostic),
      );
    });
  });
}
