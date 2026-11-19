import 'package:basic_app/database/database_open.dart';
import 'package:basic_app/database/tables.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Todos, Users])
class AppDatabase extends _$AppDatabase implements RpcDisposable {
  AppDatabase(super.e);

  factory AppDatabase.atPath(String path) =>
      AppDatabase(openDatabaseConnection(path));

  factory AppDatabase.atDefaultPath() =>
      AppDatabase.atPath(defaultDatabasePath());

  @override
  Future<void> dispose() => close();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(users);
      }
    },
  );
}
