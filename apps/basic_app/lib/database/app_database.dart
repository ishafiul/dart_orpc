import 'package:drift/drift.dart';

import 'database_open.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Todos])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDatabaseConnection());

  @override
  int get schemaVersion => 1;
}
