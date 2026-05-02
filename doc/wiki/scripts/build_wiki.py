#!/usr/bin/env python3
"""Build the emulator_mutrig engineering wiki HTML from src/*.md.

Each src/<NN>_<slug>.md becomes html/<slug>.html. The first src page
(00_*.md) is also written to html/index.html. A shared sidebar lists
all pages in src/ order.

This is a deliberately tiny renderer (no Markdown library dependency):
it handles headings, paragraphs, fenced code, inline code, bold, italics,
links, blockquotes, ordered/unordered lists, and tables. Anything more
exotic just passes through as text — keep the source plain.

Usage:
    python3 build_wiki.py
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

WIKI_DIR = Path(__file__).resolve().parent.parent
SRC_DIR = WIKI_DIR / "src"
HTML_DIR = WIKI_DIR / "html"
CSS_REL = "../css/wiki.css"

IP_NAME = "emulator_mutrig"
IP_VERSION = "26.2.x"

# -----------------------------------------------------------------------------
# Tiny Markdown → HTML renderer
# -----------------------------------------------------------------------------

INLINE_CODE_RE = re.compile(r"`([^`]+)`")
BOLD_RE = re.compile(r"\*\*([^\*]+)\*\*")
ITALIC_RE = re.compile(r"(?<!\*)\*([^\*]+)\*(?!\*)")
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^\)]+)\)")


def inline(text: str) -> str:
    text = html.escape(text)
    text = INLINE_CODE_RE.sub(r"<code>\1</code>", text)
    text = BOLD_RE.sub(r"<strong>\1</strong>", text)
    text = ITALIC_RE.sub(r"<em>\1</em>", text)
    text = LINK_RE.sub(r'<a href="\2">\1</a>', text)
    return text


def render_table(rows: list[list[str]]) -> str:
    if not rows:
        return ""
    out = ['<table>', '<thead><tr>']
    for cell in rows[0]:
        out.append(f'<th>{inline(cell.strip())}</th>')
    out.append('</tr></thead>')
    out.append('<tbody>')
    for row in rows[2:]:  # rows[1] is the |---| separator
        out.append('<tr>')
        for cell in row:
            out.append(f'<td>{inline(cell.strip())}</td>')
        out.append('</tr>')
    out.append('</tbody></table>')
    return "\n".join(out)


def render_md(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    i = 0
    in_code = False
    code_buf: list[str] = []
    list_stack: list[str] = []  # 'ul' or 'ol'
    table_buf: list[str] = []

    def flush_lists():
        while list_stack:
            tag = list_stack.pop()
            out.append(f"</{tag}>")

    def flush_table():
        nonlocal table_buf
        if not table_buf:
            return
        rows = [
            [c.strip() for c in row.strip().strip("|").split("|")]
            for row in table_buf
        ]
        out.append(render_table(rows))
        table_buf = []

    while i < len(lines):
        line = lines[i]

        # Fenced code blocks
        if line.startswith("```"):
            if in_code:
                out.append("<pre><code>" + html.escape("\n".join(code_buf)) + "</code></pre>")
                code_buf = []
                in_code = False
            else:
                flush_lists()
                flush_table()
                in_code = True
            i += 1
            continue
        if in_code:
            code_buf.append(line)
            i += 1
            continue

        # Tables
        if "|" in line and line.strip().startswith("|"):
            table_buf.append(line)
            i += 1
            continue
        elif table_buf:
            flush_table()

        # Headings
        if line.startswith("# "):
            flush_lists()
            out.append(f'<h1>{inline(line[2:].strip())}</h1>')
        elif line.startswith("## "):
            flush_lists()
            out.append(f'<h2>{inline(line[3:].strip())}</h2>')
        elif line.startswith("### "):
            flush_lists()
            out.append(f'<h3>{inline(line[4:].strip())}</h3>')
        elif line.startswith("#### "):
            flush_lists()
            out.append(f'<h4>{inline(line[5:].strip())}</h4>')
        # Lists
        elif re.match(r"^\s*-\s+", line):
            if not list_stack or list_stack[-1] != "ul":
                if list_stack:
                    out.append(f"</{list_stack.pop()}>")
                out.append("<ul>")
                list_stack.append("ul")
            out.append("<li>" + inline(re.sub(r"^\s*-\s+", "", line)) + "</li>")
        elif re.match(r"^\s*\d+\.\s+", line):
            if not list_stack or list_stack[-1] != "ol":
                if list_stack:
                    out.append(f"</{list_stack.pop()}>")
                out.append("<ol>")
                list_stack.append("ol")
            out.append("<li>" + inline(re.sub(r"^\s*\d+\.\s+", "", line)) + "</li>")
        # Blockquote
        elif line.startswith("> "):
            flush_lists()
            out.append(f'<blockquote><p>{inline(line[2:].strip())}</p></blockquote>')
        # Blank line
        elif not line.strip():
            flush_lists()
        # Paragraph
        else:
            flush_lists()
            out.append(f'<p>{inline(line)}</p>')
        i += 1

    flush_lists()
    flush_table()
    if in_code:
        out.append("<pre><code>" + html.escape("\n".join(code_buf)) + "</code></pre>")
    return "\n".join(out)


# -----------------------------------------------------------------------------
# Page assembly
# -----------------------------------------------------------------------------

PAGE_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — {ip_name} wiki</title>
<link rel="stylesheet" href="{css_rel}">
</head>
<body>
<div class="layout">
    <aside class="nav">
        <h1>Wiki</h1>
        <span class="ip-name">{ip_name}</span>
        <span class="ip-version">v{ip_version}</span>
        <ul>
{nav_items}
        </ul>
    </aside>
    <main class="content">
{body}
    </main>
    <footer class="page-foot">
        Generated by <code>doc/wiki/scripts/build_wiki.py</code>.
        Source: <code>doc/wiki/src/{src_name}</code>.
    </footer>
</div>
</body>
</html>
"""


def make_nav(pages: list[Path], current: Path) -> str:
    items: list[str] = []
    for page in pages:
        slug = page.stem.split("_", 1)[1] if "_" in page.stem else page.stem
        href = f"{slug}.html"
        # Page title comes from first H1
        title = "(untitled)"
        for line in page.read_text(encoding="utf-8").splitlines():
            if line.startswith("# "):
                title = line[2:].strip()
                break
        cls = ' class="current"' if page == current else ""
        items.append(f'            <li><a href="{href}"{cls}>{html.escape(title)}</a></li>')
    return "\n".join(items)


def title_of(page: Path) -> str:
    for line in page.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return page.stem


def build():
    HTML_DIR.mkdir(parents=True, exist_ok=True)
    pages = sorted(SRC_DIR.glob("*.md"))
    if not pages:
        print(f"no .md pages in {SRC_DIR}", file=sys.stderr)
        return 2
    for i, page in enumerate(pages):
        body = render_md(page.read_text(encoding="utf-8"))
        title = title_of(page)
        nav = make_nav(pages, page)
        rendered = PAGE_HTML.format(
            title=html.escape(title),
            ip_name=IP_NAME,
            ip_version=IP_VERSION,
            css_rel=CSS_REL,
            nav_items=nav,
            body=body,
            src_name=page.name,
        )
        slug = page.stem.split("_", 1)[1] if "_" in page.stem else page.stem
        out = HTML_DIR / f"{slug}.html"
        out.write_text(rendered, encoding="utf-8")
        # First page also becomes index
        if i == 0:
            (HTML_DIR / "index.html").write_text(rendered, encoding="utf-8")
        print(f"  built {out.relative_to(WIKI_DIR.parent.parent.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(build())
