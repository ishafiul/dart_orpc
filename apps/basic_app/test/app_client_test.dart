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
