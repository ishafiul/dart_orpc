# rust_http

A native HTTP/1.1 server for Dart. Rust owns the sockets and parses HTTP.
Your handlers stay in Dart and use the `dart:io` `HttpServer` API.

> `dart_orpc_http` serves every dart_orpc app with this server.

## Usage

```dart
import 'dart:io';

import 'package:rust_http/rust_http.dart';

Future<void> main() async {
  final server = await RustHttpServer.bind(3000);
  server.listen((HttpRequest request) {
    request.response.write('Hello World');
    request.response.close();
  });
}
```

Every class implements its `dart:io` interface:

| rust_http | implements |
|---|---|
| `RustHttpServer` | `HttpServer` |
| `RustHttpRequest` | `HttpRequest` |
| `RustHttpResponse` | `HttpResponse` |
| `RustHttpHeaders` | `HttpHeaders` |
| `RustWebSocket` | `WebSocket` |

Pass `shared: true` to `RustHttpServer.bind` on each listener that should
share a port. Pass `streamRequestBodies: true` to receive upload chunks
as they arrive and handle native body read failures in the request stream.

For WebSockets, check `RustWebSocket.isUpgradeRequest(request)` and call
`RustWebSocket.upgrade(request, protocolSelector: ...)`. The same calls
work with `dart:io` requests. Set `socket.pingInterval` to detect peers
that stop responding. During graceful shutdown, the app controls when
to close its upgraded sockets.

## Supported platforms

| OS | CPU | Built | Tested in CI |
|---|---|---|---|
| macOS | arm64 (Apple Silicon) | ✅ | ✅ |
| macOS | x64 (Intel) | ✅ | ✅ |
| Linux (glibc) | x64 | ✅ | ✅ |
| Linux (glibc) | arm64 | ✅ | ✅ |
| Windows | x64 | ✅ | ✅ |

CI tests the platforms listed above. Builds from source are available on
Alpine/musl, Windows on ARM, and FreeBSD.

- Linux spreads connections over `SO_REUSEPORT` sockets, one per isolate.
- macOS and Windows share one listening socket between isolates.

## The native library

Apps don't need Rust on the supported platforms above. The build hook
(`hook/build.dart`) takes the first library it finds:

1. `lib_path` from your app's `pubspec.yaml`:
   `hooks: user_defines: rust_http: lib_path: /path/to/librust_http.so`
2. A release build in `native/target/release` (same OS and CPU).
3. A prebuilt library downloaded from the GitHub release
   `rust_http-native-<fingerprint>`. It is checked against the SHA-256 in
   `lib/src/native_build/prebuilt_manifest.dart` and cached, so only the
   first build needs network access. It is skipped if you have changed the
   Rust sources. Set `hooks: user_defines: rust_http: prebuilt: false` to
   turn the download off.
4. A fresh `cargo build --release`, which needs Rust
   (<https://rustup.rs>), for other platforms, offline first builds and
   changed sources.

Use `dart run`, `dart test` or `dart build cli`. `dart build cli` bundles
the library next to the executable, so servers that run the bundle need
neither Rust nor network access. When the library is missing,
`RustHttpServer.bind` throws an `UnsupportedError` that says why.

### `dart compile aot-snapshot` and `dart compile exe`

These commands run no build hooks, so the program does not know where the
library is. On macOS and Linux, `rust_http` then loads it itself, from the
first of these that exists:

1. The path in the `RUST_HTTP_LIB` environment variable.
2. `lib/` or `../lib/` beside the snapshot or executable.
3. `lib/` or `../lib/` beside the running executable (`dartaotruntime`
   for a snapshot).

In `lib/`, the library may be named `librust_http.so` (`.dylib` on macOS)
or carry a target prefix such as `linux-x64-librust_http.so`, as
`dart build cli` bundles it. One way to get the file is from a
`dart build cli` bundle for the same target:

```sh
dart build cli -o build                        # build/bundle/lib/…librust_http.so
dart compile aot-snapshot bin/server.dart -o build/bundle/bin/server.aot
dartaotruntime build/bundle/bin/server.aot     # finds ../lib by itself

RUST_HTTP_LIB=/opt/rust_http/librust_http.so dartaotruntime server.aot
```

The library must match the OS, the CPU and the `rust_http` version: a
library with another ABI version is refused with an error. Windows is not
supported here; use `dart build cli` there.

Linux libraries need glibc 2.17 or newer. Windows libraries link the C
runtime statically.

## HTTP behavior

- `bufferOutput = false` and `flush()` send the response head and body
  promptly for Server-Sent Events.
- `response.deadline` closes the connection when the deadline expires.
- IPv4 clients are reported as standard IPv4 addresses such as `127.0.0.1`.

`test/contract/` runs the same suite against `dart:io` and `RustHttpServer`.

## Security notes

- Run it behind a reverse proxy on the open internet: the proxy ends TLS,
  limits request rates and drops slow clients.
- Set limits that fit your app: `maxBodySize`, `maxMultipartSize`,
  `bodyTimeout`, `maxConnections` and `idleTimeout`.
- `request.uri` is the target as sent: `..` is not removed. Check paths
  before using them for files.
- Framing ambiguities that could smuggle requests get `400`: two different
  `Content-Length` values, `Content-Length` with chunked, and
  `Transfer-Encoding` twice or in HTTP/1.0. Other codings get `501`.

## Development

```bash
cd packages/rust_http/native
cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test
```

```bash
cd packages/rust_http
dart analyze --fatal-infos && dart test
```

### Releasing prebuilt libraries

After the Rust sources change, and before publishing the package:

1. Run the `rust_http prebuilt` workflow on `main`. It builds every
   supported platform and publishes the release `rust_http-native-<fingerprint>`.
2. In `packages/rust_http`, run `dart run tool/prebuilt.dart update` and
   commit `lib/src/native_build/prebuilt_manifest.dart`.

Fuzzing needs nightly Rust and `cargo install cargo-fuzz`:

```bash
cd packages/rust_http/native
cargo +nightly fuzz run parse_head -- -max_total_time=60
```

### Layout

- `native/src/` — `protocol/` (records shared with Dart), `http/` (head
  parsing, body reading, rendering), `connection.rs`, `event_loop.rs`,
  `server.rs` (idle helper thread), `websocket.rs`, `compress.rs`,
  `listener.rs`, `ffi.rs` (the only C ABI).
- `lib/src/` — `ffi/` (bindings, loading, and the fallback for programs built without hooks), `engine/` (the `HttpEngine`
  interface and its FFI implementation), `protocol/` (the Dart mirror of the
  records), `http/` (server, request, response, headers), `websocket/`,
  `native_build/` (how the build hook finds the library).
