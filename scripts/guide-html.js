#!/usr/bin/env node
/*
 * Transforme un guide Markdown (docs/integration/*.md) en page HTML colorée pour l'intégrateur.
 *   🟨 = à confirmer (jaune) · 🟦 = à créer (bleu) · 🟥 = à vérifier avant de déployer (rouge)
 * Usage : node scripts/guide-html.js docs/integration/poste-confirmateur.md
 * Produit le même nom en .html à côté du fichier. Sans dépendance.
 */
const fs = require("fs");
const path = require("path");

const src = process.argv[2];
if (!src) {
  console.error("Usage : node scripts/guide-html.js <fichier.md>");
  process.exit(1);
}
const md = fs.readFileSync(src, "utf8").replace(/\r\n/g, "\n");

const esc = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const inline = (s) =>
  esc(s)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
const colorOf = (s, fallback) =>
  s.includes("🟥")
    ? "v"
    : s.includes("🟨")
      ? "c"
      : s.includes("🟦")
        ? "a"
        : fallback || "";

const out = [];
let section = ""; // couleur de la sous-partie en cours (titres ###)
let inList = false;
let inTable = false;
let inCode = false;
const closeBlocks = () => {
  if (inList) out.push("</ul>");
  if (inTable) out.push("</table>");
  inList = inTable = false;
};

for (const line of md.split("\n")) {
  if (line.startsWith("```")) {
    closeBlocks();
    out.push(inCode ? "</pre>" : "<pre>");
    inCode = !inCode;
    continue;
  }
  if (inCode) {
    out.push(esc(line));
    continue;
  }
  const h = line.match(/^(#{1,4}) (.*)$/);
  if (h) {
    closeBlocks();
    const n = h[1].length;
    if (n <= 3) section = n === 3 ? colorOf(h[2]) : "";
    out.push(`<h${n} class="${colorOf(h[2])}">${inline(h[2])}</h${n}>`);
    continue;
  }
  if (/^\|/.test(line)) {
    if (/^\|[\s:|-]+\|$/.test(line)) continue; // ligne de séparation
    const cells = line
      .replace(/^\||\|$/g, "")
      .split("|")
      .map((c) => c.trim());
    if (!inTable) {
      closeBlocks();
      out.push("<table>");
      inTable = true;
      out.push(
        "<tr>" + cells.map((c) => `<th>${inline(c)}</th>`).join("") + "</tr>"
      );
      continue;
    }
    out.push(
      `<tr class="${colorOf(line)}">` +
        cells.map((c) => `<td>${inline(c)}</td>`).join("") +
        "</tr>"
    );
    continue;
  }
  const li = line.match(/^\s*(?:[-*]|\d+\.) (\[ \] )?(.*)$/);
  if (li) {
    if (inTable) closeBlocks();
    if (!inList) {
      out.push("<ul>");
      inList = true;
    }
    const box = li[1] ? '<input type="checkbox"> ' : "";
    out.push(
      `<li class="${colorOf(li[2], li[1] ? section : "")}">${box}${inline(li[2])}</li>`
    );
    continue;
  }
  if (/^---+$/.test(line.trim())) {
    closeBlocks();
    out.push("<hr>");
    continue;
  }
  if (!line.trim()) {
    closeBlocks();
    continue;
  }
  closeBlocks();
  const q = line.match(/^> ?(.*)$/);
  out.push(
    q ? `<p class="note">${inline(q[1])}</p>` : `<p>${inline(line)}</p>`
  );
}
closeBlocks();

const title = (md.match(/^# (.*)$/m) || [, "Guide"])[1];
const html = `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<style>
body{font-family:system-ui,"Segoe UI",Roboto,sans-serif;max-width:1150px;margin:24px auto;padding:0 18px;color:#16181d;font-size:14px;line-height:1.5}
h1{font-size:22px}h2{font-size:17px;margin-top:28px;border-bottom:1px solid #e7e9ee;padding-bottom:4px}h3{font-size:15px;margin:18px 0 6px;padding:4px 10px;border-radius:6px}
table{border-collapse:collapse;width:100%;margin:8px 0 14px;font-size:13px}th,td{border:1px solid #e1e4ea;padding:5px 8px;text-align:left;vertical-align:top}th{background:#f6f7f9}
code{background:#f1f3f6;border-radius:4px;padding:0 4px;font-size:12.5px}pre{background:#f6f7f9;padding:10px;border-radius:8px;overflow:auto}
ul{padding-left:20px}li{margin:3px 0;padding:2px 6px;border-radius:5px;list-style:none}li input{margin-right:6px}
.note{color:#555b66;margin:2px 0}
.c{background:#fff6cc}h3.c{background:#ffe680}
.a{background:#e3efff}h3.a{background:#b9d6ff}
.v{background:#ffe1de}h3.v{background:#ffb8b0}
.legend{position:sticky;top:0;background:#fff;padding:8px 0;border-bottom:1px solid #e7e9ee;display:flex;gap:10px;flex-wrap:wrap;z-index:2}
.legend span{padding:2px 10px;border-radius:999px;font-weight:600;font-size:12.5px}
@media print{.legend{position:static}}
</style></head><body>
<div class="legend"><span class="c">🟨 À confirmer (intégrateur)</span><span class="a">🟦 À créer</span><span class="v">🟥 À vérifier avant de déployer</span></div>
${out.join("\n")}
</body></html>`;

const dest = path.join(path.dirname(src), path.basename(src, ".md") + ".html");
fs.writeFileSync(dest, html, "utf8");
console.log("Écrit : " + dest);
