import 'package:dart_orpc/dart_orpc.dart';

import '../../database/database_module.dart';
import 'auth_controller.dart';
import 'auth_service.dart';

@Module(
  imports: [DatabaseModule],
  controllers: [AuthController],
  providers: [AuthService],
)
final class AuthModule {
  const AuthModule();
}
