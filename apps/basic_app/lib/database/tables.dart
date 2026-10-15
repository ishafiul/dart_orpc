import 'package:drift/drift.dart';

class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 500)();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 3, max: 200)();

  TextColumn get email => text().withLength(max: 254).unique()();

  TextColumn get passwordHash => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
