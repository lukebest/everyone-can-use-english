import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const MarkdownIt = require("markdown-it");
const footnote = require("markdown-it-footnote");
const sub = require("markdown-it-sub");
const sup = require("markdown-it-sup");
const mark = require("markdown-it-mark");
const ins = require("markdown-it-ins");

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const sourceDir = path.join(repo, "1000-hours/sounds-of-american-english");
const publicDir = path.join(repo, "1000-hours/public");
const outDir = path.join(repo, "harmony/entry/src/main/resources/rawfile/course");

const OUTLINE = [
  { title: "语音塑造", lessons: [{ title: "简介", slug: "0-intro" }] },
  {
    title: "1. 基础",
    lessons: [
      { title: "1. 基础", slug: "1-basics" },
      { title: "1.1. 音素音标", slug: "1.1-phonemes" },
      { title: "1.2. 英文字母", slug: "1.2-alphabets" },
    ],
  },
  { title: "2. 发声器官", lessons: [{ title: "2. 发声器官", slug: "2-articulators" }] },
  {
    title: "3. 音素详解",
    lessons: [
      { title: "3. 音素详解", slug: "3-details" },
      { title: "3.1. 元音", slug: "3.1-vowels" },
      { title: "3.1.1. ə/ɚ/ɝː", slug: "3.1.1-ə" },
      { title: "3.1.2. ʌ/ɑː/ɑːr", slug: "3.1.2-ɑ" },
      { title: "3.1.3. ɪ/i/iː/ɪr", slug: "3.1.3-i" },
      { title: "3.1.4. ʊ/u/uː/ʊr", slug: "3.1.4-u" },
      { title: "3.1.5. e/æ/er", slug: "3.1.5-e" },
      { title: "3.1.6. ɒ/ɑː/ɔː/ɔːr", slug: "3.1.6-ɔ" },
      { title: "3.1.7. aɪ…oʊ", slug: "3.1.7-aɪ" },
      { title: "3.2. 辅音", slug: "3.2-consonants" },
      { title: "3.2.1. p/b", slug: "3.2.1-pb" },
      { title: "3.2.2. t/d", slug: "3.2.2-td" },
      { title: "3.2.3. k/g", slug: "3.2.3-kg" },
      { title: "3.2.4. f/v", slug: "3.2.4-fv" },
      { title: "3.2.5. s/z", slug: "3.2.5-sz" },
      { title: "3.2.6. θ/ð", slug: "3.2.6-θð" },
      { title: "3.2.7. ʃ/ʒ", slug: "3.2.7-ʃʒ" },
      { title: "3.2.8. tʃ/dʒ", slug: "3.2.8-tʃdʒ" },
      { title: "3.2.9. tr/dr", slug: "3.2.9-trdr" },
      { title: "3.2.10. ts/dz", slug: "3.2.10-tsdz" },
      { title: "3.2.11. m, n, ŋ", slug: "3.2.11-mnŋ" },
      { title: "3.2.12. l, r", slug: "3.2.12-lr" },
      { title: "3.2.13. w, j", slug: "3.2.13-wj" },
      { title: "3.2.14. h", slug: "3.2.14-h" },
      { title: "3.3. 变体", slug: "3.3-variations" },
    ],
  },
  {
    title: "4. 自然语流",
    lessons: [
      { title: "4. 自然语流", slug: "4-natural-speech" },
      { title: "4.1. 音节", slug: "4.1-syllables" },
      { title: "4.2. 单词", slug: "4.2-words" },
      { title: "4.3. 意群", slug: "4.3-grouping" },
      { title: "4.4. 连接", slug: "4.4-linking" },
      { title: "4.5. 句子", slug: "4.5-sentences" },
    ],
  },
  { title: "5. 基础之上", lessons: [{ title: "5. 基础之上", slug: "5-above-ground" }] },
  {
    title: "6. 词汇构建",
    lessons: [
      { title: "6. 词汇构建", slug: "6-vocabulary" },
      { title: "6.1. 有效记忆单词", slug: "6.1-effectiveness" },
      { title: "6.2. 多音拼写", slug: "6.2-polyphonic-spellings" },
      { title: "6.3. 常见复合词汇", slug: "6.3-compound-words" },
      { title: "6.4. 常见词根词缀", slug: "6.4-parts-of-words" },
    ],
  },
  { title: "7. 从此之后", lessons: [{ title: "7. 从此之后", slug: "7-whats-next" }] },
  {
    title: "8. 附录",
    lessons: [
      { title: "8. 附录", slug: "8-appendix" },
      { title: "8.1. 输入音标与特殊符号", slug: "8.1-inputting-phonemes-and-symbols" },
      { title: "8.2. 获取 CEPD 音标", slug: "8.2-cepd-phonetics-and-sound" },
      { title: "8.3. 音标练习", slug: "8.3-phoneme-exercises" },
      { title: "8.4. 每日练习语音生成", slug: "8.4-daily-speech-exercises" },
    ],
  },
];

