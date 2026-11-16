import 'dart:io';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/database/database_open.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('basic-app-database');
    databasePathOverride = '${directory.path}/todos.db';
  });

  tearDown(() {
    databasePathOverride = null;
    // Windows cannot delete a database file that is still open.
    directory.deleteSync(recursive: true);
  });

  test('Given an opened database When the app disposes it Then it is closed', () async {
    final database = AppDatabase();
    await database.select(database.todos).get();

    await disposeRpcProviders([database]);

    expect(database, isA<RpcDisposable>());
    await expectLater(
      database.select(database.todos).get(),
      throwsA(anything),
    );
  });
}
