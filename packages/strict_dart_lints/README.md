# strict_dart_lints

Strict analyzer presets and analyzer-plugin rules for any Dart code. Every rule
is an error: code that hides a problem instead of fixing its root cause does not
pass `dart analyze`.

This is the base layer. Rules that need dart_orpc concepts live in
[`dart_orpc_lints`](../dart_orpc_lints), which builds on these presets.

## Usage

```yaml
# analysis_options.yaml
include: package:strict_dart_lints/strict.yaml

plugins:
  strict_dart_lints:
    version: ^0.1.0
    diagnostics:
      no_doc_comments: true
```

- `strict.yaml`: for applications. Strict language modes, plus about 190
  curated core lints. Bug-class lints are raised to `error`.
- `library.yaml`: for published packages. `strict.yaml` plus the public API
  documentation lints.

Analyzer plugins are configured only in the root `analysis_options.yaml` of a
package or workspace. Run CI with `dart analyze --fatal-infos`.

## Plugin rules

| Rule | Bans | Tests |
|---|---|---|
| `no_code_comments` | `//` and `/* */` comments. Allowed: `// ignore: rule -- reason`, `// TODO(#issue) text`, coverage markers | checked |
| `no_doc_comments` | `///` and `/** */` (opt-in, enable for applications) | checked |
| `ignore_requires_reason` | `// ignore:` without `-- reason` of at least ten characters | checked |
| `no_null_assertion` | `value!` and `case x!` | exempt |
| `no_unchecked_cast` | `as` downcasts and cast patterns | exempt |
| `no_delay_as_fix` | `Future.delayed` and `sleep` from `dart:io`; inject a delay abstraction (dart_orpc: `Delay`, `RetryPolicy`) when waiting is intended | checked |
| `no_late_without_initializer` | `late` without an initializer | exempt |
| `no_hardcoded_strings` | string literals outside constants, named message functions (`String notFound(int id) => ...`), annotations, patterns and default values | exempt |
| `no_mirrors` | importing `dart:mirrors` | checked |
| `no_global_mutable_state` | non-final top-level variables and static fields | exempt |
| `no_broad_catch` | catching `Object`, `Exception` or everything without rethrowing or throwing | checked |

Generated files (`*.g.dart` and files with a `GENERATED CODE` header) are
skipped.

## Suppressing a rule

Fix the root cause first. When a rule truly cannot apply, the suppression must
say why:

```dart
// ignore: strict_dart_lints/no_hardcoded_strings -- shown verbatim by the CLI help screen
```

## Changing a rule

The analysis server loads each plugin once and keeps that build running. After
editing a rule, restart the analysis server (VS Code: **Dart: Restart Analysis
Server**; IntelliJ: **Restart Dart Analysis Server**) or the IDE keeps
reporting the old behaviour and messages. `dart analyze` always starts fresh.
