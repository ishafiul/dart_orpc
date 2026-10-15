import 'dart:io';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/database/database_open.dart';
import 'package:basic_app/environment/app_env.dart';
import 'package:basic_app/modules/auth/auth_dtos.dart';
import 'package:basic_app/modules/auth/auth_service.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  const secret = 'test-secret-that-is-not-used-in-production';
  final env = AppEnv.fromMap({
    'JWT_SECRET': secret,
    'JWT_ISSUER': 'basic_app_test',
    'DOCS_PASSWORD': 'docs-test-password',
  });
  late AuthService service;
  late AppDatabase database;
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync('auth-service');
    databasePathOverride = '${temporaryDirectory.path}/auth.db';
    database = AppDatabase();
    service = AuthService(database);
  });

  tearDown(() async {
    await database.close();
    databasePathOverride = null;
    temporaryDirectory.deleteSync(recursive: true);
  });

  test(
    'Given a new user When signing up Then a valid JWT is returned',
    () async {
      final response = await service.signUp(
        const SignUpDto(
          name: 'Ada Lovelace',
          email: 'ADA@example.com',
          password: 'correct horse battery staple 1',
        ),
        env: env,
      );

      final jwt = JWT.verify(response.accessToken, SecretKey(secret));
      expect(jwt.subject, response.user.id);
      expect(jwt.payload, containsPair('email', 'ada@example.com'));
      expect(response.tokenType, 'Bearer');
      expect(response.expiresIn, 3600);
    },
  );

  test(
    'Given an existing user When logging in Then credentials are checked',
    () async {
      await service.signUp(
        const SignUpDto(
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          password: 'correct horse battery staple 1',
        ),
        env: env,
      );

      final response = await service.login(
        const LoginDto(
          email: 'ada@example.com',
          password: 'correct horse battery staple 1',
        ),
        env: env,
      );
      expect(response.user.email, 'ada@example.com');

      await expectLater(
        service.login(
          const LoginDto(email: 'ada@example.com', password: 'wrong-password'),
          env: env,
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.unauthorized,
          ),
        ),
      );
    },
  );

  test(
    'Given a duplicate email When signing up Then conflict is returned',
    () async {
      const input = SignUpDto(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'correct horse battery staple 1',
      );
      await service.signUp(input, env: env);

      await expectLater(
        service.signUp(input, env: env),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.conflict,
          ),
        ),
      );
    },
  );

  test('Given invalid credentials When validating DTOs Then fields fail', () {
    final invalidSignUp = $SignUpDtoValidate({
      'name': 'Ada',
      'email': 'not-an-email',
      'password': 'password',
    });
    final invalidLogin = $LoginDtoValidate({
      'email': 'ada@example.com',
      'password': '12345678',
    });

    expect(invalidSignUp.isValid, isFalse);
    expect(invalidLogin.isValid, isFalse);
  });

  test('Given valid credentials When validating DTOs Then fields pass', () {
    final signUp = $SignUpDtoValidate({
      'name': 'Ada',
      'email': 'ada@example.com',
      'password': 'password123',
    });
    final login = $LoginDtoValidate({
      'email': 'ada@example.com',
      'password': 'password123',
    });

    expect(signUp.isValid, isTrue);
    expect(login.isValid, isTrue);
  });
}
