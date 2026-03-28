import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

String? databasePathOverride;

LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async {
    final file = File(
      databasePathOverride ?? p.join(Directory.current.path, 'data', 'todos.db'),
    );
    await file.parent.create(recursive: true);
    return NativeDatabase(file);
  });
}
