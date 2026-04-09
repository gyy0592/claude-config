#!/usr/bin/env bash
# pdf-ingest: dual-channel PDF extraction.
# Usage: ingest.sh <paper.pdf> [dpi]
#   Creates <basename>_temp/ in CWD with text.txt and page-NN.png.
#   Prints the temp dir path on stdout.
set -euo pipefail
if [ $# -lt 1 ]; then
  echo "usage: $0 <paper.pdf> [dpi]" >&2
  exit 2
fi
pdf="$1"
dpi="${2:-150}"
if [ ! -f "$pdf" ]; then
  echo "error: file not found: $pdf" >&2
  exit 1
fi
command -v pdftotext >/dev/null || { echo "error: pdftotext missing (install poppler-utils)" >&2; exit 1; }
command -v pdftoppm  >/dev/null || { echo "error: pdftoppm missing (install poppler-utils)"  >&2; exit 1; }

base="$(basename "$pdf" .pdf)"
dir="${base}_temp"
mkdir -p "$dir"
pdftotext -layout "$pdf" "$dir/text.txt"
pdftoppm -png -r "$dpi" "$pdf" "$dir/page"
# Summary for the caller.
nlines=$(wc -l < "$dir/text.txt")
npages=$(ls "$dir"/page-*.png 2>/dev/null | wc -l)
echo "temp_dir=$dir"
echo "text_lines=$nlines"
echo "page_images=$npages"
