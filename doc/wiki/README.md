# emulator_mutrig — Engineering Wiki

A plain-language hardware-engineering wiki for the `emulator_mutrig` IP, in
the spirit of the Synopsys VTB testenv reference at
`/data3/synopsys/pcie_gen4_5p6/doc/html/vtb/testenv/`.

This wiki is the **single landing page** for someone who has just been
handed this IP. It synthesises:

- the architecture decisions from `../RTL_PLAN_central_trigger.md`
- the CSR map and bit-field semantics from `frontend_csr.sv`
- the per-bucket DV scope from `../../tb/DV_PLAN.md` and friends
- the synthesis numbers from `../../syn/SYN_REPORT.md`
- the integration scope from `../../tb_int/DV_PLAN.md`

into HTML pages styled for hardware engineers (dense, code-friendly,
table-heavy, no marketing fluff).

## Layout

```
doc/wiki/
├── README.md           this file (entry point)
├── src/                section-source Markdown (one .md per page)
│   ├── 00_overview.md
│   ├── 10_architecture.md
│   ├── 20_csr_map.md
│   ├── 30_interfaces.md
│   ├── 40_build_axes.md
│   ├── 50_dv.md
│   ├── 60_synthesis.md
│   └── 70_open_issues.md
├── html/               generated HTML output (built from src)
│   └── index.html
├── css/                stylesheet
│   └── wiki.css
└── scripts/
    ├── build_wiki.py    src/*.md  →  html/*.html with shared layout
    └── lint_wiki.py     enforce per-page section template
```

## Building

```bash
python3 doc/wiki/scripts/build_wiki.py
# output: doc/wiki/html/index.html and one HTML per src/*.md
```

## Linting

```bash
python3 doc/wiki/scripts/lint_wiki.py doc/wiki/src
# enforces the section template documented in scripts/lint_wiki.py
```

## Per-page section template (enforced by `lint_wiki.py`)

Every page under `src/` must have these top-level Markdown headings in
order, and each section must be non-empty:

1. `# <Page Title>`
2. `## TL;DR` — two sentences max, plain language
3. `## Why this exists` — the problem this part of the IP solves
4. `## How it works` — concrete mechanism (with module names, register
   addresses, signal names where relevant)
5. `## Interfaces and contracts` — what other code talks to this part
6. `## Where to look in the code` — `path:line` pointers
7. `## Open questions / gotchas` — things a reader should know before
   editing
