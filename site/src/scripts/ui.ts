// Client interactions, ported from the redesign's site.js (chrome injection omitted).
const KEY = "shedos-theme";
const cur = () => document.documentElement.getAttribute("data-theme") || "light";

document.querySelectorAll("[data-theme-toggle]").forEach((b) =>
  b.addEventListener("click", () => {
    const next = cur() === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    try { localStorage.setItem(KEY, next); } catch {}
  })
);

const burger = document.querySelector("[data-burger]");
const menu = document.querySelector("[data-mobile-menu]");
if (burger && menu) burger.addEventListener("click", () => menu.classList.toggle("open"));

document.querySelectorAll<HTMLElement>("[data-copy]").forEach((btn) => {
  btn.addEventListener("click", () => {
    const text = btn.getAttribute("data-copy");
    if (!text || !navigator.clipboard) return;
    navigator.clipboard.writeText(text).then(() => {
      btn.classList.add("copied");
      const lbl = btn.querySelector(".lbl");
      const orig = lbl ? lbl.textContent : null;
      if (lbl) lbl.textContent = "Copied";
      setTimeout(() => { btn.classList.remove("copied"); if (lbl && orig) lbl.textContent = orig; }, 1400);
    });
  });
});

const lb = document.querySelector("[data-lightbox]");
if (lb) {
  const lbImg = lb.querySelector("img")!;
  const open = (src: string, alt: string) => { lbImg.src = src; lbImg.alt = alt || ""; lb.classList.add("open"); };
  const close = () => { lb.classList.remove("open"); setTimeout(() => { lbImg.src = ""; }, 180); };
  document.querySelectorAll<HTMLImageElement>("[data-zoom] img, img[data-zoom]").forEach((img) => {
    img.classList.add("zoomable");
    img.addEventListener("click", () => open(img.currentSrc || img.src, img.alt));
  });
  lb.addEventListener("click", (e) => {
    const t = e.target as HTMLElement;
    if (t === lb || t.closest("[data-lb-close]")) close();
  });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && lb.classList.contains("open")) close(); });
}
