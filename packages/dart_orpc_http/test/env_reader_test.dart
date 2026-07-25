import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  test('When reading mapped values then types and defaults are resolved', () {
    final env = EnvReader.fromMap({
      'SECRET': ' value ',
      'SECONDS': '60',
      'PORT': '4000',
    });

    expect(env.requiredString('SECRET'), 'value');
    expect(env.string('NAME', fallback: 'app'), 'app');
    expect(env.positiveInt('SECONDS', fallback: 30), 60);
    expect(env.port('PORT', fallback: 3000), 4000);
  });

  test(
    'When values are missing or invalid then descriptive errors surface',
    () {
      final env = EnvReader.fromMap({'SECONDS': 'invalid', 'PORT': '70000'});

      expect(() => env.requiredString('SECRET'), throwsA(isA<StateError>()));
      expect(
        () => env.positiveInt('SECONDS', fallback: 30),
        throwsA(isA<StateError>()),
      );
      expect(
        () => env.port('PORT', fallback: 3000),
        throwsA(isA<StateError>()),
      );
    },
  );
}
