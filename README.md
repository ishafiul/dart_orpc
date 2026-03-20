# dart_orpc

`dart_orpc` is a contract-first Dart framework for defining an API once and deriving:

- RPC endpoints
- optional REST endpoints
- OpenAPI output
- typed Dart clients

The framework is RPC-first. REST and OpenAPI are generated views of the same contract model, not separate sources of truth.

## What This Repo Contains

This repository is a Melos-managed Dart workspace with:

- `packages/dart_orpc`
  Public runtime facade package.
- `packages/dart_orpc_annotations`
  Public annotations such as `@Module`, `@Controller`, `@RpcMethod`, and `@RpcInput`.
- `packages/dart_orpc_core`
  Core RPC contracts, request/response envelopes, errors, and procedure registry types.
- `packages/dart_orpc_http`
  Pure-Dart `dart:io` HTTP adapter for exposing `POST /rpc`.
- `packages/dart_orpc_client`
  Client transport and calling primitives.
- `packages/dart_orpc_cli`
  CLI tooling for local `serve` and `watch` workflows.
- `packages/dart_orpc_generator`
  `build_runner` / `source_gen` code generation for server wiring and typed Dart clients.
- `apps/basic_app`
  Example server app and current acceptance target.
- `apps/client_app`
  Example client app for exercising the generated client.

## Current Direction

The current vertical slice focuses on:

- modules
- controllers
- providers/services
- DTO-based contracts
- `POST /rpc`
- generated server registry wiring
- generated Dart client output

Planned next steps include REST route generation and OpenAPI output from the same metadata model.

## Example Shape

```dart
@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'getById')
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) {
    return userService.getById(input.id);
  }
}
```

From that contract model, the framework aims to support:

- `POST /rpc` with method `user.getById`
- generated REST routes
- generated OpenAPI output
- generated Dart client calls such as `client.user.getById(...)`

## Workspace Commands

```sh
dart pub get
melos run analyze
melos test
melos run format
melos run dev:basic-app
melos run serve:basic-app
```

Direct CLI usage:

```sh
dart run dart_orpc_cli:dart_orpc serve --project apps/basic_app
dart run dart_orpc_cli:dart_orpc watch --project apps/basic_app
```

`watch` watches the app plus workspace packages, reruns `build_runner` for the
app, and restarts the server after relevant changes.

Global install from this repo:

```sh
dart pub global activate --source path packages/dart_orpc_cli
cd /path/to/dart_orpc_app
dart_orpc serve
dart_orpc watch
```

`serve` and `watch` refuse to run unless the target directory is a valid
`dart_orpc` app. `watch` also requires `build_runner` and
`dart_orpc_generator` in the target app so code generation can run.

## Source of Truth

For product direction and architecture rules, see:

- `AGENTS.md`
- `dart_rpc_framework_prd.md`
