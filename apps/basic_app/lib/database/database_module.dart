import 'package:basic_app/database/app_database.dart';
import 'package:dart_orpc/dart_orpc.dart';

@Module(
  global: true,
  bindings: [
    RpcProviderBinding.useFactory(
      provide: AppDatabase,
      factory: AppDatabase.atDefaultPath,
    ),
  ],
  exports: [AppDatabase],
)
final class DatabaseModule {
  const DatabaseModule();
}
