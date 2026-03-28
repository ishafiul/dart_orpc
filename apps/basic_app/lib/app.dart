import 'package:dart_orpc/dart_orpc.dart';

import 'user_module.dart';

part 'app.g.dart';

@Module(imports: [UserModule])
final class AppModule {
  const AppModule();
}

RpcHttpApp buildBasicApp() => _$buildAppModuleRpcApp();

ProcedureMetadataRegistry buildBasicAppProcedureMetadata() =>
    _$createAppModuleProcedureMetadataRegistry();

JsonObject buildBasicAppOpenApiDocument() => _$createAppModuleOpenApiDocument();
