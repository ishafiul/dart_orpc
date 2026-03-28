import 'package:dart_orpc/dart_orpc.dart';

import 'user_controller.dart';
import 'user_dtos.dart';
import 'user_service.dart';

part 'user_module.g.dart';

@Module(
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
)
final class UserModule {
  const UserModule();
}
