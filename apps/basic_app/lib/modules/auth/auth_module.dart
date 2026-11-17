import 'package:dart_orpc/dart_orpc.dart';

import 'auth_controller.dart';
import 'auth_service.dart';

@Module(controllers: [AuthController], providers: [AuthService])
final class AuthModule {
  const AuthModule();
}
