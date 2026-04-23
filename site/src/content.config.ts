import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const docs = defineCollection({
    loader: glob({ pattern: "**/*.mdx", base: "./src/content/docs" }),
    schema: z.object({
        title: z.string(),
        description: z.string(),
        order: z.number().default(100),
        section: z.string().default("Guide"),
    }),
});

export const collections = { docs };
