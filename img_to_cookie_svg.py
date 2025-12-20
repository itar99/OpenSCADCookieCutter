#!/usr/bin/env python3
"""
Convert a single input image into a layered SVG for cookie cutter generation.

- Input:  PNG/JPG with a simple black-on-white style drawing
- Output: SVG with two layers:
    * "outline" : cleaned up outer silhouette (for cutter)
    * "detail"  : all contours / interior lines (for stamp)

Usage example:
    python img_to_cookie_svg.py input.png output.svg \
        --threshold 180 \
        --outline-offset 5 \
        --simplify 0.01
"""

import argparse
import os
import sys

import cv2
import numpy as np
import svgwrite


def parse_args():
    p = argparse.ArgumentParser(description="Convert image into layered SVG for cookie cutters.")
    p.add_argument("input", help="Input image (PNG/JPG).")
    p.add_argument("output", help="Output SVG file.")
    p.add_argument("--threshold", type=int, default=180,
                   help="Grayscale threshold (0-255) for binarization; lower -> more foreground (default: 180).")
    p.add_argument("--invert", action="store_true",
                   help="Invert binary (use if your drawing is white on black instead of black on white).")
    p.add_argument("--blur", type=int, default=3,
                   help="Gaussian blur kernel size (odd int; 0 to disable, default: 3).")
    p.add_argument("--outline-offset", type=int, default=5,
                   help="Pixel expansion for outer outline (like Inkscape Outset, default: 5).")
    p.add_argument("--simplify", type=float, default=0.01,
                   help="Polygon simplification factor as fraction of contour perimeter (default: 0.01).")
    p.add_argument("--min-area", type=float, default=50.0,
                   help="Ignore contours smaller than this area in pixels (default: 50).")
    p.add_argument("--debug", action="store_true",
               help="Save debug PNGs of intermediate masks.")
    return p.parse_args()


def load_grayscale(path):
    img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        print(f"ERROR: Unable to read image '{path}'", file=sys.stderr)
        sys.exit(1)
    return img


def binarize(img_gray, thresh_val, blur_k, invert=False):
    """Return binary image: 255 = foreground, 0 = background."""
    if blur_k and blur_k > 0 and blur_k % 2 == 1:
        img_gray = cv2.GaussianBlur(img_gray, (blur_k, blur_k), 0)

    # Threshold: assume dark drawing on light background
    _, binary = cv2.threshold(img_gray, thresh_val, 255, cv2.THRESH_BINARY_INV)

    if invert:
        binary = cv2.bitwise_not(binary)

    return binary


def find_contours(binary, mode):
    """Wrapper for cv2.findContours that handles OpenCV version differences."""
    res = cv2.findContours(binary, mode, cv2.CHAIN_APPROX_SIMPLE)
    if len(res) == 3:
        _, contours, hierarchy = res
    else:
        contours, hierarchy = res
    return contours, hierarchy


def simplify_contour(contour, factor):
    """Simplify contour using approxPolyDP with epsilon = factor * perimeter."""
    peri = cv2.arcLength(contour, True)
    epsilon = factor * peri
    approx = cv2.approxPolyDP(contour, epsilon, True)
    return approx


def contour_to_path_d(contour):
    """
    Convert a contour (Nx1x2 array) into an SVG path string.
    Assumes image coordinates (origin top-left, y down) which is fine for SVG.
    """
    pts = contour.reshape(-1, 2)
    if len(pts) == 0:
        return ""

    d = []
    x0, y0 = pts[0]
    d.append(f"M {float(x0):.2f},{float(y0):.2f}")
    for x, y in pts[1:]:
        d.append(f"L {float(x):.2f},{float(y):.2f}")
    d.append("Z")
    return " ".join(d)

def write_meta_scad(meta_path: str, w_u: float, h_u: float) -> None:
    """
    Writes OpenSCAD include file with outline bounds in SVG/viewBox units.
    """
    with open(meta_path, "w", encoding="utf-8") as f:
        f.write(f"ART_W_U = {w_u:.6f};\n")
        f.write(f"ART_H_U = {h_u:.6f};\n")


