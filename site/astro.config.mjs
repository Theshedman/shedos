import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
    site: "https://shedos.org",
    integrations: [mdx(), sitemap()],
    markdown: {
        shikiConfig: {
            theme: "catppuccin-mocha",
            wrap: true,
        },
    },
    build: {
        format: "directory",
    },
});
