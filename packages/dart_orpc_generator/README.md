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
