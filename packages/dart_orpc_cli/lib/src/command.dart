import 'package:args/args.dart';

abstract interface class DartOrpcCommand {
  String get name;

  String get description;

  ArgParser buildParser();

  Future<int> run(ArgResults results);
}
