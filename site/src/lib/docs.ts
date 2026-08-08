import { getCollection, type CollectionEntry } from "astro:content";

export type DocEntry = CollectionEntry<"docs">;

// Docs grouped into sections in SECTION_ORDER, pages within a section by
// `order`. This is the single source of truth for both the sidebar and the
// prev/next footer, so the two can't drift.
const SECTION_ORDER = ["Guide", "Security", "Reference"];

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
    // `order` collides across sections (each starts at 10), so first-page
    // position can't decide section order; list it explicitly instead.
    const rank = (s: string) => {
        const i = SECTION_ORDER.indexOf(s);
        return i === -1 ? SECTION_ORDER.length : i;
    };
    return [...sections.entries()].sort((a, b) => rank(a[0]) - rank(b[0]));
}

// The docs flattened in sidebar order, so prev/next walks pages the way they
// are actually listed — within a section, then on to the next section.
export async function orderedDocs(): Promise<DocEntry[]> {
    return (await docSections()).flatMap(([, items]) => items);
}
