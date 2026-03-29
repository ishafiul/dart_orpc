import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:luthor/luthor.dart';
import 'package:source_gen/source_gen.dart';

part 'rpc_module_generator/type_checkers.dart';
part 'rpc_module_generator/library_generation.dart';
part 'rpc_module_generator/module_generation.dart';
part 'rpc_module_generator/module_generation_context.dart';
part 'rpc_module_generator/container_and_registry_emitter.dart';
part 'rpc_module_generator/rest_and_metadata_emitter.dart';
part 'rpc_module_generator/openapi_emitter.dart';
part 'rpc_module_generator/client_emitter.dart';
part 'rpc_module_generator/module_graph_resolver.dart';
part 'rpc_module_generator/provider_resolution.dart';
part 'rpc_module_generator/imported_provider_instantiations.dart';
part 'rpc_module_generator/controller_binding_builder.dart';
part 'rpc_module_generator/procedure_binding_builder.dart';
part 'rpc_module_generator/procedure_invocation_resolution.dart';
part 'rpc_module_generator/procedure_parameter_resolution.dart';
part 'rpc_module_generator/rest_generation_helpers.dart';
part 'rpc_module_generator/rest_rpc_input_resolver.dart';
part 'rpc_module_generator/rest_input_field_resolver.dart';
part 'rpc_module_generator/resolved_rest_rpc_input_builder.dart';
part 'rpc_module_generator/dto_field_resolver.dart';
part 'rpc_module_generator/rpc_input_binding_resolver.dart';
part 'rpc_module_generator/type_and_constructor_helpers.dart';
part 'rpc_module_generator/naming_helpers.dart';
part 'rpc_module_generator/import_directives.dart';
part 'rpc_module_generator/module_resolution_models.dart';
part 'rpc_module_generator/procedure_models.dart';
part 'rpc_module_generator/procedure_invocation_models.dart';
part 'rpc_module_generator/dto_binding_models.dart';
part 'rpc_module_generator/generation_models.dart';

final class RpcModuleGenerator extends Generator {
  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) {
    return _generateModuleLibrary(library, buildStep);
  }
}
