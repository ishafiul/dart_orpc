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

### `lib/src/analysis/`

Analyzer adapters shared by multiple generators. `dto_field_discovery.dart`
enumerates public instance fields/getters and unnamed-constructor parameters
with their types and original source elements. It does not decide field binding
or emit code.

Module analysis merges member and constructor candidates, retaining source
annotations and reporting conflicts. Field-reference generation deduplicates
member names and only falls back to constructor candidates when there are no
members. These distinct policies stay with their consumers.

### `lib/src/contracts/`

Standalone, analyzer-independent contract models. `RestRoutePattern` parses a
path once and retains its emitted spelling, ordered parameter occurrences, and
collision path/signature. DTO binding, explicit path-parameter validation,
collision checks, and generated metadata use that same parsed value.

Parsing preserves existing normalization and parameter-recognition behavior;
it does not introduce a new route grammar or reject previously accepted paths.
Both shared directories are internal libraries imported by the generators,
not parts of the module-generator library or public runtime exports.

### `lib/src/graph/`

Standalone, analyzer-independent graph algorithms imported by the generator
library. These are internal implementation libraries, not library parts or
consumer-facing runtime APIs. They belong to the build-time generator rather
than the runtime `dart_orpc_core` package.

- `depth_first_search.dart`: iterative DFS with visiting/done states, a path
  index, dependency-first postorder, and closed cycle paths. Shared nodes are
  visited once, and deep dependency chains do not use the Dart call stack.
- `topological_sort.dart`: Kahn's algorithm using dependency counts and an
  ordered ready queue. Unknown dependencies remain unresolved unless supplied
  as already available; repeated edges count once.

Module analysis adapts annotation imports into DFS nodes, then constructs
resolved declarations in postorder. Provider analysis supplies only required
constructor dependencies to the sorter; imported/external providers are already
available. Optional constructor arguments are bound using the existing
instantiation policy after ordering.

The ready queue preserves the original declaration-pass order: a newly ready
provider later in the declaration list runs in the current pass, while an
earlier one waits for the next pass. A plain FIFO would change optional
injection and disposal order. This compatibility policy uses an ordered tree,
costing O(E + V log V), instead of a linear FIFO Kahn traversal. DFS traversal
and cycle search cost O(V + E); neither algorithm repeatedly scans blocked
providers or completed dependency subgraphs.

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

For streaming procedures, analysis resolves `Stream<T>` into two analyzer-free
values: `isStream` and the event type `T`. Emitters never receive `Stream<T>` as
the output contract and never re-inspect a method return type.

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

Server streaming follows the same rule. One resolved procedure drives
`RpcStreamProcedure`, an optional `RestStreamRoute`, SSE metadata, OpenAPI
extensions, and the generated `Stream<T>` client method. Invalid combinations
such as unary SSE, JSON REST on streams, raw or nested streams, and
`Future<Stream<T>>` must fail during analysis.

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
- Graph unit tests cover deep/shared graphs, cycles, missing/duplicate edges,
  ordering compatibility, and single dependency enumeration per node.
- Generated-output assertions protect the public contract. Prefer focused
  assertions or stable goldens over snapshots of incidental whitespace.
- CI enforces at least 90% line coverage for the generator and each primary
  runtime package (`core`, `client`, `http`, `websocket`, and `openapi`).
  Coverage is a floor, not a substitute for contract-focused tests.
