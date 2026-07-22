# Generator architecture

## Goal

Keep source analysis separate from generated Dart emission so analyzer API
changes have a small, obvious impact surface and output behavior remains easy to
test.

## Generation flow

```text
RpcModuleGenerator
  -> library pipeline
    -> module pipeline
      -> analysis
      -> immutable generation plan
      -> emission
    -> deterministic imports, exports, and module output
```

`RpcModuleGenerator` is deliberately thin. It delegates to the library pipeline,
which finds annotated modules and combines their results. Each module then moves
through analysis once and emission once.

## Directory responsibilities

### `analysis/`

Reads analyzer elements and annotation constants, validates contracts, resolves
the module/provider graph, and produces the generation plan. Changes caused by
new analyzer APIs should normally stay here.

### `model/`

Contains the resolved data transferred between stages. Models should describe
the contract and generated names, not emit Dart source. `_ModuleGenerationPlan`
is the handoff from analysis to emission.

Some resolved models retain analyzer elements only for source-library import and
export discovery. Emitters must not query those elements.

### `emission/`

Turns the resolved plan into Dart source for containers and registries, REST and
metadata, OpenAPI/app wiring, and clients. Emitters must not inspect analyzer
elements or annotations. `_ModuleEmitter` is the single place that defines
section order.

### `pipeline/`

Coordinates library-level and module-level generation. Pipelines decide stage
order but contain no contract-resolution rules and no feature-specific source
templates.

### `support/`

Holds deterministic naming, import/export discovery, and source-expression
helpers shared by stages. Helpers should stay small and focused; feature logic
belongs in analysis or emission.

## Adding or changing a feature

1. Add or update the resolved model that describes the feature.
2. Resolve and validate it in `analysis/`.
3. Consume the resolved value in the relevant emitter.
4. Add success and invalid-contract cases to the generator behavior tests.
5. If a new architectural part is introduced, place it in one of the documented
   directories and declare it in `rpc_module_generator.dart`.

Do not read annotations from an emitter, generate source from an analyzer
resolver, or rebuild resolved information in multiple stages.

## Analyzer upgrades

When changing the analyzer constraint:

1. Update analyzer-facing code under `analysis/` and import/export discovery in
   `support/`.
2. Run the architecture test to ensure analyzer access did not leak into
   emitters.
3. Run all generator behavior tests and inspect any output changes.
4. Regenerate the example application and run workspace analysis and tests.

## Testing strategy

- Behavior tests execute real builders against in-memory source packages.
- Invalid-contract tests assert useful generation failures.
- Architecture tests enforce directory membership, part registration, and the
  analyzer-free emitter boundary.
- Generated-output assertions protect the public contract. Prefer focused
  assertions or stable goldens over snapshots of incidental whitespace.
- CI enforces at least 90% line coverage for the generator package. Coverage is
  a floor, not a substitute for contract-focused tests.
