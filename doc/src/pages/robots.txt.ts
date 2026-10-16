import type { APIRoute } from "astro";

function getSiteOrigin(): string {
  const value = process.env.PUBLIC_SITE_URL?.trim();
  return value && value.length > 0
    ? value.replace(/\/$/, "")
    : "https://shafi.dev";
}

export const GET: APIRoute = () => {
  const origin = getSiteOrigin();
  const body = [
    "User-agent: *",
    "Allow: /dart-orpc",
    "",
    `Sitemap: ${origin}/dart-orpc/sitemap-index.xml`,
    "",
  ].join("\n");

  return new Response(body, {
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "public, max-age=0, s-maxage=3600",
    },
  });
};