const LABELS = {
  "us-male": "美",
  "us-female": "美女",
  "uk-male": "英",
  "uk-female": "英女",
  uk: "英",
  us: "美",
  other: "播",
};

function slugify(text) {
  const cleaned = text
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[\u0000-\u001f]/g, "")
    .replace(/[\s~`!@#$%^&*()\-_+=[\]{}|\\;:"'“”‘’<>,.?/]+/g, "-")
    .replace(/-{2,}/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
  return /^\d/.test(cleaned) ? `_${cleaned}` : cleaned;
}

function resourceUrl(rel) {
  const encoded = rel
    .split("/")
    .map((part) => encodeURIComponent(part))
    .join("/");
  return `resource://rawfile/course/${encoded}`;
}

function preprocess(markdown) {
  const lines = markdown.split("\n");
  const out = [];
  let i = 0;
  while (i < lines.length) {
    const match = lines[i].match(/^> \[!([A-Za-z]+)\]\s*$/);
    if (!match) {
      out.push(lines[i]);
      i += 1;
      continue;
    }
    const kind = match[1].toLowerCase();
    const body = [];
    i += 1;
    while (i < lines.length && lines[i].startsWith(">")) {
      body.push(lines[i].replace(/^>\s?/, ""));
      i += 1;
    }
    out.push(`<div class="alert alert-${kind}">\n\n${body.join("\n")}\n\n</div>`);
  }
  return out.join("\n");
}

function speakButtons(attrs) {
  const buttons = [];
  for (const match of attrs.matchAll(/data-audio-([a-z0-9-]+)="([^"]+)"/g)) {
    const label = LABELS[match[1]] ?? "播";
    buttons.push(`<button type="button" data-src="${match[2]}">${label}</button>`);
  }
  if (buttons.length === 0) return "";
  return `<span class="speak">${buttons.join("")}</span>`;
}

function rewriteHtml(html, slugs, assets) {
  return html.replace(/(href|src|data-src)="([^"]+)"/g, (full, attr, url) => {
    const next = rewriteUrl(url, slugs, assets);
    return `${attr}="${next}"`;
  });
}

