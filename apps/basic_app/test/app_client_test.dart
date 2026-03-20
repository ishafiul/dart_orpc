import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  test(
    'generated AppClient sends the typed RPC request and decodes the response',
    () async {
      final transport = _RecordingTransport(
        const UserResponseDto(id: '1', name: 'Ada Lovelace').toJson(),
      );
      final client = AppClient(transport: transport);

      final user = await client.user.getById(const GetUserDto(id: '1'));

      expect(transport.lastRequest, isNotNull);
      expect(transport.lastRequest!.method, 'user.getById');
      expect(transport.lastRequest!.input, {'id': '1'});
      expect(user.id, '1');
      expect(user.name, 'Ada Lovelace');
    },
  );

  test(
    'generated AppClient supports zero-input RPC methods without a placeholder DTO',
    () async {
      final transport = _RecordingTransport(
        const UserStatusDto(status: 'ready').toJson(),
      );
      final client = AppClient(transport: transport);

      final status = await client.user.status();

      expect(transport.lastRequest, isNotNull);
      expect(transport.lastRequest!.method, 'user.status');
      expect(transport.lastRequest!.input, isNull);
      expect(status.status, 'ready');
    },
  );
}

final class _RecordingTransport implements RpcTransport {
  _RecordingTransport(this.response);

  final Object? response;
  RpcRequest? lastRequest;

  @override
  Future<Object?> send(RpcRequest request) async {
    lastRequest = request;
    return response;
  }
}
