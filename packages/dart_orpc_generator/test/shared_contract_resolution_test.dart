import 'package:test/test.dart';

import 'support/generator_test_harness.dart';

void main() {
  group('Shared DTO and route resolution', () {
    test(
      'field references keep constructor fallback separate from REST merging',
      () async {
        final run = await runModuleBuilder(_source);
        expect(run.succeeded, isTrue, reason: run.errors.join('\n'));
        expect(run.generatedFieldRefs, contains("RpcInputField<Input>('id')"));
        expect(
          run.generatedFieldRefs,
          isNot(contains("RpcInputField<Input>('filter')")),
        );
        expect(run.generatedOutput, contains("wireName: 'filter'"));
        expect(run.generatedOutput, contains("path: '/items/:itemId/'"));
        expect(run.generatedOutput, contains("wireName: 'itemId'"));
        expect(
          run.generatedOutput,
          contains('source: ProcedureParameterSourceKind.query'),
        );
      },
    );

    test(
      'annotations on a member and constructor still report source conflicts',
      () async {
        final run = await runModuleBuilder(
          _source.replaceFirst(
            '@FromPath(\'itemId\') this.id',
            '@FromQuery() this.id',
          ),
        );
        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains('conflicting source annotations for DTO field "id"'),
        );
      },
    );

    test(
      'explicit path parameters use the same parsed route as DTO bindings',
      () async {
        final run = await runModuleBuilder('''
import 'package:dart_orpc/dart_orpc.dart';
@Controller('item')
final class ItemController {
  @RpcMethod(path: RestMapping.get('items/:itemId/'))
  int get(@PathParam('itemId') int id) => id;
}
@Module(controllers: [ItemController])
final class AppModule { const AppModule(); }
''');
        expect(run.succeeded, isTrue, reason: run.errors.join('\n'));
        expect(run.generatedOutput, contains("path: '/items/:itemId/'"));
        expect(run.generatedOutput, contains("name: 'itemId'"));
      },
    );

    test(
      'renamed parameters and trailing slash still collide across procedures',
      () async {
        final run = await runModuleBuilder('''
import 'package:dart_orpc/dart_orpc.dart';
@Controller('item')
final class ItemController {
  @RpcMethod(path: RestMapping.get('items/:id'))
  int first(@PathParam() int id) => id;
  @RpcMethod(path: RestMapping.get('/items/:other/'))
  int second(@PathParam() int other) => other;
}
@Module(controllers: [ItemController])
final class AppModule { const AppModule(); }
''');
        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains('duplicate REST route "GET /items/:"'),
        );
      },
    );
  });
}

const _source = r'''
import 'package:dart_orpc/dart_orpc.dart';

class Input {
  Input(@FromPath('itemId') this.id, @FromQuery() String? filter);
  @FromPath('itemId')
  final int id;
  factory Input.fromJson(Map<String, dynamic> json) =>
      Input(json['id'] as int, json['filter'] as String?);
  Map<String, dynamic> toJson() => {'id': id};
}

@Controller('item')
class ItemController {
  @RpcMethod(path: RestMapping.get('items/:itemId/'))
  int get(@RpcInput() Input input) => input.id;
}

@Module(controllers: [ItemController])
class AppModule { const AppModule(); }
''';
