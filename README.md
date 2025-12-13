# Cookie Cutter & Stamp Generator

A fully automated pipeline for converting a single image into a **3D-printable cookie cutter and matching stamp**, using ImageMagick, Python, and OpenSCAD.

The goal of this project is to remove all manual GUI steps and make the process **repeatable, fast, and boring** — in the best way.

---

## What This Does

Given **any image** (color, grayscale, messy — it doesn’t matter), this toolchain will:

1. Normalize the image to **pure black & white**
2. Convert the image into:
   - a cutting **outline**
   - a filled **detail stamp surface**
3. Generate:
   - `<name>_cutter.stl`
   - `<name>_stamp.stl`
4. Optionally keep or delete intermediate files for debugging

All output files are written to the directory the script is run from.

---

## Design Philosophy

- One command → finished models  
- No manual image editing  
- No Inkscape clicking  
- No per-design OpenSCAD tweaking  
- Deterministic output (same input = same result)  
- Intermediate artifacts removed unless explicitly requested  

This project is intended for **makers**, not artists fighting tools.

---

## Requirements

### System Tools

- **ImageMagick**
- **OpenSCAD**

On Debian / Ubuntu / WSL:

```bash
sudo apt install imagemagick openscad
```

### Python

- Python 3.x
- Required modules:
  - `Pillow`
  - `numpy`
  - `svgwrite`

If your system uses an externally managed Python environment, install dependencies using your preferred method (`venv`, `pipx`, or system packages).

---

## Repository Contents

```
.
├── create_cookie_cutter.sh      # Main entry point
├── img_to_cookie_svg.py         # Image → SVG conversion
├── CookieCutterSCAD.scad        # STL generator (cutter + stamp)
└── README.md
```

---

## Usage

### Basic Usage

```bash
./create_cookie_cutter.sh myImage.png
```

This will generate:

```
myImage_cutter.stl
myImage_stamp.stl
```

Intermediate files are deleted automatically.

---

### Debug Mode (keep intermediate files)

```bash
./create_cookie_cutter.sh myImage.png --debug
```

This will also keep:

```
myImage_bw.png
myImage_outline.svg
myImage_detail.svg
```

Debug mode is useful for inspecting geometry or troubleshooting SVG generation.

---

## Image Input Rules

- Any input image format supported by ImageMagick
- Colors do **not** matter
- Everything not close to white is treated as **black**
- White interior areas become **stamp detail**
- Best results come from:
  - High contrast
  - Clear silhouettes
  - Minimal noise

---

## Output Models

### Cookie Cutter

- Cutting edge follows the outer silhouette
- Reinforced outer wall for strength
- Designed for FDM printing

### Cookie Stamp

- Raised detail based on interior white areas
- Ergonomic flared handle on the back
- Detail faces upward in OpenSCAD preview for clarity

> **Note:** Resin prints are excellent for test fitting and inspection, but are **not food safe**.  
> Use appropriate materials and printers for functional food tools.

---

## Customization

Most parameters can be adjusted in `CookieCutterSCAD.scad`, including:

- Cutter wall thickness  
- Stamp detail depth  
- Handle size and shape  
- Overall scaling  

The pipeline is designed so these changes apply globally without modifying the scripts.

---

## Safety & Disclaimer

- Resin prints are **not food safe**
- Use food-safe materials and coatings if making functional tools
- This project is provided *as-is*, with no guarantees other than  
  “it worked on my machine”

Don’t try this at home unless you’re comfortable debugging CAD, Python, and shell scripts.

Note: Yes I used AI to write the Readme because...ugh...writing.  Also used AI for research about the various technologies involved.
