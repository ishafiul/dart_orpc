import 'package:test/test.dart';

import 'support/generator_test_harness.dart';

void main() {
  group('Generated dependency ordering compatibility', () {
    test(
      'newly ready providers retain optional injection and disposal order',
      () async {
        final run = await runModuleBuilder(
          _source('First, Second, Consumer, Gap'),
        );
        expect(run.succeeded, isTrue, reason: run.errors.join('\n'));
        final output = run.generatedOutput;
        expect(output, contains('final second = Second(first);'));
        expect(output, contains('final consumer = Consumer(second: second);'));
        expect(output, contains('final gap = Gap();'));
        expect(
          output.indexOf('final second = Second(first);'),
          lessThan(output.indexOf('final consumer = Consumer(')),
        );
        expect(
          output,
          matches(
            RegExp(
              r'disposeRpcProviders\(\[\s*gap,\s*consumer,\s*second,\s*first\s*,?\s*\]\)',
            ),
          ),
        );
      },
    );

    test(
      'optional dependencies are not promoted into required ordering edges',
      () async {
        final run = await runModuleBuilder(
          _source('Consumer, Second, First, Gap'),
        );
        expect(run.succeeded, isTrue, reason: run.errors.join('\n'));
        expect(run.generatedOutput, contains('final consumer = Consumer();'));
        expect(run.generatedOutput, contains('final second = Second(first);'));
        expect(run.generatedOutput, contains('final gap = Gap();'));
      },
    );

    test('optional cycles do not prevent provider construction', () async {
      final run = await runModuleBuilder('''
import 'package:dart_orpc/dart_orpc.dart';
final class First { First({Second? second}); }
final class Second { Second({First? first}); }
@Module(providers: [First, Second])
final class AppModule { const AppModule(); }
''');
      expect(run.succeeded, isTrue, reason: run.errors.join('\n'));
      expect(run.generatedOutput, contains('final first = First();'));
      expect(
        run.generatedOutput,
        contains('final second = Second(first: first);'),
      );
    });
  });
}

String _source(String providers) =>
    '''
import 'package:dart_orpc/dart_orpc.dart';
final class First {}
final class Second { Second(First first); }
final class Consumer { Consumer({Second? second}); }
final class Missing {}
final class Gap { Gap([Missing? missing, First? first]); }
@Module(providers: [$providers])
final class AppModule { const AppModule(); }
''';
