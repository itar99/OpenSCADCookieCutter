#!/usr/bin/env bash
set -euo pipefail

DEBUG=false

# --- Parse arguments ---
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <image_file> [--debug]"
    exit 1
fi

IMG="$1"

if [ $# -eq 2 ]; then
    if [ "$2" = "--debug" ] || [ "$2" = "-d" ]; then
        DEBUG=true
    else
        echo "Unknown option: $2"
        exit 1
    fi
fi

BASE="$(basename "$IMG")"
NAME="${BASE%.*}"

SCAD_FILE="CookieCutterSCAD.scad"
BW_IMG="${NAME}_bw.png"

OUTLINE_SVG="${NAME}_outline.svg"
DETAIL_SVG="${NAME}_detail.svg"

echo "=== Processing: $IMG ==="
[ "$DEBUG" = true ] && echo "DEBUG MODE ENABLED"

echo "=== Normalizing image to black & white ==="
convert "$IMG" \
    -colorspace Gray \
    -auto-level \
    -threshold 50% \
    "$BW_IMG"

echo "=== Generating SVGs ==="
python3 img_to_cookie_svg.py "$BW_IMG" "${NAME}.svg"

echo "=== Building CUTTER STL ==="
openscad \
  -o "${NAME}_cutter.stl" \
  -D "art_file=\"${NAME}\"" \
  -D "RENDER_MODE=\"cutter\"" \
  "$SCAD_FILE"

echo "=== Building STAMP STL ==="
openscad \
  -o "${NAME}_stamp.stl" \
  -D "art_file=\"${NAME}\"" \
  -D "RENDER_MODE=\"stamp\"" \
  "$SCAD_FILE"

# --- Cleanup unless debugging ---
if [ "$DEBUG" = false ]; then
    echo "=== Cleaning up temporary files ==="
    rm -f "$BW_IMG" "$OUTLINE_SVG" "$DETAIL_SVG"
else
    echo "=== Debug mode: intermediate files preserved ==="
    echo "  $BW_IMG"
    echo "  $OUTLINE_SVG"
    echo "  $DETAIL_SVG"
fi

echo "=== Done ==="
echo "Final outputs:"
echo "  ${NAME}_cutter.stl"
echo "  ${NAME}_stamp.stl"
