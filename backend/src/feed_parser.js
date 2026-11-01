const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', rsquo: '’', lsquo: '‘', rdquo: '”', ldquo: '“', hellip: '…', mdash: '—', ndash: '–' };

export function decodeEntities(text) {
  return String(text ?? '').replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (match, body) => {
    if (body[0] === '#') {
      const code = body[1].toLowerCase() === 'x' ? Number.parseInt(body.slice(2), 16) : Number.parseInt(body.slice(1), 10);
      return Number.isFinite(code) && code > 0 && code < 0x110000 ? String.fromCodePoint(code) : match;
    }
    return ENTITIES[body.toLowerCase()] ?? match;
  });
}

function stripTags(html) {
  return decodeEntities(String(html ?? '').replace(/<[^>]+>/g, ' '))
    .replace(/[ \t\r\f\v]+/g, ' ')
    .replace(/ ?\n ?/g, '\n')
    .trim();
}

function tagValue(block, tag) {
  const match = block.match(new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)</${tag}>`, 'i'));
  if (!match) {
    return '';
  }
  return stripTags(match[1].replace(/^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/, '$1'));
}

/** Parses RSS 2.0 `<item>` and Atom `<entry>` blocks into `{ title, link, description, publishedAt }`. */
export function parseFeed(xml) {
  const blocks = String(xml ?? '').match(/<(item|entry)[\s>][\s\S]*?<\/\1>/gi) ?? [];
  return blocks
    .map((block) => {
      const atomLink = block.match(/<link[^>]*\shref=["']([^"']+)["']/i)?.[1];
      const link = decodeEntities(atomLink ?? tagValue(block, 'link') ?? '').trim();
      return {
        title: tagValue(block, 'title'),
        link,
        description: tagValue(block, 'description') || tagValue(block, 'summary'),
        publishedAt: tagValue(block, 'pubDate') || tagValue(block, 'updated') || tagValue(block, 'published') || null
      };
    })
    .filter((item) => /^https?:\/\//i.test(item.link) && item.title);
}

const CJK = /[\u3400-\u9fff]/g;
// A prose paragraph ends like a sentence (Latin or CJK punctuation, optionally closed by a quote).
const SENTENCE_END = /[.!?。！？…]["”’」』）)]?$|["”」』]$/;
const BOILERPLATE = /cookie|subscribe|newsletter|©|版权所有|责任编辑|责编|来源[:：]|转载|扫码|关注我们|点击查看/i;

/** Chinese packs more meaning into fewer characters, so its paragraphs are shorter. */
function minParagraphLength(paragraph) {
  const cjkChars = paragraph.match(CJK)?.length ?? 0;
  return cjkChars > paragraph.length / 2 ? 30 : 60;
}

/**
 * Pulls readable paragraphs out of an article page: prefers the `<article>` element, drops scripts,
 * navigation and boilerplate, keeps only paragraphs that look like prose (English or Chinese).
 */
export function extractArticleText(html, { maxChars = 6000 } = {}) {
  const page = String(html ?? '')
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/<(script|style|noscript|nav|header|footer|aside|form|figure|svg|iframe)[\s\S]*?<\/\1>/gi, ' ');
  const scope = page.match(/<article[\s\S]*?<\/article>/i)?.[0] ?? page.match(/<main[\s\S]*?<\/main>/i)?.[0] ?? page;
  const paragraphs = (scope.match(/<p[\s>][\s\S]*?<\/p>/gi) ?? [])
    .map((paragraph) => stripTags(paragraph).replace(/\s+/g, ' '))
    .filter(
      (paragraph) =>
        paragraph.length >= minParagraphLength(paragraph) && SENTENCE_END.test(paragraph) && !BOILERPLATE.test(paragraph)
    );
  const text = [];
  let length = 0;
  for (const paragraph of paragraphs) {
    if (length + paragraph.length > maxChars) {
      break;
    }
    text.push(paragraph);
    length += paragraph.length + 2;
  }
  return text.join('\n\n');
}
