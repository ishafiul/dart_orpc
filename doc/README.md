# Documentation app

This Astro/Starlight app is the source for `https://shafi.dev/dart-orpc`.
The sibling `micro_frontend` repository uses a relative symlink:

```text
Hobby/
├── dart_orpc/doc/
└── micro_frontend/apps/dart-orpc -> ../../dart_orpc/doc
```

Keep both repositories checked out in this layout on development and deployment
machines. The symlink does not include this repository's files in a clone of
`micro_frontend`.

From `micro_frontend`, install dependencies and build:

```sh
pnpm install
ln -s ../../micro_frontend/node_modules ../dart_orpc/doc/node_modules
pnpm run build:dart-orpc
```

Create the dependency symlink once on a fresh checkout. The workspace uses
hoisted dependencies; this link lets Astro resolve them from the real docs
directory outside the workspace. Skip `ln -s` if that link already exists.

Run behind the local router:

```sh
pnpm run dev:dart-orpc
```

Deploy only this app, then deploy the router when its configuration changes:

```sh
pnpm --filter mf-dart-orpc run deploy
pnpm run deploy:router
```

The package and Worker are named `mf-dart-orpc`. The router's `DART_ORPC`
service binding mounts it at `/dart-orpc`. Astro defaults to that base path and
`https://shafi.dev`; `PUBLIC_BASE_PATH` and `PUBLIC_SITE_URL` can override them
for other hosts, with matching router and Wrangler asset configuration.

Build output goes to `dist/`, with assets in `dist/dart-orpc` and the Cloudflare
Worker entry at `dist/_worker.js/index.js`.
