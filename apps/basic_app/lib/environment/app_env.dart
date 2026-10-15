import 'package:dart_orpc/dart_orpc.dart';

final class AppEnv {
  AppEnv._(EnvReader env) {
    jwtSecret = env.string('JWT_SECRET', fallback: 'default_secret');
    jwtIssuer = env.string('JWT_ISSUER', fallback: 'basic_app');
    jwtLifetime = env.duration(
      'JWT_EXPIRES_IN_SECONDS',
      fallback: const Duration(hours: 1),
    );
    port = env.port('PORT', fallback: 3000);
    docsUsername = env.string('DOCS_USERNAME', fallback: 'admin');
    docsPassword = env.string('DOCS_PASSWORD', fallback: 'password');
    docsRealm = env.string('DOCS_REALM', fallback: 'Basic App Docs');
  }

  factory AppEnv.load({String path = '.env'}) =>
      AppEnv._(EnvReader.load(path: path));

  factory AppEnv.fromMap(Map<String, String> values) =>
      AppEnv._(EnvReader.fromMap(values));

  late final String jwtSecret;
  late final String jwtIssuer;
  late final Duration jwtLifetime;
  late final int port;
  late final String docsUsername;
  late final String docsPassword;
  late final String docsRealm;
}

const appEnvKey = RpcContextKey<AppEnv>('basic_app.env');

extension AppEnvRpcContext on RpcContext {
  AppEnv get env => requireBinding(appEnvKey);
}
