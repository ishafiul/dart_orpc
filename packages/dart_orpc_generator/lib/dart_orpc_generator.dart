library dart_orpc_generator;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/rpc_module_generator.dart';

Builder dartOrpcBuilder(BuilderOptions options) {
  return SharedPartBuilder([RpcModuleGenerator()], 'dart_orpc');
}
