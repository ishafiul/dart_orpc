import 'package:dart_orpc/dart_orpc.dart';

import 'app_database.dart';

/// Provides the single [AppDatabase] that every feature module shares.
///
/// It is global: import it once in the app root, and every module in the app
/// can inject [AppDatabase] without importing it.
@Module(global: true, providers: [AppDatabase], exports: [AppDatabase])
final class DatabaseModule {
  const DatabaseModule();
}
