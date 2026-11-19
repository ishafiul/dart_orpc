import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:strict_dart_lints/src/rules/ignore_requires_reason.dart';
import 'package:strict_dart_lints/src/rules/no_broad_catch.dart';
import 'package:strict_dart_lints/src/rules/no_code_comments.dart';
import 'package:strict_dart_lints/src/rules/no_delay_as_fix.dart';
import 'package:strict_dart_lints/src/rules/no_doc_comments.dart';
import 'package:strict_dart_lints/src/rules/no_global_mutable_state.dart';
import 'package:strict_dart_lints/src/rules/no_hardcoded_strings.dart';
import 'package:strict_dart_lints/src/rules/no_late_without_initializer.dart';
import 'package:strict_dart_lints/src/rules/no_mirrors.dart';
import 'package:strict_dart_lints/src/rules/no_null_assertion.dart';
import 'package:strict_dart_lints/src/rules/no_unchecked_cast.dart';

final plugin = StrictDartLintsPlugin();

class StrictDartLintsPlugin extends Plugin {
  static const _name = 'strict_dart_lints';

  @override
  String get name => _name;

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(IgnoreRequiresReason())
      ..registerWarningRule(NoBroadCatch())
      ..registerWarningRule(NoCodeComments())
      ..registerWarningRule(NoDelayAsFix())
      ..registerWarningRule(NoGlobalMutableState())
      ..registerWarningRule(NoHardcodedStrings())
      ..registerWarningRule(NoLateWithoutInitializer())
      ..registerWarningRule(NoMirrors())
      ..registerWarningRule(NoNullAssertion())
      ..registerWarningRule(NoUncheckedCast())
      ..registerLintRule(NoDocComments());
  }
}
