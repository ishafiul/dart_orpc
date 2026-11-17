import 'package:dart_orpc/dart_orpc.dart';

import 'app_database.dart';

/// Provides the single [AppDatabase] that every feature module shares.
///
/// Import this module instead of listing [AppDatabase] as a provider, so the
/// app opens one connection to the database file.
@Module(providers: [AppDatabase], exports: [AppDatabase])
final class DatabaseModule {
  const DatabaseModule();
}
