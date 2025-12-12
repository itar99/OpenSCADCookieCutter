Cookie Cutter & Stamp Generator

A fully automated pipeline for converting a single image into a 3D-printable cookie cutter and matching stamp, using ImageMagick, Python, and OpenSCAD.

The goal of this project is to remove all manual GUI steps and make the process repeatable, fast, and boring—in the best way.

What This Does

Given any image (color, grayscale, messy, doesn’t matter), this toolchain will:

Normalize the image to pure black & white

Convert the image into:

a cutting outline

a detail stamp surface

Generate:

<name>_cutter.stl

<name>_stamp.stl

Optionally keep or delete intermediate files for debugging

All output files are written to the directory the script is run from.

Design Philosophy

One command → finished models

No manual image editing

No Inkscape clicking

No OpenSCAD hand-tweaking per design

Deterministic output (same input = same result)

Intermediate artifacts removed unless explicitly requested

This is intended for makers, not artists fighting tools.

Requirements
System Tools

ImageMagick

OpenSCAD

On Debian/Ubuntu/WSL:

sudo apt install imagemagick openscad

Python

Python 3.x

Required modules (see script header or install manually):

Pillow

numpy

svgwrite

If your system uses an externally managed Python environment, install dependencies using your preferred method (venv, pipx, or system packages).

Repository Contents
.
├── create_cookie_cutter.sh      # Main entry point
├── img_to_cookie_svg.py         # Image → SVG conversion
├── CookieCutterSCAD.scad        # STL generator (cutter + stamp)
└── README.md

Usage
Basic Usage
./create_cookie_cutter.sh myImage.png


This will generate:

myImage_cutter.stl
myImage_stamp.stl


Intermediate files are deleted automatically.

Debug Mode (keep intermediate files)
./create_cookie_cutter.sh myImage.png --debug


This will also keep:

myImage_bw.png
myImage_outline.svg
myImage_detail.svg


Useful for inspecting geometry or debugging SVG issues.

Image Input Rules

Any input image format supported by ImageMagick

Colors do not matter

Everything not close to white is treated as black

White interior areas become stamp detail

Best results come from:

High contrast

Clear silhouettes

Minimal noise

Output Models
Cookie Cutter

Cutting edge follows the outer silhouette

Reinforced outer wall for strength

Designed for FDM printing

Cookie Stamp

Raised detail based on interior white areas

Ergonomic flared handle on the back

Detail faces upward in OpenSCAD preview for clarity

Note: Resin prints are excellent for test fitting and inspection, but are not food safe. Use appropriate materials and printers for actual food use.

Customization

Most parameters can be adjusted in CookieCutterSCAD.scad, including:

Cutter wall thickness

Stamp detail depth

Handle size and shape

Overall scaling

The pipeline is designed so these changes apply globally without modifying the scripts.

Safety & Disclaimer

Resin prints are not food safe

Use food-safe materials and coatings if making functional tools

This project is provided as-is, with no guarantees other than “it worked on my machine”

Don’t try this at home unless you’re comfortable debugging CAD, Python, and shell scripts.
