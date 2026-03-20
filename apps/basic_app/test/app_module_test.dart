import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  test(
    'generated module registry dispatches the annotated RPC method',
    () async {
      final app = buildBasicApp();

      final response = await app.procedures.dispatch(
        const RpcContext(headers: {}),
        const RpcRequest(method: 'user.getById', input: {'id': '1'}),
      );

      expect(response, {'id': '1', 'name': 'Ada Lovelace'});
    },
  );
}
