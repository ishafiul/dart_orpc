# PRD — DEPS-001: Migrate to luthor 1.1 and upgrade the toolchain

- **Status:** Approved on [#66](https://github.com/ishafiul/dart_orpc/issues/66#issuecomment-6875654003), updated to target luthor 1.1 and its unknown-key modes ([exaby73/luthor#144](https://github.com/exaby73/luthor/pull/144)).
- **Tracker item:** `DEPS-001` in [`TODO.md`](../../TODO.md)
- **Requirements map:** [#61](https://github.com/ishafiul/dart_orpc/issues/61)
- **Unblocks:** ERR-002, structured validation issues ([#54](https://github.com/ishafiul/dart_orpc/issues/54))
- **Baseline:** `main` at `540c8bf`. Line references below are against this commit.

---

<overview>

## Problem Statement

- **What concrete pain point exists?**
  - `luthor_generator` 0.17 requires `analyzer ^9`, which holds back the whole code-generation stack ([#53](https://github.com/ishafiul/dart_orpc/pull/53)):

    | Package | Stuck at | Latest |
    |---|---|---|
    | analyzer | 9.0.0 | 14.7.0 |
    | freezed | 3.2.5 | 4.0.3 |
    | json_serializable | 6.13.0 | 6.15.2 |
    | drift / drift_dev | 2.31.0 | 2.35.x |
    | melos | 7.8.1 | 8.10.1 |
    | build_runner | 2.15.1 | 2.17.1 |
    | sqlite3 | 2.9.4 | 3.9.1 |
    | test | 1.31.1 | 1.33.0 |

  - freezed 3 emits `required final` constructor parameters that Dart 3.14 rejects. So `basic_app` stays on language 3.11 while the rest of the workspace requires `^3.14.0`.
  - ERR-002 needs luthor 1.1's structured `ValidationIssue`s ([#55](https://github.com/ishafiul/dart_orpc/issues/55)).
- **Who experiences it?**
  - Framework maintainers stuck on old toolchain versions.
  - App developers who want current freezed, json_serializable and drift.
  - Anyone waiting for ERR-002.
- **Why existing solutions don't work?**
  - luthor 1.x is a breaking redesign from 0.17 (introduced in 1.0, kept in 1.1). It makes validator rules private (`_Check`). It stops exporting the concrete `*Validation` classes, `validations` and schema fields.
  - `dart_orpc_openapi` builds JSON Schema by walking exactly those classes at runtime (`openapi_document.dart` L446–L652).
  - `luthor_generator` 1.x emits no schema description to read instead.
  - The `dart_orpc_luthor` bridge's public typedefs use luthor 0.17's `SchemaValidationResult`.

## Target Users & Personas

- **Server developer:**
  - Annotates DTOs with `@luthor`, `@HasMin`, `@IsEmail` and so on.
  - Expects validation and OpenAPI to keep working after upgrading, with no DTO changes beyond what luthor 1.1 requires.
- **API consumer:** reads `/openapi.json` and expects the same documented constraints, plus enum values.
- **Framework maintainer:** wants every dependency on its latest major, and OpenAPI decoupled from luthor internals so future luthor releases can't break it again.

## Success Metrics

- `dart pub outdated` holds back no direct dependency except `build` 5 and the packages that follow it, which upstream blocks: `luthor_generator` 1.1 requires `build ^4`.
- `basic_app`'s `/openapi.json` matches a golden snapshot taken on luthor 0.17, apart from reviewed, intended differences.
- `dart_orpc_openapi` no longer depends on luthor.
- `dart run melos run analyze`, `test`, `test:generator:coverage` and `test:runtime:coverage` all pass on Dart 3.14. `basic_app` requires `^3.14.0`.

## Source Requirements & Decisions

- **Requirements map:** [#61](https://github.com/ishafiul/dart_orpc/issues/61)
- **Resolved grilling issues:**
  - [#55](https://github.com/ishafiul/dart_orpc/issues/55) (on ERR-002's map): migrate to luthor 1.1 before ERR-002, as its own initiative.
  - [#62](https://github.com/ishafiul/dart_orpc/issues/62): OpenAPI gets DTO constraints from **build-time DTO schema metadata** in `dart_orpc_core`, rendered by `dart_orpc_openapi`, which drops luthor.
    - Honour `@JsonKey` name, include and defaultValue options and `fieldRename`; fail the build on anything else that shapes the JSON.
    - Custom validators get `x-dart-orpc-custom-validation: true`.
    - `OpenApiSchemaComponent(validator:)` is removed.
    - A golden snapshot is taken first.
  - [#63](https://github.com/ishafiul/dart_orpc/issues/63): unknown input keys are **stripped** by default. There's no new dart_orpc option.
    - **Addendum (luthor 1.1):** luthor 1.1 adds `UnknownKeys { strip, passthrough, strict }`, set per DTO with `@Luthor(unknownKeys: ...)` or per package with `luthor_generator:luthor` `unknown_keys` in `build.yaml` ([exaby73/luthor#144](https://github.com/exaby73/luthor/pull/144)). That's exactly the upstream home #63 named for strict mode, so dart_orpc uses it: generated code already validates with the mode luthor emits, and F4.5 documents it in the metadata and OpenAPI.
  - [#64](https://github.com/ishafiul/dart_orpc/issues/64): the bridge uses luthor 1.1's `ValidationResult<T>` directly, with one input-validator parameter. Errors stay one flattened message, with luthor 1.1's text, until ERR-002.
  - [#65](https://github.com/ishafiul/dart_orpc/issues/65): DTO enum fields become JSON Schema enums. Other unmapped annotations keep parity.
- **Constraints carried forward:**
  - Packages are `0.1.0-dev`. Breaking changes are committed with `!` so `melos version` records them; changelogs are never hand-written.
  - Compile-time generation is preferred over runtime discovery (AGENTS.md).
  - Runtime validation stays 100% luthor, custom validators included. Only the OpenAPI description moves to build-time metadata.
  - The first upgrade attempt is saved as `major-upgrade-attempt.diff`, made while preparing #53. It gave 111 analyzer errors, all luthor 1.0 API changes, which 1.1 keeps, and includes the analyzer 14 `isSynthetic` fix.

</overview>

---

<functional-decomposition>

## Capability Tree (The WHAT)

### Capability C1: OpenAPI parity baseline

Lock today's OpenAPI output so the migration can prove it changed nothing by accident.

#### Feature F1.1: Golden OpenAPI snapshot

- **Description:** A committed golden copy of `basic_app`'s `/openapi.json`, produced on luthor 0.17, with a test that compares the live document against it.
- **Inputs:** `basic_app`'s generated application.
- **Outputs:** A golden file plus a test that fails on any difference and prints the diff.
- **Behavior:**
  - The comparison is semantic: JSON values, with object key order ignored.
  - Updating the golden is an explicit, reviewed step. A flag or helper regenerates it; tests never regenerate it silently.

### Capability C2: Build-time DTO schema metadata

dart_orpc describes each `@luthor` DTO's JSON shape and constraints itself, at build time, without reading luthor at runtime.

#### Feature F2.1: DTO schema metadata model

- **Description:** Immutable, dependency-free types in `dart_orpc_core` describe a DTO's fields, types and constraints.
- **Inputs:** None; this is a data model.
- **Outputs:** A metadata model that `dart_orpc_openapi` and later features (ERR-002, OAPI work) can consume.
- **Behavior:** It represents:
  - **Types:** string, integer, number, boolean; object (a reference to another DTO); list; map with string keys; enum (with its serialized values); and "any".
  - **Field properties:** nullability, required on input, and the wire name.
  - **Constraints:** min/max (length for strings and lists, value for numbers), exact length, pattern, and format (email, date-time, uri, uuid).
  - **Custom-validation flag:** set when the field has a custom validator.

#### Feature F2.2: Metadata extraction in the generator

- **Description:** The generator turns each `@luthor` DTO into that metadata.
- **Inputs:** Analyzed DTO classes: the factory or constructor parameters and fields, their types, and their json_serializable, freezed and luthor annotations.
- **Outputs:** A metadata value per DTO, or a build error.
- **Behavior:**
  - **Wire names:** `@JsonKey(name:)`, otherwise the class-level `@JsonSerializable(fieldRename:)`, otherwise the field name.
  - **Excluded fields:** `@JsonKey(includeFromJson: false)`, `includeToJson: false` and `ignore` are excluded as json_serializable excludes them.
  - **Required vs optional on input:** a field is optional when it's nullable or has `@JsonKey(defaultValue:)` or a freezed `@Default`.
  - **Nesting:** nested `@luthor` DTOs become references; `List<T>` and `Map<String, T>` recurse.
  - **Enums:** serialized values, honouring `@JsonValue`. The type is `integer` when the values are ints and `string` otherwise.
  - **Constraints:** `@HasMin`/`@HasMax` (and luthor 0.17's `*Double`/`*Number` variants while still on 0.17), `@HasLength`, `@MatchRegex`, `@IsEmail`, `@IsDateTime`, `@IsUri` and `@IsUuid`. Annotation fields are read generically, so both luthor 0.17 and 1.0 work.
  - **Custom validators:** `@WithCustomValidator` and `@WithSchemaCustomValidator` set the custom-validation flag.
  - **Left out:** `@IsUrl`, `@IsIp`, `@IsCuid`, `@IsCuid2`, `@IsEmoji`, `@StartsWith`, `@EndsWith`, `@Contains` and `@IsFile`, matching today.
  - **Build error**, naming the DTO and field, for:
    - a global `build.yaml` `field_rename`;
    - union, sealed or generic DTOs;
    - map keys that aren't strings;
    - field types that can't be described.

#### Feature F2.3: Metadata emission

- **Description:** Generated module code exposes the DTO metadata in place of `OpenApiSchemaComponent(validator: $XSchema)`.
- **Inputs:** The extracted metadata.
- **Outputs:**
  - Generated `const` metadata values.
  - A registry factory per module, composed across imported modules the way the OpenAPI schema registry is today.
- **Behavior:** The output is deterministic, uses stable ordering and is easy to inspect, as AGENTS.md requires.

### Capability C3: OpenAPI rendered from metadata

#### Feature F3.1: JSON Schema rendering without luthor

- **Description:** `dart_orpc_openapi` renders component schemas from the DTO metadata, and drops its luthor dependency.
- **Inputs:** The DTO metadata registry and the procedure metadata.
- **Outputs:** The OpenAPI document. Component schemas match today's for every existing construct, and enum fields gain `enum`.
- **Behavior:**
  - Types map to their JSON Schema type.
  - **Strings:** min/max/length become `minLength`/`maxLength`; pattern becomes `pattern`; formats become `format`.
  - **Numbers:** `minimum`/`maximum`.
  - **Lists:** `minItems`/`maxItems` and `items`.
  - **Maps:** `additionalProperties`.
  - **Nested DTOs:** `$ref` to their component.
  - **Required:** the `required` list.
  - **Nullability:** nullable fields render as today.
  - **Enums:** `enum`.
  - **Custom validators:** the flag becomes `x-dart-orpc-custom-validation: true`.
  - **Breaking:** `OpenApiSchemaComponent(validator: Validator)` is removed, and components are built from the metadata. Committed with `!`.

#### Feature F3.2: Parity verification

- **Description:** The rendered document matches the F1.1 golden, apart from reviewed, intended differences.
- **Inputs:** The golden file and the live document.
- **Outputs:** A passing golden test.
- **Behavior:** Any intended difference, such as enum additions or a corrected constraint, is listed in the PR, and the golden is updated in the same PR.

### Capability C4: luthor 1.1 and toolchain upgrade

#### Feature F4.1: Dependency upgrade

- **Description:** Every dependency moves to its latest compatible version.
- **Inputs:** The workspace and benchmark pubspecs.
- **Outputs:**
  - luthor, luthor_generator, analyzer, freezed, json_serializable, drift/drift_dev, melos, sqlite3, test, build_runner and coverage at their latest.
  - `basic_app` requires `sdk: ^3.14.0`, and its freezed-version comment is removed.
- **Behavior:**
  - Generated code is regenerated.
  - The `basic_app` and benchmark code that depends on these packages is updated mechanically: DTOs (luthor 1.1 annotations), the drift and sqlite3 database code, and melos 8 configuration.

#### Feature F4.2: Analyzer 14 compatibility

- **Description:** The generator compiles and behaves the same on analyzer 14.
- **Inputs:** Generator sources.
- **Outputs:** No use of removed APIs.
- **Behavior:**
  - `FieldElement.isSynthetic` (`procedure_binding_builder.dart` L359) becomes `!(field.isOriginDeclaration || field.isOriginDeclaringFormalParameter)`.
  - Any other removed APIs are replaced with behaviour-preserving equivalents.

#### Feature F4.3: luthor 1.1 validation bridge

- **Description:** `dart_orpc_luthor` validates with luthor 1.1.
- **Inputs:** luthor 1.1 `ValidationResult<T>`s from the generated `$XValidate(Object? json)` functions.
- **Outputs:** Decoded DTOs, validated output JSON, or `RpcException`s.
- **Behavior:**
  - **Types:** the typedefs become `ValidationResult<T> Function(Object? json)`, and the functions match on `ValidationSuccess`/`ValidationFailure`.
  - **One input validator:** `validateReadOnly`, `LuthorReadOnlySchemaValidator` and the defensive `Map.from` copy are removed.
  - **Messages:**
    - Input failures stay `BAD_REQUEST` with one flattened message, `Invalid RPC input for "m": path: message; …`, built from luthor 1.1's flat path-keyed errors.
    - Output failures stay `INTERNAL_ERROR`.
    - The text follows luthor 1.1's defaults.
  - **Unknown keys:** stripped. Generated code calls the schema as `luthor_generator` emits it, with no `.strict()` or `.passthrough()`.
  - **Breaking public API**, committed with `!`.

#### Feature F4.4: Generated validation calls

- **Description:** Generated RPC, REST and WebSocket code calls the new bridge.
- **Inputs:** Procedure metadata.
- **Outputs:** Bridge calls with one validator argument, `$XValidate` (`rest_generation_helpers.dart` L17, L99).
- **Behavior:** The same procedures are validated as today.

#### Feature F4.5: Unknown-key modes (luthor 1.1)

- **Description:** DTOs that choose a luthor 1.1 unknown-key mode are validated and documented consistently.
- **Inputs:**
  - `@Luthor(unknownKeys: ...)` on a DTO.
  - The package-level `unknown_keys` option of the `luthor_generator:luthor` builder in `build.yaml`.
- **Outputs:**
  - `DtoSchemaMetadata.unknownKeys`: strip, passthrough or strict.
  - OpenAPI `additionalProperties: false` for strict DTOs.
- **Behavior:**
  - **Mode resolution** matches `luthor_generator`: the DTO annotation, otherwise the package option, otherwise strip. The package option is read with the same `build.yaml` access as the `field_rename` check (#76).
  - **Runtime validation needs no new dart_orpc code:** generated calls use the schema `luthor_generator` emits, which already carries the mode. A strict DTO rejects an unknown input key with `BAD_REQUEST` (luthor's `unrecognizedKey` issue); a strip DTO still accepts and drops it.
  - **OpenAPI:** a strict DTO's component schema gets `additionalProperties: false`. Strip and passthrough DTOs render as today, since both accept unknown keys.
  - **Keys the generator can't name:** `luthor_generator` falls back to passthrough when a serializer reads keys it can't name, such as `@JsonKey(readValue:)`. The extractor already fails the build for converters; it now also fails for `@JsonKey(readValue:)`, so metadata never describes a shape luthor validates differently.
  - **`basic_app` usage** is decided in its own grilling issue on #61.

### Capability C5: Documentation

#### Feature F5.1: Docs and tracker

- **Description:** The docs describe the post-migration behaviour.
- **Inputs:** The implemented behaviour.
- **Outputs:**
  - Updated validation, OpenAPI and `dart_orpc_luthor` docs pages:
    - luthor 1.1 annotations, including `@Luthor(unknownKeys:)`;
    - unknown keys stripped;
    - the custom-validation marker;
    - enums in OpenAPI;
    - the bridge API change;
    - the `OpenApiSchemaComponent` removal.
  - `TODO.md` marks DEPS-001 done, and records OAPI-003 additions for the unmapped annotations.
- **Behavior:** No hand-written changelog; the `!` commits cover it.

</functional-decomposition>

---

<structural-decomposition>

## Repository Structure & Modules (The HOW)

### Repository Structure

```text
packages/
├── dart_orpc_core/lib/src/
│   └── dto_schema_metadata.dart          # F2.1: new; exported from dart_orpc_core.dart
├── dart_orpc_generator/lib/src/rpc_module_generator/
│   ├── analysis/dto_schema_extraction.dart  # F2.2: new; builds on naming_helpers.dart L40–L62 field walk
│   ├── analysis/procedure_binding_builder.dart # F4.2: isSynthetic (L359)
│   ├── emission/openapi_emitter.dart     # F2.3: emits metadata instead of OpenApiSchemaComponent(validator:)
│   └── support/rest_generation_helpers.dart # F4.4: one validator argument (L17, L99)
├── dart_orpc_openapi/lib/src/
│   └── openapi_document.dart             # F3.1: render from metadata; remove the validator walker (L446–L652)
│                                         #        and OpenApiSchemaComponent(validator:) (L6–L11)
├── dart_orpc_luthor/lib/src/
│   └── luthor_rpc_validation.dart        # F4.3: luthor 1.1 ValidationResult
apps/basic_app/
├── test/openapi_golden_test.dart         # F1.1: new
├── test/goldens/openapi.json             # F1.1: new
├── lib/modules/**/..._dtos.dart          # F4.1: luthor 1.1 annotations
├── lib/database/                         # F4.1: drift/sqlite3 upgrade
└── pubspec.yaml                          # F4.1: sdk ^3.14.0
doc/src/content/docs/                     # F5.1
TODO.md                                   # F5.1
```

### Module Definitions

#### Module: DTO schema metadata (`dart_orpc_core`)

- **Maps to capability:** C2 (F2.1)
- **Responsibility:** A transport- and validator-neutral description of DTO JSON shapes and constraints.
- **Exports (public seams; names proposed, see A3):**
  - `DtoSchemaMetadata { String name; List<DtoFieldMetadata> fields; DtoUnknownKeys unknownKeys; }`. `unknownKeys` (strip, passthrough or strict; default strip) is added by F4.5.
  - `DtoFieldMetadata { String wireName; DtoFieldType type; bool nullable; bool required; DtoFieldConstraints constraints; bool customValidation; }`
  - `DtoFieldType`, a sealed type with these cases:
    - `DtoStringType`, `DtoIntegerType`, `DtoNumberType`, `DtoBooleanType`, `DtoAnyType`
    - `DtoObjectType(String component)`
    - `DtoListType(DtoFieldType element)`
    - `DtoMapType(DtoFieldType value)`
    - `DtoEnumType(List<Object> values)`
  - `DtoFieldConstraints { num? min; num? max; int? length; String? pattern; DtoStringFormat? format; }`
  - `DtoSchemaRegistry`: indexes metadata by component name and rejects duplicates, as `OpenApiSchemaRegistry` does today.
- **Dependency rule:** no new package dependencies; `core` stays dependency-light.

#### Module: Generator extraction and emission (`dart_orpc_generator`)

- **Maps to capability:** C2 (F2.2, F2.3) and C4 (F4.2, F4.4)
- **Responsibility:** Analyze `@luthor` DTOs into metadata at build time, emit it, and emit the bridge calls.
- **Changes:**
  - A new `dto_schema_extraction.dart` reuses the component discovery in `naming_helpers.dart` (L40–L62), which already finds `@luthor` DTOs through `_luthorChecker` (`type_checkers.dart` L63) and walks nested field types.
  - `_ResolvedOpenApiSchemaComponent.validatorExpression` (`procedure_invocation_models.dart` L49–L57) is replaced by the extracted metadata.
  - `_writeOpenApiSections` (`openapi_emitter.dart`) emits `const DtoSchemaMetadata(...)` values and registry factories, keeping today's per-module and composed registry structure.
  - The extraction emits build errors through the existing generator error path, naming the DTO and field.

#### Module: OpenAPI renderer (`dart_orpc_openapi`)

- **Maps to capability:** C3 (F3.1)
- **Responsibility:** Render the OpenAPI document from procedure metadata and DTO metadata only.
- **Changes:**
  - `_buildComponentSchemas` (L340) renders `DtoSchemaMetadata`.
  - `_schemaForValidator`, `_schemaForObjectValidator`, `_schemaForListValidation` and `_schemaForMapValidation` (L446–L628) are replaced by metadata renderers.
  - `_schemaForTypeCode` (L411) and `_requestBodySchema` (L380) use the metadata registry.
  - `luthor` is removed from `pubspec.yaml`.
  - `OpenApiSchemaRegistry` takes `DtoSchemaMetadata`, or is replaced by `DtoSchemaRegistry`.
  - The `createOpenApiDocument` signature changes accordingly, which is breaking.

#### Module: luthor bridge (`dart_orpc_luthor`)

- **Maps to capability:** C4 (F4.3)
- **Exports:**
  - `typedef LuthorSchemaValidator<T> = ValidationResult<T> Function(Object? json)`
  - `typedef LuthorJsonSchemaValidator = ValidationResult<JsonObject> Function(Object? json)`
  - `T decodeRpcInputWithLuthor<T>({required Object? rawInput, required String method, required LuthorSchemaValidator<T> validate})`
  - `JsonObject encodeRpcOutputWithLuthor<T>(...)` and `JsonObject encodeRpcOutputJsonWithLuthor<T>(...)`, with unchanged roles on the new types.
- **Removed:** `LuthorReadOnlySchemaValidator` and the `validateReadOnly` parameter.

</structural-decomposition>

---

<dependency-graph>

## Explicit Topological Dependency Chain

The luthor version switch can't be split. The moment luthor is 1.0, the OpenAPI walker, the bridge and the generated calls all stop compiling together. So everything that **can** happen on luthor 0.17 happens first, and the switch is one atomic phase.

### Foundation Layer (Phase 0), still luthor 0.17

- **F1.1 Golden OpenAPI snapshot:** no dependencies. Merges before any OpenAPI change.
- **F2.1 DTO schema metadata model:** no dependencies.

### Decoupling Layer (Phase 1), still luthor 0.17

- **F2.2 Metadata extraction:** depends on [F2.1].
- **F2.3 Metadata emission:** depends on [F2.2].
- **F3.1 OpenAPI from metadata:** depends on [F2.1, F2.3].
- **F3.2 Parity verification:** depends on [F1.1, F3.1].

### Switch Layer (Phase 2), luthor 1.1, delivered as one PR

- **F4.1 Dependency upgrade:** depends on [F3.2], because OpenAPI must no longer use luthor before the switch.
- **F4.2 Analyzer 14 compatibility:** depends on [F4.1].
- **F4.3 luthor 1.1 bridge:** depends on [F4.1].
- **F4.4 Generated validation calls:** depends on [F4.3].
- **F4.5 Unknown-key modes:** depends on [F2.3, F3.1, F4.1, F4.3]. It needs luthor 1.1 in place, so it follows the switch, in its own PR.

### Documentation Layer (Phase 3)

- **F5.1 Docs and tracker:** depends on [F3.2, F4.1, F4.2, F4.3, F4.4, F4.5].

</dependency-graph>

---

<implementation-roadmap>

## Phased Development Roadmap

### Phase 0: Lock the baseline (luthor 0.17)

- **Goal:** Make OpenAPI drift visible, and add the neutral metadata model.
- **Entry criteria:** `main` is green.
- **Tasks:**
  - [ ] **F1.1: Golden OpenAPI snapshot** (depends on: none)
    - Acceptance criteria:
      - The golden `basic_app` `/openapi.json` is committed.
      - The test passes on today's code and fails with a readable diff when any schema value changes.
    - Test strategy: `apps/basic_app/test/openapi_golden_test.dart`.
  - [ ] **F2.1: DTO schema metadata model** (depends on: none)
    - Acceptance criteria:
      - The types exist in `dart_orpc_core` and are exported, with no new dependencies.
      - The registry rejects duplicate names.
    - Test strategy: unit tests in `packages/dart_orpc_core/test`.
- **Exit criteria:** both merged; `main` is green.

### Phase 1: Decouple OpenAPI from luthor (luthor 0.17)

- **Goal:** OpenAPI renders from build-time metadata, and `dart_orpc_openapi` no longer imports luthor.
- **Entry criteria:** Phase 0 merged.
- **Tasks:**
  - [ ] **F2.2: Metadata extraction** (depends on: F2.1)
    - Acceptance criteria:
      - Every rule in F2.2's behaviour holds.
      - Unsupported shapes fail the build with the DTO and field named.
    - Test strategy: generator tests with source fixtures covering:
      - `@JsonKey(name)`, `fieldRename`, includes and ignore;
      - defaults and nullable fields;
      - nested DTOs, lists and maps;
      - enums, with and without `@JsonValue`;
      - every mapped annotation;
      - custom validators;
      - each build-error case.
  - [ ] **F2.3: Metadata emission** (depends on: F2.2)
    - Acceptance criteria: generated `basic_app` code contains deterministic `const` metadata and composed registries.
    - Test strategy: generator output tests, and `basic_app` regeneration.
  - [ ] **F3.1: OpenAPI from metadata** (depends on: F2.1, F2.3)
    - Acceptance criteria:
      - `dart_orpc_openapi` has no luthor dependency.
      - `OpenApiSchemaComponent(validator:)` is removed.
      - Enums render as `enum`, and custom validators carry the marker.
    - Test strategy: `openapi_document_test.dart`, rewritten to use metadata fixtures.
  - [ ] **F3.2: Parity verification** (depends on: F1.1, F3.1)
    - Acceptance criteria: the golden test passes, and any intended differences are listed in the PR.
    - Test strategy: the golden test.
- **Exit criteria:** merged; analysis, tests and coverage are green on luthor 0.17.

### Phase 2: Switch to luthor 1.1 (one PR)

- **Goal:** Upgrade everything at once now that OpenAPI no longer depends on luthor.
- **Entry criteria:** Phase 1 merged.
- **Tasks**, delivered as ordered commits in one PR:
  - [ ] **F4.1: Dependency upgrade** (depends on: F3.2)
    - Acceptance criteria:
      - `dart pub outdated` holds back only the `build`-5 family.
      - `basic_app` requires `^3.14.0`.
      - All benchmark packages resolve and analyze.
  - [ ] **F4.2: Analyzer 14 compatibility** (depends on: F4.1)
    - Acceptance criteria: the generator compiles, and custom metadata serialization skips the same fields as before.
  - [ ] **F4.3: luthor 1.1 bridge** (depends on: F4.1)
    - Acceptance criteria: the F4.3 behaviour holds, and an unknown body key is accepted and dropped over RPC and REST.
  - [ ] **F4.4: Generated validation calls** (depends on: F4.3)
    - Acceptance criteria: generated code passes one validator, and every procedure still validates.
- **Test strategy:**
  - Updated `dart_orpc_luthor` tests: success, input failure, output failure, flattened messages with luthor 1.1 text, list-element paths, and unknown keys.
  - The F1.1 golden test still passes.
  - Full workspace tests and both coverage gates.
- **Exit criteria:** merged; everything is green on Dart 3.14 and luthor 1.1.

### Phase 2b: Unknown-key modes (luthor 1.1)

- **Goal:** Document and test luthor 1.1's per-DTO and per-package unknown-key modes.
- **Entry criteria:** Phase 2 merged.
- **Tasks:**
  - [ ] **F4.5: Unknown-key modes** (depends on: F2.3, F3.1, F4.1, F4.3)
    - Acceptance criteria:
      - A DTO with `@Luthor(unknownKeys: .strict)` has `unknownKeys: strict` in its metadata, and `additionalProperties: false` in OpenAPI.
      - A package-level `unknown_keys: strict` applies to DTOs without an annotation; the annotation wins over it.
      - An unknown body key on a strict DTO returns `BAD_REQUEST` over RPC and REST; on a strip DTO it's accepted and dropped.
      - `@JsonKey(readValue:)` fails the build, naming the DTO and field.
    - Test strategy: core model tests, extractor fixtures, emission tests, renderer tests, and `basic_app` RPC and REST tests.
- **Exit criteria:** merged; the golden and all tests pass.

### Phase 3: Documentation

- [ ] **F5.1: Docs and tracker** (depends on: all above)
  - Acceptance criteria:
    - The docs reflect F2–F4.
    - `TODO.md` marks DEPS-001 done, and records the unmapped annotations under OAPI-003.
    - The docs build passes, and code samples compile.

</implementation-roadmap>

---

<test-strategy>

## Test Strategy & Critical Scenarios

```text
        /\
       /E2E\        ← golden OpenAPI snapshot + basic_app acceptance tests
      /------\
     /Integration\  ← generator fixtures → emitted metadata → rendered OpenAPI; bridge over RPC/REST
    /------------\
   /  Unit Tests  \ ← metadata model, extraction rules, renderer mappings, bridge result handling
  /----------------\
```

### Critical Test Scenarios

#### Module: Generator extraction

- **Happy path:** a DTO using `@JsonKey(name)`, `fieldRename: snake`, a nested DTO, `List<Dto>`, `Map<String, int>`, an enum with `@JsonValue`, and `@HasMin`/`@HasMax`/`@IsEmail`/`@MatchRegex` produces the expected metadata.
- **Edge cases:**
  - fields excluded with `includeFromJson: false` or `ignore`;
  - `@Default` and `defaultValue` make a field optional;
  - nullable nested DTOs;
  - an enum with int `@JsonValue`s;
  - a recursive DTO, which uses a `$ref` and doesn't loop.
- **Error cases:** each of these fails the build, naming the DTO and field:
  - a global `build.yaml` `field_rename`;
  - union, sealed or generic DTOs;
  - non-string map keys;
  - field types that can't be described.

#### Module: OpenAPI renderer

- **Happy path:** metadata for every type and constraint renders the expected JSON Schema.
- **Edge cases:** a custom-validator marker sits next to other constraints; an enum field is nullable.
- **Integration:** the `basic_app` golden matches.

#### Module: luthor bridge

- **Happy path:** valid input decodes, and valid output passes through unchanged.
- **Error cases:**
  - Invalid input gives `BAD_REQUEST`, with a flattened message using luthor 1.1's text and paths, such as `items.1.id`.
  - Invalid output gives `INTERNAL_ERROR`.
  - Non-object input gives `BAD_REQUEST`.
- **Edge cases:** unknown keys are accepted and dropped; a `fromJson` that throws becomes a `fromJsonFailed` issue, mapped to `BAD_REQUEST`.

</test-strategy>

---

<architecture>

## System Architecture & ADRs

- **Architecture overview:**
  - **Build time:** the generator analyzes `@luthor` DTOs into `DtoSchemaMetadata`, a core model, and emits it. `luthor_generator` emits `$XSchema` and `$XValidate`.
  - **Runtime validation:** generated code calls `dart_orpc_luthor`, which calls luthor 1.1.
  - **Runtime documentation:** `dart_orpc_openapi` renders JSON Schema from `DtoSchemaMetadata`.
  - Validation and documentation share their source annotations but are independent at runtime.
- **ADR-1: OpenAPI from build-time metadata** ([#62](https://github.com/ishafiul/dart_orpc/issues/62))
  - **Decision:** a dart_orpc-owned DTO metadata model in core, extracted by the generator and rendered by `dart_orpc_openapi`.
  - **Rationale:** AGENTS.md's single metadata model and compile-time generation. It also removes the coupling to luthor internals for good.
  - **Trade-offs:** the generator must mirror json_serializable's and luthor's annotation semantics. Hand-written luthor validators no longer feed OpenAPI.
  - **Alternatives considered:** finished JSON emitted by the generator; an upstream luthor introspection API; types only.
- **ADR-2: Strip unknown input keys by default** ([#63](https://github.com/ishafiul/dart_orpc/issues/63))
  - **Decision:** strip, luthor's default. Since luthor 1.1, a DTO or package can opt into strict or passthrough upstream, and dart_orpc documents the chosen mode (F4.5).
  - **Rationale:** today's behaviour, and rolling-deploy safety.
  - **Alternatives considered:** strict mode, which would belong upstream on `@Luthor` if ever wanted; configurable in dart_orpc.
- **ADR-3: Bridge on luthor's own types** ([#64](https://github.com/ishafiul/dart_orpc/issues/64))
  - **Decision:** `ValidationResult<T>`, with one validator parameter.
  - **Rationale:** only generated code calls the bridge, and luthor 1.1 never modifies input.
  - **Alternatives considered:** a dart_orpc result type; keeping the read-only variant.
- **ADR-4: Enums documented; other annotations keep parity** ([#65](https://github.com/ishafiul/dart_orpc/issues/65))
- **ADR-5: Decouple before switching** (this PRD)
  - **Decision:** OpenAPI moves to metadata while still on luthor 0.17. The version switch is then one atomic PR.
  - **Rationale:** each step is verifiable against the golden, and the breaking switch PR doesn't also contain the OpenAPI rewrite.
  - **Trade-offs:** the extractor must accept both luthor 0.17 and 1.0 annotation classes for one phase.

## Assumptions

- **A1:** The freezed 4, drift/drift_dev, sqlite3 3 and melos 8 upgrades need only mechanical changes in `basic_app`, the benchmarks and the workspace config. Phase 2 verifies this. If one turns out to need a design decision, it gets its own grilling issue on #61.
- **A2:** The luthor annotations `basic_app` uses (`@HasMin`, `@HasMax`, `@IsEmail`, `@MatchRegex`) exist in both 0.17 and 1.0 with readable `min`, `max` and `pattern` fields. 0.17's `HasMin.min` is an `int` and 1.0's is a `num`; extraction reads them as `num`.
- **A4:** luthor 1.1 is source-compatible with the luthor 1.0 API this PRD was written against, apart from the additions in exaby73/luthor#144. Phase 2 verifies this.
- **A3:** Names marked "proposed" (`DtoSchemaMetadata`, `DtoFieldMetadata`, `DtoFieldType`, `DtoFieldConstraints`, `DtoSchemaRegistry`, `dto_schema_extraction.dart`) may be refined during implementation without re-review, as long as the seams and behaviour above hold.

</architecture>

---

<risks>

## Risk Analysis & Mitigations

- **Technical risks:**
  - **The extractor diverges from json_serializable or luthor**, giving wrong property names, required-ness or constraints in OpenAPI.
    - Mitigation: the golden snapshot (F1.1), fixture tests per rule, and build errors instead of guesses for unsupported shapes.
  - **luthor 1.1 behaviour changes reach clients:**
    - unknown keys are stripped;
    - validation stops after a failed type check;
    - default message text changes;
    - per-element list errors appear;
    - `null` input to a schema produces a `required` issue.
    - Mitigation: bridge tests pin each behaviour, and docs (F5.1) describe them.
- **Dependency risks:**
  - **The other major upgrades (A1)** may bring API changes beyond luthor: freezed 4's generated API, drift 2.35 and sqlite3 3 in the database layer, and melos 8 configuration.
    - Mitigation: Phase 2 runs the full suite and the benchmarks; a non-mechanical surprise becomes a grilling issue.
  - **`build` 5 stays blocked** until `luthor_generator` supports it. This is accepted and recorded.
  - **luthor is third-party.** After this migration only validation depends on it; OpenAPI doesn't.
- **Scope risks:**
  - **ERR-002 (structured issues) and OAPI-003 (richer mappings) are tempting to fold in.** The PRD keeps flattened messages and parity mappings; those items build on this one.
  - **Breaking changes:** the `OpenApiSchemaComponent` removal, the `createOpenApiDocument` signature and the bridge typedefs are all `0.1.0-dev` breaks, committed with `!`.

</risks>