def bbox_from_polys(polys):
    """
    Accepts either:
      - list of polygons: [[(x,y), (x,y), ...], ...]
      - OpenCV contours: [array(N,1,2), array(N,1,2), ...]
      - OpenCV contours: [list([ [x,y], ... ]), ...] with extra nesting
    Returns: min_x, min_y, max_x, max_y
    """
    min_x = float("inf")
    min_y = float("inf")
    max_x = float("-inf")
    max_y = float("-inf")

    n_points = 0

    for poly in polys:
        if poly is None:
            continue

        arr = np.asarray(poly)

        # OpenCV contour formats commonly become:
        # (N,1,2) or (N,2)
        if arr.ndim == 3 and arr.shape[-1] == 2:
            arr = arr.reshape(-1, 2)
        elif arr.ndim == 2 and arr.shape[-1] == 2:
            pass
        else:
            # Fall back: try iterating as (x,y) pairs
            try:
                for pt in poly:
                    x, y = pt
                    min_x = min(min_x, float(x))
                    min_y = min(min_y, float(y))
                    max_x = max(max_x, float(x))
                    max_y = max(max_y, float(y))
                    n_points += 1
                continue
            except Exception as e:
                raise TypeError(f"Unsupported contour/polygon format: {type(poly)} shape={getattr(arr, 'shape', None)}") from e

        # Fast path for numpy arrays
        xs = arr[:, 0].astype(float)
        ys = arr[:, 1].astype(float)
        min_x = min(min_x, float(xs.min()))
        min_y = min(min_y, float(ys.min()))
        max_x = max(max_x, float(xs.max()))
        max_y = max(max_y, float(ys.max()))
        n_points += arr.shape[0]

    if n_points == 0:
        raise ValueError("bbox_from_polys: empty polygon/contour list")

    return min_x, min_y, max_x, max_y


def create_svg(width, height, outline_contours, detail_contours, output_path):
    """
    Generate layered SVG using svgwrite with:
    - outline layer
    - detail layer
    """
    dwg = svgwrite.Drawing(output_path,
                           size=(f"{width}px", f"{height}px"),
                           viewBox=f"0 0 {width} {height}",
                           debug=False)
    # Inkscape layer namespace
    dwg.attribs["xmlns:inkscape"] = "http://www.inkscape.org/namespaces/inkscape"

    # Outline layer
    outline_group = dwg.g(id="outline",
                          **{"inkscape:groupmode": "layer",
                             "inkscape:label": "outline"})
    for cnt in outline_contours:
        d = contour_to_path_d(cnt)
        if not d:
            continue
        path = dwg.path(d=d,
                        fill="none",
                        stroke="black",
                        stroke_width=1)
        outline_group.add(path)
    dwg.add(outline_group)

    # Detail layer
    detail_group = dwg.g(id="detail",
                         **{"inkscape:groupmode": "layer",
                            "inkscape:label": "detail"})
    for cnt in detail_contours:
        d = contour_to_path_d(cnt)
        if not d:
            continue
        path = dwg.path(d=d,
                        fill="none",
                        stroke="black",
                        stroke_width=1)
        detail_group.add(path)
    dwg.add(detail_group)

    dwg.save()
    print(f"Saved layered SVG to: {output_path}")

def write_svg_single_group(width, height, contours, output_path):
    import svgwrite
    dwg = svgwrite.Drawing(
        output_path,
        size=(f"{width}px", f"{height}px"),
        viewBox=f"0 0 {width} {height}",
        profile="full",
        debug=False,
    )

    # Filled shapes work best for OpenSCAD import
    for cnt in contours:
        d = contour_to_path_d(cnt)
        if not d:
            continue
        dwg.add(dwg.path(d=d, fill="black", stroke="none"))
    dwg.save()

def contours_to_compound_path_d(contours):
    """Concatenate multiple contours into one SVG path 'd' with multiple subpaths."""
    parts = []
    for cnt in contours:
        d = contour_to_path_d(cnt)
        if d:
            parts.append(d)
    return " ".join(parts)

def write_svg_detail_evenodd(width, height, contours, output_path):
    import svgwrite
    dwg = svgwrite.Drawing(
        output_path,
        size=(f"{width}px", f"{height}px"),
        viewBox=f"0 0 {width} {height}",
        profile="full",
        debug=False,
    )

    d = contours_to_compound_path_d(contours)
    if d:
        p = dwg.path(d=d, fill="black", stroke="none")
        # This is the key: keeps holes as holes
        p.update({"fill-rule": "evenodd"})
        dwg.add(p)

    dwg.save()


