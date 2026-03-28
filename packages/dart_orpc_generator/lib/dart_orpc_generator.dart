library dart_orpc_generator;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/rpc_dto_field_ref_generator.dart';
import 'src/rpc_module_generator.dart';

Builder dartOrpcBuilder(BuilderOptions options) =>
    SharedPartBuilder([RpcDtoFieldRefGenerator()], 'dart_orpc');

Builder dartOrpcModuleBuilder(BuilderOptions options) =>
    LibraryBuilder(RpcModuleGenerator(), generatedExtension: '.orpc.dart');
