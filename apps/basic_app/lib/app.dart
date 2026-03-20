import 'package:dart_orpc/dart_orpc.dart';

import 'user_controller.dart';
import 'user_dtos.dart';
import 'user_service.dart';

part 'app.g.dart';

@Module(controllers: [UserController], providers: [UserService])
final class AppModule {
  const AppModule();
}

RpcHttpApp buildBasicApp() => _$buildAppModuleRpcApp();
