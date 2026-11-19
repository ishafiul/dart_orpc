import 'package:dart_orpc/dart_orpc.dart';

const _jwtSecretKey = 'JWT_SECRET';
const _jwtIssuerKey = 'JWT_ISSUER';
const _jwtLifetimeKey = 'JWT_EXPIRES_IN_SECONDS';
const _portKey = 'PORT';
const _docsUsernameKey = 'DOCS_USERNAME';
const _docsPasswordKey = 'DOCS_PASSWORD';
const _docsRealmKey = 'DOCS_REALM';

const _defaultJwtSecret = 'default_secret';
const _defaultJwtIssuer = 'basic_app';
const _defaultJwtLifetime = Duration(hours: 1);
const _defaultPort = 3000;
const _defaultDocsUsername = 'admin';
const _defaultDocsPassword = 'password';
const _defaultDocsRealm = 'Basic App Docs';
const _defaultEnvFile = '.env';

final class AppEnv {
  const AppEnv._({
    required this.jwtSecret,
    required this.jwtIssuer,
    required this.jwtLifetime,
    required this.port,
    required this.docsUsername,
    required this.docsPassword,
    required this.docsRealm,
  });

  factory AppEnv._read(EnvReader env) => AppEnv._(
    jwtSecret: env.string(_jwtSecretKey, fallback: _defaultJwtSecret),
    jwtIssuer: env.string(_jwtIssuerKey, fallback: _defaultJwtIssuer),
    jwtLifetime: env.duration(_jwtLifetimeKey, fallback: _defaultJwtLifetime),
    port: env.port(_portKey, fallback: _defaultPort),
    docsUsername: env.string(_docsUsernameKey, fallback: _defaultDocsUsername),
    docsPassword: env.string(_docsPasswordKey, fallback: _defaultDocsPassword),
    docsRealm: env.string(_docsRealmKey, fallback: _defaultDocsRealm),
  );

  factory AppEnv.load({String path = _defaultEnvFile}) =>
      AppEnv._read(EnvReader.load(path: path));

  factory AppEnv.fromMap(Map<String, String> values) =>
      AppEnv._read(EnvReader.fromMap(values));

  final String jwtSecret;
  final String jwtIssuer;
  final Duration jwtLifetime;
  final int port;
  final String docsUsername;
  final String docsPassword;
  final String docsRealm;
}

const appEnvKey = RpcContextKey<AppEnv>('basic_app.env');

extension AppEnvRpcContext on RpcContext {
  AppEnv get env => requireBinding(appEnvKey);
}
