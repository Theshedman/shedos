// Prebuild hook: figure out the newest published stable ISO and the newest
// published RC on repo.shedos.org, and emit both so the download page can
// show "Stable" and "Testing" side-by-side.
//
// Resolution strategy:
//   1. Stable candidates = versions matching YYYY.MM.DD (VERSION file +
//      git tags), sorted desc. RC candidates = YYYY.MM.DD-rcN.
//   2. For the newest candidate in each list, try to fetch its .sha256
//      sibling on repo.shedos.org. A proper User-Agent is sent because
//      Cloudflare's default managed rules drop datacenter traffic with
//      no/empty UA (and the GH Actions runner lives in a datacenter).
//   3. If the fetch succeeds, the hash is inlined on the page. If it
//      fails (network, CDN, rate limit), we still emit the version +
//      ISO URL + .sha256 URL from the git tag — the Download button
//      keeps working and the UI renders a fallback "fetch .sha256 to
//      verify" command. The page is never blank just because a probe
//      timed out at build time.
//   4. The RC block is only emitted when its date is strictly newer
//      than the latest stable — otherwise there's nothing fresh to
//      test and we hide it.

import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const siteRoot = path.resolve(here, "..");
const repoRoot = path.resolve(siteRoot, "..");

const versionFile = fs.readFileSync(path.join(repoRoot, "VERSION"), "utf8").trim();

const STABLE_RE = /^\d{4}\.\d{2}\.\d{2}$/;
const RC_RE = /^\d{4}\.\d{2}\.\d{2}-rc\d+$/;

const UA = "shedos-site-build (+https://shedos.org)";

function gitTags() {
    try {
        return execSync("git tag --sort=-v:refname", {
            cwd: repoRoot,
            encoding: "utf8",
        })
            .split("\n")
            .map((t) => t.trim().replace(/^v/, ""))
            .filter(Boolean);
    } catch {
        return [];
    }
}

function dedup(list) {
    const seen = new Set();
    const out = [];
    for (const v of list) {
        if (v && !seen.has(v)) {
            seen.add(v);
            out.push(v);
        }
    }
    return out;
}

function dateOf(version) {
    return version.slice(0, 10);
}

function urlsFor(version) {
    const iso = `shedos-${version}-x86_64.iso`;
    const isoUrl = `https://repo.shedos.org/iso/${iso}`;
    const sha256Url = `${isoUrl}.sha256`;
    return { iso, isoUrl, sha256Url };
}

async function probeSha(version) {
    const { sha256Url } = urlsFor(version);
    try {
        const res = await fetch(sha256Url, {
            headers: { "User-Agent": UA, Accept: "text/plain, */*" },
            signal: AbortSignal.timeout(10_000),
            redirect: "follow",
        });
        if (!res.ok) {
            console.warn(`[sync-version] probe ${version} -> HTTP ${res.status}`);
            return null;
        }
        const body = (await res.text()).trim();
        const first = body.split(/\s+/)[0];
        if (!/^[a-fA-F0-9]{64}$/.test(first)) {
            console.warn(
                `[sync-version] probe ${version} -> body not SHA-256 (${body.length} bytes, first token: ${JSON.stringify(first.slice(0, 80))})`,
            );
            return null;
        }
        return first.toLowerCase();
    } catch (err) {
        console.warn(`[sync-version] probe ${version} -> ${err?.message ?? err}`);
        return null;
    }
}

// Walk candidates newest-first; return the first one whose .sha256
// probes cleanly. If every probe fails (e.g. the runner is blocked from
// reaching the CDN), fall back to the newest candidate with sha=null —
// the git tag itself is our source of truth that an ISO got published,
// and DownloadBox degrades to a "fetch the .sha256 to verify" UX.
async function resolveNewest(candidates) {
    if (candidates.length === 0) return null;
    for (const version of candidates) {
        const sha256 = await probeSha(version);
        if (sha256) {
            const { iso, isoUrl, sha256Url } = urlsFor(version);
            return { version, iso, isoUrl, sha256Url, sha256 };
        }
    }
    const version = candidates[0];
    const { iso, isoUrl, sha256Url } = urlsFor(version);
    console.warn(
        `[sync-version] no probe succeeded; falling back to newest candidate ${version} without inline sha`,
    );
    return { version, iso, isoUrl, sha256Url, sha256: null };
}

const tags = gitTags();

// Tags are the source of truth for what's been published. The VERSION
// file may point at a release that hasn't been tagged/published yet.
const stableCandidates = tags.filter((t) => STABLE_RE.test(t));
const rcCandidates = tags.filter((t) => RC_RE.test(t));

const stable = await resolveNewest(stableCandidates);
let rc = await resolveNewest(rcCandidates);

if (stable && rc && dateOf(rc.version) <= dateOf(stable.version)) {
    rc = null;
}

const gen = path.join(siteRoot, "src", "generated");
fs.mkdirSync(gen, { recursive: true });

function emit(prefix, r) {
    if (!r) {
        return (
            `export const ${prefix}_VERSION: string | null = null;\n` +
            `export const ${prefix}_ISO_NAME: string | null = null;\n` +
            `export const ${prefix}_ISO_URL: string | null = null;\n` +
            `export const ${prefix}_SHA256: string | null = null;\n` +
            `export const ${prefix}_SHA256_URL: string | null = null;\n`
        );
    }
    return (
        `export const ${prefix}_VERSION = ${JSON.stringify(r.version)};\n` +
        `export const ${prefix}_ISO_NAME = ${JSON.stringify(r.iso)};\n` +
        `export const ${prefix}_ISO_URL = ${JSON.stringify(r.isoUrl)};\n` +
        `export const ${prefix}_SHA256: string | null = ${JSON.stringify(r.sha256)};\n` +
        `export const ${prefix}_SHA256_URL = ${JSON.stringify(r.sha256Url)};\n`
    );
}

const out =
    `// AUTO-GENERATED by site/scripts/sync-version.mjs — do not edit.\n` +
    `// Regenerated on every \`npm run build\` / \`npm run dev\` via the prebuild hook.\n` +
    emit("STABLE", stable) +
    emit("RC", rc);

fs.writeFileSync(path.join(gen, "version.ts"), out);

console.log(
    `[sync-version] stable=${stable?.version ?? "none"}${stable?.sha256 ? "" : " (no sha)"}` +
        ` rc=${rc?.version ?? "none"}${rc && !rc.sha256 ? " (no sha)" : ""}`,
);
