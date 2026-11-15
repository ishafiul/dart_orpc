import 'json_utils.dart';

/// The `error.details` key that holds framework validation issues.
const rpcValidationIssuesKey = 'issues';

/// One structured validation failure, serialized in `error.details.issues`.
///
/// Every transport and client uses this shape:
///
/// ```json
/// {"path": ["items", 1, "id"], "code": "required", "message": "id is required"}
/// ```
final class RpcValidationIssue {
  /// Creates an issue at [path].
  ///
  /// Throws an [ArgumentError] when a path segment is neither a [String] nor
  /// a non-negative [int].
  RpcValidationIssue({
    required List<Object> path,
    required this.code,
    required this.message,
  }) : path = List.unmodifiable(path) {
    for (final segment in this.path) {
      if (!_isSegment(segment)) {
        throw ArgumentError.value(
          path,
          'path',
          'segments must be strings or non-negative integers',
        );
      }
    }
  }

  /// Where the failure is: string object keys and integer list indexes, or
  /// `[]` for the whole value.
  ///
  /// Each segment is one key, so `["a.b"]` and `["0"]` are single keys, not
  /// a nested path or a list index.
  final List<Object> path;

  /// A machine-readable code, such as `required` or `tooShort`.
  ///
  /// Codes are an open set: new ones can appear, so clients should fall back
  /// to [message] for codes they don't recognize.
  final String code;

  /// A human-readable description of the failure.
  final String message;

  JsonObject toJson() => {'path': path, 'code': code, 'message': message};

  /// Parses one wire entry, or returns `null` when it is not a valid issue.
  ///
  /// Keys other than `path`, `code` and `message` are ignored.
  static RpcValidationIssue? tryParse(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final code = json['code'];
    final message = json['message'];
    if (path is! List || code is! String || message is! String) return null;
    if (!path.every(_isSegment)) return null;
    return RpcValidationIssue(
      path: path.cast<Object>(),
      code: code,
      message: message,
    );
  }

  static bool _isSegment(Object? segment) =>
      segment is String || (segment is int && segment >= 0);

  @override
  bool operator ==(Object other) =>
      other is RpcValidationIssue &&
      other.code == code &&
      other.message == message &&
      _pathEquals(other.path, path);

  @override
  int get hashCode => Object.hash(Object.hashAll(path), code, message);

  @override
  String toString() =>
      'RpcValidationIssue(path: $path, code: $code, message: $message)';
}

/// `error.details` carrying [issues] in order under
/// [rpcValidationIssuesKey].
JsonObject rpcValidationIssueDetails(Iterable<RpcValidationIssue> issues) => {
  rpcValidationIssuesKey: [for (final issue in issues) issue.toJson()],
};

/// The valid issues in [details], in wire order.
///
/// Malformed entries are skipped. Absent details, a missing or non-list
/// `issues` value, or an empty list give an empty result. The returned list
/// is unmodifiable.
List<RpcValidationIssue> parseRpcValidationIssues(
  Map<String, Object?>? details,
) {
  final issues = details?[rpcValidationIssuesKey];
  if (issues is! List) return const [];
  return List.unmodifiable([
    for (final entry in issues) ?RpcValidationIssue.tryParse(entry),
  ]);
}

bool _pathEquals(List<Object> left, List<Object> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    final a = left[index];
    final b = right[index];
    // "0" and 0 are different segments: a key and a list index.
    if (a.runtimeType != b.runtimeType || a != b) return false;
  }
  return true;
}
