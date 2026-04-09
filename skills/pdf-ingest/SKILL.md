---
name: pdf-ingest
description: Dual-channel PDF reader. Extracts text AND renders page images from a PDF in one shot, so downstream work can read prose fast and still verify equations/figures visually. Use whenever a PDF is the input to a task — paper reading, report parsing, form extraction, anything where raw text alone would mangle formulas, subscripts, tables, or figures. Trigger this explicitly when the user asks to "ingest", "read", "extract", or "parse" a PDF, and also trigger it when any other skill (especially paper-reader) needs to consume a PDF.
---

# pdf-ingest

## Why dual channel

Plain-text extraction is fast and searchable but destroys complex math: subscripts collapse, matrices flatten, Greek letters go missing, figures vanish. Page images preserve everything visually but cannot be grep'd. Running both gives you the best of each — text for scanning/structure, images for ground-truth verification of any formula or figure before you cite it.

## What this skill does

Given an input PDF, produce a sibling directory `<pdf_basename>_temp/` in the current working directory containing:

- `text.txt` — text extracted with `pdftotext -layout` (preserves column layout so equations stay aligned)
- `page-01.png`, `page-02.png`, … — one PNG per page at 150 DPI via `pdftoppm`

Then return the temp directory path to the caller.

## How to run it

Use the bundled script — it handles errors, missing tools, and prints a summary:

```bash
bash ~/.claude/skills/pdf-ingest/scripts/ingest.sh <path-to-paper>.pdf
```

Optional second argument overrides DPI (default 150; bump to 200 or 250 if a formula is illegible in the rendered page image):

```bash
bash ~/.claude/skills/pdf-ingest/scripts/ingest.sh paper.pdf 250
```

The script prints three lines to stdout:

```
temp_dir=<basename>_temp
text_lines=<N>
page_images=<M>
```

## How the caller should use the output

1. `cat <temp_dir>/text.txt` or `Read` it for fast scanning: abstract, section headers, prose, most symbols.
2. Whenever a formula, figure, or table is about to be discussed, open the exact page image (`<temp_dir>/page-NN.png`) with the `Read` tool and treat the image as ground truth. Text-channel symbols that contradict the image are wrong — trust the image.
3. Do not delete the temp dir until the caller is done. It is cheap and useful for re-checking.

## Requirements

`pdftotext` and `pdftoppm` (both from `poppler-utils`). If either is missing, install `poppler-utils` via the system package manager — this skill does not attempt auto-install.

## Failure modes

- **"file not found"** — the path the user gave does not exist. Ask them to re-check.
- **"pdftotext missing"** — poppler-utils not installed.
- **Text channel looks empty** — the PDF is a scanned image. The page PNGs are still usable; the caller should rely entirely on the image channel (and optionally OCR separately).
- **Formula illegible in 150 DPI PNG** — re-run with DPI 200 or 250.
