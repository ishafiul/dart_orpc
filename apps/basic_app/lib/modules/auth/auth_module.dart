import 'package:dart_orpc/dart_orpc.dart';

import '../../database/app_database.dart';
import 'auth_controller.dart';
import 'auth_service.dart';

@Module(controllers: [AuthController], providers: [AppDatabase, AuthService])
final class AuthModule {
  const AuthModule();
}
