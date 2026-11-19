# dart_orpc_lints

Architecture and contract lint rules for dart_orpc applications. It is layered
on top of [`strict_dart_lints`](../strict_dart_lints), which holds the rules
that apply to any Dart code.

| Layer | Package | Rules |
|---|---|---|
| Base | `strict_dart_lints` | Strict analyzer preset and Dart-wide rules: comments, ignore reasons, quick-fix smells, hard-coded strings |
| dart_orpc | `dart_orpc_lints` | Rules that need dart_orpc concepts: module boundaries, framework errors, controllers, routing |

## Usage

Both plugins are enabled side by side, so each rule keeps its stable
`plugin/rule` name for `// ignore:` comments. Until `strict_dart_lints` is
published, add both packages:

```yaml
# pubspec.yaml
dev_dependencies:
  dart_orpc_lints: ^0.1.0
  strict_dart_lints: ^0.1.0
```

```yaml
# analysis_options.yaml
include: package:dart_orpc_lints/app.yaml

plugins:
  strict_dart_lints:
    version: ^0.1.0
    diagnostics:
      no_doc_comments: true
  dart_orpc_lints: ^0.1.0
```

`app.yaml` includes `strict_dart_lints/strict.yaml` and excludes generated
`*.orpc.dart` files from analysis. Configure both analyzer plugins in the
root `analysis_options.yaml` so both sets of plugin diagnostics run.

## Rules

All rules are errors and skip generated files.

| Rule | Bans | Tests |
|---|---|---|
| `throw_framework_errors` | throwing anything but `RpcException` or an `Error` subtype | exempt |
| `no_manual_routes` | using `HttpServer` from `dart:io` or `rust_http` directly | exempt |
| `controller_no_logic` | loops, `try` statements and `dart:io` inside `@Controller` classes | exempt |
| `no_cross_module_internal_import` | using another module's controllers or non-exported providers | exempt |
| `no_undeclared_module_dependency` | using an exported provider of a module that is not in `@Module(imports:)` and is not global | exempt |
| `no_manual_provider_construction` | constructing a provider or controller instead of injecting it | exempt |

### How module ownership is resolved

A file belongs to the module declared in that file, otherwise to the single
`@Module` class declared in the nearest enclosing folder, walking up to the
package root. A folder with more than one module class owns nothing. The module
rules compare type names against the `providers`, `bindings`, `controllers`,
`exports`, `imports` and `global` arguments of those declarations.

### Deferred

| Rule | Waits on |
|---|---|
| `layer_imports` | provider role markers (`@Service`, `@Repository`, ...) in `dart_orpc_annotations`, so a rule can tell layers apart |
| `no_generated_code_edits` | nothing in the lint: hand edits to generated files are caught by regenerating in CI and failing on a diff |

## Plugin dependency constraint

The analysis server resolves all enabled plugins together in one generated
package outside the workspace, so a plugin's runtime `dependencies` must
resolve from pub.dev alone. While `strict_dart_lints` is unpublished,
`dart_orpc_lints` lists it as a dev dependency only; a runtime dependency makes
resolution fail and the analyzer silently loads no plugin at all. Once
`strict_dart_lints` is on pub.dev, it moves to `dependencies` and applications
need only `dart_orpc_lints`.

## Changing a rule

The analysis server loads each plugin once and keeps that build running. After
editing a rule, restart the analysis server (VS Code: **Dart: Restart Analysis
Server**; IntelliJ: **Restart Dart Analysis Server**) or the IDE keeps
reporting the old behaviour and messages. `dart analyze` always starts fresh.
