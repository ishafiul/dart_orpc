import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:dart_orpc_lints/src/rules/controller_no_logic.dart';
import 'package:dart_orpc_lints/src/rules/layer_dependencies.dart';
import 'package:dart_orpc_lints/src/rules/no_cross_module_internal_import.dart';
import 'package:dart_orpc_lints/src/rules/no_manual_provider_construction.dart';
import 'package:dart_orpc_lints/src/rules/no_manual_routes.dart';
import 'package:dart_orpc_lints/src/rules/no_undeclared_module_dependency.dart';
import 'package:dart_orpc_lints/src/rules/provider_requires_role.dart';
import 'package:dart_orpc_lints/src/rules/role_must_be_provided.dart';
import 'package:dart_orpc_lints/src/rules/throw_framework_errors.dart';

final plugin = DartOrpcLintsPlugin();

class DartOrpcLintsPlugin extends Plugin {
  static const _name = 'dart_orpc_lints';

  @override
  String get name => _name;

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(ControllerNoLogic())
      ..registerWarningRule(LayerDependencies())
      ..registerWarningRule(NoCrossModuleInternalImport())
      ..registerWarningRule(NoManualProviderConstruction())
      ..registerWarningRule(NoManualRoutes())
      ..registerWarningRule(NoUndeclaredModuleDependency())
      ..registerWarningRule(ProviderRequiresRole())
      ..registerWarningRule(RoleMustBeProvided())
      ..registerWarningRule(ThrowFrameworkErrors());
  }
}
