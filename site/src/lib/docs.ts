import { getCollection, type CollectionEntry } from "astro:content";

export type DocEntry = CollectionEntry<"docs">;

// Docs grouped into sections, in the order the sidebar lists them: a section
// appears when its first page does (pages sorted by `order`), and pages within
// a section follow `order`. This is the single source of truth for both the
// sidebar and the prev/next footer, so the two can't drift. `order` is only
// unique *within* a section, so a plain global sort interleaves sections —
// which is exactly what broke the footer's prev/next links.
export async function docSections(): Promise<[string, DocEntry[]][]> {
    const entries = (await getCollection("docs")).sort(
        (a, b) => a.data.order - b.data.order,
    );
    const sections = new Map<string, DocEntry[]>();
    for (const e of entries) {
        const key = e.data.section ?? "";
        if (!sections.has(key)) sections.set(key, []);
        sections.get(key)!.push(e);
    }
    return [...sections.entries()];
}

// The docs flattened in sidebar order, so prev/next walks pages the way they
// are actually listed — within a section, then on to the next section.
export async function orderedDocs(): Promise<DocEntry[]> {
    return (await docSections()).flatMap(([, items]) => items);
}
