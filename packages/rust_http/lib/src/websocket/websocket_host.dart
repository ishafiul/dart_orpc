import '../protocol/kinds.dart';

/// What a WebSocket needs from its server.
abstract interface class WebSocketHost {
  /// Picks the id of a new WebSocket.
  int nextWebSocketId();

  /// Registers [socket] under [id], to receive its records.
  void registerWebSocket(int id, WebSocketReceiver socket);

  /// Forgets the WebSocket [id].
  void unregisterWebSocket(int id);

  /// Queues a record for the engine: an accept for a request, or a message
  /// for a WebSocket.
  void sendWebSocketRecord(
    int id,
    OutboundKind kind,
    int status,
    List<int> body, {
    String? protocol,
  });
}

/// Receives the records of one WebSocket.
abstract interface class WebSocketReceiver {
  /// A message ([InboundKind.webSocketText] or
  /// [InboundKind.webSocketBinary]) or the close.
  void receive(InboundKind kind, int closeCode, List<int> payload);

  /// The server stopped: the socket is closed abnormally.
  void serverClosed();
}