function rewriteUrl(url, slugs, assets) {
  if (!url || url.startsWith("#") || url.startsWith("mailto:")) return url;
  const hashAt = url.indexOf("#");
  const hash = hashAt >= 0 ? url.slice(hashAt) : "";
  const bare = hashAt >= 0 ? url.slice(0, hashAt) : url;
  const asset = bare.match(/^\/(audios|images|videos)\/(.+)$/);
  if (asset) {
    assets.add(`${asset[1]}/${decodeURIComponent(asset[2])}`);
    return resourceUrl(`${asset[1]}/${decodeURIComponent(asset[2])}`) + hash;
  }
  if (/^https?:\/\//.test(bare)) return url;
  let slug = bare.replace(/^\.\//, "").replace(/\.md$/, "").replace(/\.html$/, "");
  if (slug.startsWith("/sounds-of-american-english/")) {
    slug = slug.slice("/sounds-of-american-english/".length);
  }
  if (slugs.has(slug)) {
    return resourceUrl(`pages/${slug}.html`) + hash;
  }
  return url;
}

function pageHtml(title, body, prev, next) {
  const pager = [];
  if (prev) pager.push(`<a href="${resourceUrl(`pages/${prev.slug}.html`)}">上一课</a>`);
  if (next) pager.push(`<a href="${resourceUrl(`pages/${next.slug}.html`)}">下一课</a>`);
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<style>
  body { margin: 0; padding: 16px 16px 48px; background: #f6f1e8; color: #1c1917; font: 17px/1.7 sans-serif; }
  h1, h2, h3 { line-height: 1.3; }
  a { color: #9a3412; }
  .pho { color: #9a3412; font-weight: 600; }
  .speak button, .pager a { border: 0; background: #f3d6cc; color: #9a3412; border-radius: 999px; margin: 0 4px; padding: 2px 8px; text-decoration: none; font-size: 13px; }
  table { border-collapse: collapse; display: block; overflow-x: auto; max-width: 100%; }
  td, th { border: 1px solid #e6ddd0; padding: 6px; vertical-align: top; }
  img, video { max-width: 100%; height: auto; }
  .alert { background: #fff; border-left: 4px solid #c4552a; padding: 8px 12px; margin: 12px 0; }
  blockquote { margin-left: 0; padding-left: 12px; border-left: 3px solid #e6ddd0; }
  pre { overflow-x: auto; background: #fff; padding: 12px; }
  .pager { margin-top: 28px; }
</style>
</head>
<body>
${body}
<nav class="pager">${pager.join(" ")}</nav>
<script>
(function () {
  var current = null;
  var timer = null;
  document.addEventListener("click", function (event) {
    var btn = event.target.closest("button[data-src]");
    if (!btn) return;
    event.preventDefault();
    if (current) current.pause();
    current = new Audio(btn.getAttribute("data-src"));
    current.play();
  });
  document.addEventListener("selectionchange", function () {
    if (timer) clearTimeout(timer);
    timer = setTimeout(function () {
      var sel = window.getSelection();
      var text = sel ? sel.toString().trim() : "";
      if (window.EnjoyBridge && window.EnjoyBridge.onSelection) {
        window.EnjoyBridge.onSelection(text);
      }
    }, 250);
  });
})();
</script>
</body>
</html>`;
}

function escapeHtml(text) {
  return text.replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[ch]);
}

function headingText(token) {
  if (!token || !token.children) return token?.content ?? "";
  return token.children
    .filter((child) => child.type === "text" || child.type === "code_inline")
    .map((child) => child.content)
    .join("");
}

const flat = OUTLINE.flatMap((group) => group.lessons);
const slugs = new Set(flat.map((lesson) => lesson.slug));
const onDisk = new Set(
  fs.readdirSync(sourceDir).filter((name) => name.endsWith(".md")).map((name) => name.slice(0, -3)),
);
for (const slug of slugs) {
  if (!onDisk.has(slug)) console.warn("missing lesson file", slug);
}
for (const slug of onDisk) {
  if (!slugs.has(slug)) console.warn("lesson not in outline", slug);
}

const md = new MarkdownIt({ html: true, linkify: false, typographer: false });
md.use(footnote);
md.use(sub);
md.use(sup);
md.use(mark);
md.use(ins);
const slugCount = new Map();
md.renderer.rules.heading_open = (tokens, idx) => {
  const text = headingText(tokens[idx + 1]);
  const base = slugify(text) || "section";
  const seen = slugCount.get(base) ?? 0;
  slugCount.set(base, seen + 1);
  const id = seen === 0 ? base : `${base}-${seen}`;
  return `<${tokens[idx].tag} id="${id}">`;
};

fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(path.join(outDir, "pages"), { recursive: true });
const assets = new Set();

flat.forEach((lesson, index) => {
  slugCount.clear();
  const source = fs.readFileSync(path.join(sourceDir, `${lesson.slug}.md`), "utf8");
  let html = md.render(preprocess(source));
  html = html.replace(/<span class="speak-word-inline"([^>]*)>\s*<\/span>/g, (_, attrs) => speakButtons(attrs));
  html = rewriteHtml(html, slugs, assets);
  const prev = index > 0 ? flat[index - 1] : null;
  const next = index + 1 < flat.length ? flat[index + 1] : null;
  fs.writeFileSync(path.join(outDir, "pages", `${lesson.slug}.html`), pageHtml(lesson.title, html, prev, next));
});

const missing = [];
for (const rel of assets) {
  const from = path.join(publicDir, rel);
  const to = path.join(outDir, rel);
  if (!fs.existsSync(from)) {
    missing.push(rel);
    continue;
  }
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(from, to);
}

const index = {
  groups: OUTLINE.map((group) => ({
    title: group.title,
    lessons: group.lessons.map((lesson) => ({
      title: lesson.title,
      file: `pages/${lesson.slug}.html`,
    })),
  })),
};
fs.writeFileSync(path.join(outDir, "index.json"), JSON.stringify(index, null, 2));
console.log(`lessons ${flat.length}, assets ${assets.size - missing.length}, missing ${missing.length}`);
if (missing.length > 0) {
  console.log(missing.slice(0, 20).join("\n"));
}
