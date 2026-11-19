import 'dart:io';

import 'package:basic_app/database/app_database.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('basic-app-database');
  });

  tearDown(() => deleteFolderAfterDatabaseFileIsReleased(directory));

  test(
    'Given an opened database When the app disposes it Then it is closed',
    () async {
      final database = AppDatabase.atPath('${directory.path}/todos.db');
      await database.select(database.todos).get();

      await disposeRpcProviders([database]);

      expect(database, isA<RpcDisposable>());
      await expectLater(
        database.select(database.todos).get(),
        throwsA(anything),
      );
    },
  );
}

void deleteFolderAfterDatabaseFileIsReleased(Directory directory) =>
    directory.deleteSync(recursive: true);
