const packageSnapshot = [
  { label: "Facade package", value: "dart_orpc" },
  { label: "Pub status", value: "0.1.0-dev" },
  { label: "License", value: "MIT" },
  { label: "Runtime", value: "Dart VM / native clients" },
] as const;

const capabilityHighlights = [
  { label: "Contract", value: "Single source of truth" },
  { label: "Transports", value: "HTTP RPC, REST, WS, SSE" },
  { label: "Documentation", value: "OpenAPI 3.0.3 + Scalar" },
  { label: "Type Safety", value: "Typed client & Luthor DTOs" },
] as const;

const workflowHighlights = [
  {
    title: "Contract-first API definition",
    description:
      "Define modules, controllers, and DTOs once in Dart. Your module graph automatically drives RPC procedures, REST endpoints, OpenAPI schemas, and client stubs.",
  },
  {
    title: "Dual transport without duplicated logic",
    description:
      "Unary procedures use POST /rpc and optional REST mappings. Typed server streams use explicitly enabled WebSocket or SSE views.",
  },
  {
    title: "Server streaming with WebSocket & SSE",
    description:
      "Return Stream<T> from any method to deliver typed server streams over WebSocket (dart-orpc.v1 protocol) or REST Server-Sent Events (SSE).",
  },
  {
    title: "Out-of-the-box Scalar API reference",
    description:
      "Ship interactive, modern Scalar documentation at /docs connected to live OpenAPI metadata at /openapi.json with zero manual documentation upkeep.",
  },
] as const;

const ecosystem = [
  {
    title: "Core & Annotations",
    description:
      "`dart_orpc_annotations` and `dart_orpc_core` provide decorators like `@Module`, `@Controller`, `@RpcMethod`, and robust envelope handling.",
  },
  {
    title: "HTTP & WebSocket Transports",
    description:
      "`dart_orpc_http` handles unary RPC and REST/SSE dispatch, while `dart_orpc_websocket` provides the subprotocol for unary calls and server streams.",
  },
  {
    title: "OpenAPI & Documentation",
    description:
      "`dart_orpc_openapi` auto-generates OpenAPI 3.0.3 documents and provides turnkey Scalar API reference page mounting.",
  },
  {
    title: "Client & Codegen",
    description:
      "`dart_orpc_client`, `dart_orpc_generator`, and `dart_orpc_cli` automate typed client stub generation and generation and server restart workflows.",
  },
] as const;

const continueLinks = [
  { label: "Create a complete application", href: "/dart-orpc/guides/create-an-app" },
  { label: "API reference", href: "/dart-orpc/reference" },
  { label: "Good practices and tips", href: "/dart-orpc/guides/practices-and-tips" },
  { label: "Modules and dependency injection", href: "/dart-orpc/guides/modules-and-providers" },
  { label: "Server operations", href: "/dart-orpc/guides/server-operations" },
  { label: "Installation setup", href: "/dart-orpc/installation" },
  { label: "Quick start walkthrough", href: "/dart-orpc/quick-start" },
  { label: "Core concepts", href: "/dart-orpc/core-concepts" },
  { label: "Architecture & protocol", href: "/dart-orpc/architecture" },
  { label: "Packages directory", href: "/dart-orpc/packages" },
  {
    label: "Procedures and DTOs",
    href: "/dart-orpc/guides/procedures-and-dtos",
  },
  { label: "REST and SSE streaming", href: "/dart-orpc/guides/rest-and-sse" },
  {
    label: "WebSocket streaming guide",
    href: "/dart-orpc/guides/websocket-streaming",
  },
  {
    label: "Scalar & OpenAPI integration",
    href: "/dart-orpc/guides/scalar-openapi",
  },
  {
    label: "Code generation with build_runner",
    href: "/dart-orpc/guides/code-generation",
  },
  { label: "Todo server example", href: "/dart-orpc/examples/todo-app" },
  { label: "Live events & SSE example", href: "/dart-orpc/examples/sse" },
] as const;

export function DartOrpcLandingSections() {
  return (
    <div className="dart-orpc-landing">
      <div className="landing-contract">
        <strong>Contract first</strong>
        <p>
            dart_orpc is an opinionated, contract-first backend framework for
            Dart. Modules, controllers, services, and DTOs define one contract
            for RPC, REST, WebSocket, and docs.
        </p>
      </div>

      <section>
        <h2>Framework snapshot</h2>
        <p>A quick breakdown of what dart_orpc delivers and how the pieces connect.</p>
        <div className="landing-grid landing-grid-four">
          {packageSnapshot.map((item) => (
            <article className="landing-stat" key={item.label}>
              <span>{item.label}</span>
              <strong>{item.value}</strong>
            </article>
          ))}
        </div>
      </section>

      <section>
        <h2>Define APIs once and consume them everywhere</h2>
        <p>Build type-safe APIs in Dart without maintaining separate OpenAPI schemas, REST routing controllers, and client SDKs.</p>
        <div className="landing-grid landing-grid-four">
          {capabilityHighlights.map((item) => (
            <article className="landing-stat" key={item.label}>
              <span>{item.label}</span>
              <strong>{item.value}</strong>
            </article>
          ))}
        </div>
      </section>

      <section>
        <h2>Structured backends, from contract to client</h2>
        <div className="landing-grid landing-grid-two">
          {workflowHighlights.map((item) => (
            <article className="landing-card" key={item.title}>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section>
        <h2>Modular ecosystem for server, client, and tooling</h2>
        <div className="landing-grid landing-grid-two">
          {ecosystem.map((item) => (
            <article className="landing-card" key={item.title}>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section>
        <h2>Continue reading</h2>
        <p>Explore guides, package references, or hands-on examples.</p>
        <nav className="landing-links" aria-label="Continue reading">
          {continueLinks.map((item) => (
            <a key={item.href} href={item.href}>{item.label}</a>
          ))}
        </nav>
      </section>
    </div>
  );
}
