/// A JSON value that can write its UTF-8 representation without an
/// intermediate JSON object or string.
abstract interface class RpcJsonBytes {
  /// Returns this value encoded as a complete UTF-8 JSON value.
  List<int> toJsonBytes();
}
