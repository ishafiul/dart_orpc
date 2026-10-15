# Basic App authentication example

Basic App demonstrates application-owned JWT authentication with generated
RPC, REST, OpenAPI, Scalar, and Dart client contracts.

## Run

```bash
cp .env.example .env
dart run build_runner build --delete-conflicting-outputs
dart run bin/server.dart
```

Open `http://localhost:3000/docs` to see public auth operations and locked Todo
operations. Scalar exposes the generated Bearer authorization control.

Create a token through `POST /auth/signup` or `POST /auth/login`, then send it
to Todo operations:

```http
Authorization: Bearer <access-token>
```

Todo routes also demonstrate a separate permission guard. Authentication is
required first; permission headers decide whether an authenticated caller can
perform each operation:

```http
x-permissions: todo.read,todo.write,todo.admin,tenant.active
```

`BasicAppJwtAuthGuard` is deliberately kept in the application. The framework
only supplies `@BearerAuth`, guard execution, request headers, generated client
options, and OpenAPI security metadata; applications choose JWT keys and
verification policy.
