import cloudflare from "@astrojs/cloudflare";
import react from "@astrojs/react";
import starlight from "@astrojs/starlight";
import { defineConfig } from "astro/config";

export default defineConfig({
  site: process.env.PUBLIC_SITE_URL ?? "https://shafi.dev",
  base: process.env.PUBLIC_BASE_PATH ?? "/dart-orpc",
  trailingSlash: "never",
  output: "static",
  adapter: cloudflare({
    platformProxy: {
      enabled: true,
    },
  }),
  integrations: [
    starlight({
      title: "dart_orpc Docs",
      titleDelimiter: " - ",
      description:
        "An opinionated, contract-first backend framework for Dart: modules, controllers, validated DTOs, RPC, REST/SSE, OpenAPI, and typed clients.",
      head: [
        {
          tag: "meta",
          attrs: {
            name: "robots",
            content: "index,follow",
          },
        },
      ],
      customCss: ["./src/styles/global.css", "./src/styles/starlight.css"],
      components: {
        Header: "./src/components/DocsHeader.astro",
      },
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/ishafiul/dart_orpc",
        },
      ],
      sidebar: [
        {
          label: "Start",
          items: [
            { label: "Introduction", link: "/" },
            { label: "Installation Guide", link: "/installation/" },
            { label: "Quick Start Guide", link: "/quick-start/" },
            { label: "Core Concepts", link: "/core-concepts/" },
            { label: "Architecture & Protocol", link: "/architecture/" },
          ],
        },
        {
          label: "Build an App — Handbook",
          items: [
            { label: "Handbook overview", link: "/handbook/" },
            { label: "1. Create a server", link: "/handbook/server" },
            { label: "2. Controllers and RpcMethod", link: "/handbook/controllers" },
            { label: "3. Modules and providers", link: "/handbook/modules" },
            { label: "4. Global modules", link: "/handbook/global-modules" },
            { label: "5. Data validation", link: "/handbook/validation" },
            { label: "6. Environment", link: "/handbook/environment" },
            { label: "7. Middleware", link: "/handbook/middleware" },
            { label: "8. Guards", link: "/handbook/guards" },
            { label: "9. Rate limiting", link: "/handbook/rate-limiting" },
            { label: "10. CORS", link: "/handbook/cors" },
            { label: "11. OpenAPI and Scalar", link: "/handbook/openapi" },
            { label: "12. Create a client", link: "/handbook/client" },
            { label: "13. Monorepos", link: "/handbook/monorepo" },
            { label: "14. Complete server", link: "/handbook/complete-server" },
          ],
        },
        {
          label: "Packages",
          autogenerate: { directory: "packages" },
        },
        {
          label: "Guides",
          autogenerate: { directory: "guides" },
        },
        {
          label: "API Reference",
          autogenerate: { directory: "reference" },
        },
        {
          label: "Examples",
          autogenerate: { directory: "examples" },
        },
      ],
    }),
    react(),
  ],
});
