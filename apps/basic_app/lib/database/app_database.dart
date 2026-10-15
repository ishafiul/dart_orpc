import 'package:drift/drift.dart';

import 'database_open.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Todos, Users])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDatabaseConnection());

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
