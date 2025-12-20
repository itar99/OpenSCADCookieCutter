#!/usr/bin/env bash
set -euo pipefail

DEBUG=false
SIZE_MM=90

usage() {
  echo "Usage: $0 <image_file> [--size <mm>] [--debug|-d]"
  echo "  --size <mm>   Target smallest dimension in mm (default: ${SIZE_MM})"
  echo "  --debug, -d   Keep intermediate files"
}

# ---- Parse args (order-independent) ----
IMG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --debug|-d)
      DEBUG=true
      shift
      ;;
    --size)
      shift
      if [ $# -eq 0 ]; then
        echo "ERROR: --size requires a value in mm"
        usage
        exit 1
      fi
      SIZE_MM="$1"
      shift
      ;;
    --size=*)
      SIZE_MM="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "ERROR: Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [ -z "$IMG" ]; then
        IMG="$1"
        shift
      else
        echo "ERROR: Unexpected extra argument: $1"
        usage
        exit 1
      fi
      ;;
  esac
done

if [ -z "$IMG" ]; then
  echo "ERROR: Missing <image_file>"
  usage
  exit 1
fi

# Validate SIZE_MM is a positive number (integer or decimal)
if ! [[ "$SIZE_MM" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "ERROR: --size must be a positive number (got: '$SIZE_MM')"
  exit 1
fi
# Optional: disallow 0
if [[ "$SIZE_MM" == "0" || "$SIZE_MM" == "0.0" ]]; then
  echo "ERROR: --size must be > 0"
  exit 1
fi

echo "SIZE: $SIZE_MM"

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

META="${NAME}_meta.scad"

ART_W_U=$(awk 'BEGIN{FS="="} $1~/^ART_W_U/ {gsub(/[ ;]/,"",$2); print $2}' "$META")
ART_H_U=$(awk 'BEGIN{FS="="} $1~/^ART_H_U/ {gsub(/[ ;]/,"",$2); print $2}' "$META")

echo "META FILE: ${META}"
echo "Parsed ART_W_U=${ART_W_U} ART_H_U=${ART_H_U}  (target size=${SIZE_MM}mm)"
echo "Meta contents:"
sed -n '1,20p' "$META"

if [ -z "${ART_W_U}" ] || [ -z "${ART_H_U}" ]; then
  echo "ERROR: Could not read ART_W_U / ART_H_U from ${META}"
  exit 1
fi

echo "=== Building CUTTER STL ==="
openscad \
  -o "${NAME}_cutter.stl" \
  -D "art_file=\"${NAME}\"" \
  -D "RENDER_MODE=\"cutter\"" \
  -D "target_min_mm=${SIZE_MM}" \
  -D "ART_W_U=${ART_W_U}" \
  -D "ART_H_U=${ART_H_U}" \
  "$SCAD_FILE"

echo "=== Building STAMP STL ==="
openscad \
  -o "${NAME}_stamp.stl" \
  -D "art_file=\"${NAME}\"" \
  -D "RENDER_MODE=\"stamp\"" \
  -D "target_min_mm=${SIZE_MM}" \
  -D "ART_W_U=${ART_W_U}" \
  -D "ART_H_U=${ART_H_U}" \
  "$SCAD_FILE"

# --- Cleanup unless debugging ---
if [ "$DEBUG" = false ]; then
    echo "=== Cleaning up temporary files ==="
    rm -f "$BW_IMG" "$OUTLINE_SVG" "$DETAIL_SVG" "${NAME}_meta.scad"
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
