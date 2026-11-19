import 'package:basic_app/modules/auth/auth_controller.dart';
import 'package:basic_app/modules/auth/auth_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

@Module(controllers: [AuthController], providers: [AuthService])
final class AuthModule {
  const AuthModule();
}
