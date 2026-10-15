import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dart_orpc/dart_orpc.dart';

import '../../database/app_database.dart';
import '../../environment/app_env.dart';
import 'auth_dtos.dart';

final class AuthService {
  AuthService(this.db);

  final AppDatabase db;

  Future<AuthResponseDto> signUp(SignUpDto input, {required AppEnv env}) async {
    final email = _normalizeEmail(input.email);
    final existingUser = await (db.select(
      db.users,
    )..where((user) => user.email.equals(email))).getSingleOrNull();
    if (existingUser != null) {
      throw RpcException.conflict('An account with this email already exists.');
    }

    final id = await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            name: input.name.trim(),
            email: email,
            passwordHash: BCrypt.hashpw(input.password, BCrypt.gensalt()),
          ),
        );
    final user = await (db.select(
      db.users,
    )..where((user) => user.id.equals(id))).getSingle();
    return _createAuthResponse(user, env);
  }

  Future<AuthResponseDto> login(LoginDto input, {required AppEnv env}) async {
    final email = _normalizeEmail(input.email);
    final user = await (db.select(
      db.users,
    )..where((user) => user.email.equals(email))).getSingleOrNull();
    if (user == null || !BCrypt.checkpw(input.password, user.passwordHash)) {
      throw RpcException.unauthorized('Invalid email or password.');
    }
    return _createAuthResponse(user, env);
  }

  AuthResponseDto _createAuthResponse(User user, AppEnv env) {
    final userId = user.id.toString();
    final token = JWT(
      {'email': user.email, 'name': user.name},
      subject: userId,
      issuer: env.jwtIssuer,
    ).sign(SecretKey(env.jwtSecret), expiresIn: env.jwtLifetime);

    return AuthResponseDto(
      accessToken: token,
      expiresIn: env.jwtLifetime.inSeconds,
      user: AuthUserDto(id: userId, name: user.name, email: user.email),
    );
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();
}
