import 'dart:io';

import 'package:dart_orpc_cli/dart_orpc_cli.dart';

Future<void> main(List<String> arguments) async {
  final cli = DartOrpcCli();
  final statusCode = await cli.run(arguments);

  if (statusCode != 0) {
    exit(statusCode);
  }
}
