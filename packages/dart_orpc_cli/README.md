# dart_orpc_cli

Command-line tooling for `dart_orpc` application development, including
serving a generated application and watching source files for regeneration and
restart.

```sh
dart run dart_orpc_cli:dart_orpc --help
```

## Create an app

Generate a minimal hello-world server:

```sh
dart_orpc create hello_app
cd hello_app
dart run build_runner build
dart run bin/server.dart
```

The generated app exposes `hello.say` through `POST /rpc` and `GET /hello`.
Pass `--no-pub-get` to skip dependency resolution during creation.
