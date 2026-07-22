import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:luthor/luthor.dart';
import 'package:source_gen/source_gen.dart';

// Analyzer-facing discovery and contract resolution.
part 'rpc_module_generator/analysis/controller_binding_builder.dart';
part 'rpc_module_generator/analysis/contract_collision_validator.dart';
part 'rpc_module_generator/analysis/dto_field_resolver.dart';
part 'rpc_module_generator/analysis/imported_provider_instantiations.dart';
part 'rpc_module_generator/analysis/module_analyzer.dart';
part 'rpc_module_generator/analysis/module_graph_resolver.dart';
part 'rpc_module_generator/analysis/procedure_binding_builder.dart';
part 'rpc_module_generator/analysis/procedure_invocation_resolution.dart';
part 'rpc_module_generator/analysis/procedure_parameter_resolution.dart';
part 'rpc_module_generator/analysis/provider_resolution.dart';
part 'rpc_module_generator/analysis/resolved_rest_rpc_input_builder.dart';
part 'rpc_module_generator/analysis/rest_input_field_resolver.dart';
part 'rpc_module_generator/analysis/rest_rpc_input_resolver.dart';
part 'rpc_module_generator/analysis/rpc_input_binding_resolver.dart';
part 'rpc_module_generator/analysis/type_and_constructor_helpers.dart';
part 'rpc_module_generator/analysis/type_checkers.dart';

// Immutable data passed from analysis to emission.
part 'rpc_module_generator/model/dto_binding_models.dart';
part 'rpc_module_generator/model/generation_models.dart';
part 'rpc_module_generator/model/module_generation_plan.dart';
part 'rpc_module_generator/model/module_resolution_models.dart';
part 'rpc_module_generator/model/procedure_invocation_models.dart';
part 'rpc_module_generator/model/procedure_models.dart';

// Dart source emission. Emitters do not inspect source annotations directly.
part 'rpc_module_generator/emission/client_emitter.dart';
part 'rpc_module_generator/emission/container_and_registry_emitter.dart';
part 'rpc_module_generator/emission/module_emitter.dart';
part 'rpc_module_generator/emission/openapi_emitter.dart';
part 'rpc_module_generator/emission/rest_and_metadata_emitter.dart';

// High-level generation flow.
part 'rpc_module_generator/pipeline/library_generation.dart';
part 'rpc_module_generator/pipeline/module_generation.dart';

// Shared deterministic naming, imports, and source-expression helpers.
part 'rpc_module_generator/support/import_directives.dart';
part 'rpc_module_generator/support/naming_helpers.dart';
part 'rpc_module_generator/support/rest_generation_helpers.dart';

final class RpcModuleGenerator extends Generator {
  const RpcModuleGenerator();

  static const _pipeline = _RpcModuleLibraryGenerator();

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) {
    return _pipeline.generate(library, buildStep);
  }
}
