import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

const _dataFolder = 'data';
const _databaseFile = 'todos.db';

String defaultDatabasePath() =>
    p.join(Directory.current.path, _dataFolder, _databaseFile);

LazyDatabase openDatabaseConnection(String path) {
  return LazyDatabase(() async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return NativeDatabase(file);
  });
}
