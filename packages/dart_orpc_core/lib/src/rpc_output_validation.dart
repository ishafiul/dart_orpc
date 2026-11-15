import 'rpc_validation_issue.dart';

/// Why a procedure's output failed validation, for server diagnostics.
///
/// Attached to the generic `INTERNAL_ERROR` [RpcException] as its
/// `diagnostic`, so it reaches server `onError` hooks but is never sent to
/// clients. It holds the issue paths, codes and messages, not the output
/// payload.
final class RpcOutputValidationDiagnostic {
  RpcOutputValidationDiagnostic({
    required this.method,
    required List<RpcValidationIssue> issues,
  }) : issues = List.unmodifiable(issues);

  /// The RPC method whose output failed.
  final String method;

  /// The validation issues, in validator order.
  final List<RpcValidationIssue> issues;

  @override
  String toString() {
    final described = issues
        .map(
          (issue) => issue.path.isEmpty
              ? issue.message
              : '${issue.path.join('.')}: ${issue.message}',
        )
        .join('; ');
    return 'RpcOutputValidationDiagnostic($method): $described';
  }
}
