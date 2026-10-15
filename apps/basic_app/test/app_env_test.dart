import 'package:basic_app/environment/app_env.dart';
import 'package:test/test.dart';

void main() {
  test('Given environment strings When parsed Then values are fully typed', () {
    final variables = {
      'JWT_SECRET': 'secret',
      'JWT_ISSUER': 'basic_app',
      'JWT_EXPIRES_IN_SECONDS': '7200',
      'PORT': '4000',
      'DOCS_USERNAME': 'docs',
      'DOCS_PASSWORD': 'password',
      'DOCS_REALM': 'Basic App Docs',
    };
    final env = AppEnv.fromMap(variables);

    expect(env.jwtSecret, isA<String>());
    expect(env.jwtIssuer, 'basic_app');
    expect(env.jwtLifetime, const Duration(hours: 2));
    expect(env.port, 4000);
    expect(env.docsUsername, 'docs');
    expect(env.docsPassword, 'password');
    expect(env.docsRealm, 'Basic App Docs');
  });

  test('Given invalid typed values When parsed Then startup fails', () {
    final variables = {
      'JWT_SECRET': 'secret',
      'JWT_ISSUER': 'basic_app',
      'JWT_EXPIRES_IN_SECONDS': 'not-a-number',
      'PORT': '70000',
      'DOCS_USERNAME': 'docs',
      'DOCS_PASSWORD': 'password',
      'DOCS_REALM': 'Basic App Docs',
    };

    expect(() => AppEnv.fromMap(variables), throwsA(isA<StateError>()));
  });

  test('Given only secrets When parsed Then developer defaults apply', () {
    final env = AppEnv.fromMap({
      'JWT_SECRET': 'secret',
      'DOCS_PASSWORD': 'password',
    });

    expect(env.jwtIssuer, 'basic_app');
    expect(env.jwtLifetime, const Duration(hours: 1));
    expect(env.port, 3000);
    expect(env.docsUsername, 'admin');
    expect(env.docsRealm, 'Basic App Docs');
  });
}