def main():
    args = parse_args()

    img_gray = load_grayscale(args.input)
    h, w = img_gray.shape[:2]

    # Sanity: force to uint8 just in case
    img_gray = img_gray.astype("uint8")

    # --- 1) BLACK → cookie silhouette (outline) ---

    # shape_mask: 255 where pixel is "black-ish" (cookie), 0 elsewhere
    # We invert threshold: dark becomes 255.
    # With clean 0/255 art, threshold 127 is fine; you can tune via --threshold.
    _, shape_mask = cv2.threshold(
        img_gray, args.threshold, 255, cv2.THRESH_BINARY_INV
    )

    # Optional: a little dilation can close tiny gaps
    if args.outline_offset > 0:
        kernel_size = max(1, args.outline_offset * 2 + 1)
        kernel = np.ones((kernel_size, kernel_size), np.uint8)
        shape_mask = cv2.dilate(shape_mask, kernel, iterations=1)

    # Find external contours on the black-region mask
    outline_contours, _ = find_contours(shape_mask, cv2.RETR_EXTERNAL)

    outline_contours_filtered = []
    silhouette_mask = np.zeros((h, w), dtype=np.uint8)

    if outline_contours:
        # Take the single largest black region as the cookie
        largest = max(outline_contours, key=cv2.contourArea)
        cnt_simplified = simplify_contour(largest, args.simplify)
        outline_contours_filtered.append(cnt_simplified)

        # Fill it to get "inside of cookie" mask
        cv2.drawContours(
            silhouette_mask,
            [cnt_simplified],
            contourIdx=-1,
            color=255,
            thickness=cv2.FILLED,
        )
    else:
        print("WARNING: No outline contours found (no black region?)", file=sys.stderr)

    # --- 2) WHITE INSIDE silhouette → detail ---

    # white_mask: 255 where pixel is "white-ish" (background + interior), 0 elsewhere
    _, white_mask = cv2.threshold(
        img_gray, args.threshold, 255, cv2.THRESH_BINARY
    )

    # Keep only white that lies inside the cookie silhouette
    white_inside = cv2.bitwise_and(white_mask, silhouette_mask)

    # Shrink detail so it's smaller than outline (1px erosion to start)
    detail_kernel = np.ones((3, 3), np.uint8)
    white_inside_eroded = cv2.erode(white_inside, detail_kernel, iterations=0)

        # Extract detail contours: filled white islands inside the cookie.
    # Use RETR_TREE so we don't lose nested structure, and don't simplify
    # (or simplify very lightly) so we keep fine features.
    detail_contours, detail_hierarchy = find_contours(
        white_inside_eroded, cv2.RETR_TREE
    )

    detail_contours_filtered = []
    for cnt in detail_contours:
        area = cv2.contourArea(cnt)
        if area < 2.0:
            continue  # ignore only truly tiny specks

        # Either don't simplify at all:
        # detail_contours_filtered.append(cnt)

        # Or simplify extremely lightly:
        cnt_simplified = simplify_contour(cnt, factor=0.002)
        detail_contours_filtered.append(cnt_simplified)

    if not detail_contours_filtered:
        print("WARNING: No detail contours found (white inside outline).", file=sys.stderr)

    # --- 3) Optional debug images so you can see what's happening ---

    if args.debug:
        dbg = np.zeros((h, w, 3), dtype=np.uint8)

        # red = outline (silhouette)
        dbg[ silhouette_mask == 255 ] = (0, 0, 255)

        # green = interior white detail
        dbg[ white_inside_eroded == 255 ] = (0, 255, 0)

        cv2.imwrite("debug_shape_mask.png", shape_mask)
        cv2.imwrite("debug_silhouette_mask.png", silhouette_mask)
        cv2.imwrite("debug_white_inside.png", white_inside)
        cv2.imwrite("debug_white_inside_eroded.png", white_inside_eroded)
        cv2.imwrite("debug_overlay.png", dbg)
        print("Wrote debug_* PNGs in current directory.")

    # --- 4) Create SVG ---

    create_svg(w, h, outline_contours_filtered, detail_contours_filtered, args.output) # create the combined SVG
    
    base = os.path.splitext(args.output)[0]
    write_svg_single_group(w, h, outline_contours_filtered, base + "_outline.svg")
    write_svg_detail_evenodd(w, h, detail_contours_filtered,  base + "_detail.svg")
    print("Wrote:", base + "_outline.svg", "and", base + "_detail.svg")

    min_x, min_y, max_x, max_y = bbox_from_polys(outline_contours_filtered)
    art_w_u = max_x - min_x
    art_h_u = max_y - min_y

    meta_path = f"{base}_meta.scad"
    write_meta_scad(meta_path, art_w_u, art_h_u)
    print("Wrote: ", base + "_meta.scad")


if __name__ == "__main__":
    main()
