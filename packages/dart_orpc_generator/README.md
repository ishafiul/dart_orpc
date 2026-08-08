# dart_orpc_generator

Build-time generators for `dart_orpc` modules and DTO field references.

Most contributors should start with
[`doc/architecture.md`](doc/architecture.md). It explains the generation flow,
directory boundaries, and where each kind of change belongs.

## Development

From the workspace root:

```sh
dart test packages/dart_orpc_generator
dart analyze packages/dart_orpc_generator
dart format packages/dart_orpc_generator
dart run melos run test:generator:coverage
```

Generated module behavior is covered by `test/rpc_module_generator_test.dart`.
Architectural boundaries are covered by `test/generator_architecture_test.dart`.
The workspace coverage command enforces at least 90% generator line coverage.

## Entry points

- `lib/dart_orpc_generator.dart` exposes the build-runner factories.
- `lib/src/rpc_module_generator.dart` owns the module-generator library and lists
  its internal parts by architectural layer.
- `lib/src/rpc_dto_field_ref_generator.dart` owns the smaller DTO field-reference
  generator.

The package intentionally keeps analyzer interaction behind the analysis stage
and passes a resolved generation plan to emitters.

## Root-scoped global modules

Annotate an infrastructure module with `@Module(global: true)` and explicitly
list the providers it exports:

```dart
@Module(
  global: true,
  providers: [Database],
  exports: [Database],
)
final class PlatformModule {}
```

Global visibility is calculated from the generated application root and its
reachable `imports` graph. It is not package-wide source scanning. Only
providers named in `exports` are visible, and each exported provider is created
once per generated application container. Two separately generated roots have
separate instances.

Feature modules may consume an exported global provider without importing the
global module. A provider can also be explicitly imported and globally visible;
both paths resolve to the same generated binding. Private providers remain
private, and duplicate exporters, local shadowing, unresolved dependencies,
provider cycles, and module import cycles fail generation with diagnostics.

When a module is generated in isolation and a constructor dependency is not
available in its reachable graph, the generated API exposes a typed required
dependency. Root composition must supply that value; no public dynamic
provider map is used.

Global guard providers are reusable dependencies only. They do not execute
automatically and do not add OpenAPI security metadata. Route execution still
requires `@UseGuards`, while Bearer documentation still requires
`@BearerAuth`.
