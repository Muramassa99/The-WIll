"""Render digit_motion_slices_v1 exports without modifying their source data.

Usage: python render_digit_motion_slices.py input.json [...] --output review
Writes review.svg and review.html. Uses only Python's standard library.
"""
import argparse
import html
import json
import math
from pathlib import Path

DIGITS = ("index", "middle", "ring", "pinky", "thumb")
COLORS = ("#7c3aed", "#c2410c", "#15803d", "#a16207", "#0891b2", "#be185d", "#475569")
PANEL_W, PANEL_H, PLOT, PAD = 340, 500, 270, 44


def esc(value):
    return html.escape(str(value), quote=True)


def numbers(values):
    if isinstance(values, (list, tuple)):
        return [n for value in values for n in numbers(value)]
    return [float(values)] if isinstance(values, (float, int)) and math.isfinite(values) else []


def maximum(values):
    nums = numbers(values)
    return f"{max(abs(n) for n in nums):.3f}" if nums else "unavailable"


def sequence(values):
    return "/".join(f"{v:.2f}" for v in numbers(values)) or "unavailable"


def points(values):
    return [v for v in values or [] if isinstance(v, list) and len(v) == 2 and len(numbers(v)) == 2]


def samples(state):
    return [s for s in state.get("coplanarity_samples", []) if isinstance(s, dict)]


def extent(records):
    all_points, radius = [], 0.0
    for _, data in records:
        for digit in data.get("digits", {}).values():
            for key in ("raw", "prepared"):
                state = digit.get(key, {})
                if not isinstance(state, dict) or not state.get("valid", False):
                    continue
                all_points += points(state.get("zero_points_2d_mm"))
                for sample in samples(state):
                    all_points += points(sample.get("points_2d_mm"))
                for contour in state.get("handle_contours_2d_mm", []):
                    all_points += points(contour)
                for segment in state.get("handle_segments_2d_mm", []):
                    all_points += points(segment)
                radius = max([radius] + numbers(state.get("capsule_radii_mm", [])))
    if not all_points:
        raise ValueError("No valid measured points found in the supplied exports")
    xs, ys = zip(*all_points)
    margin = radius + 5
    span = max(max(xs) - min(xs), max(ys) - min(ys)) + margin * 2
    span = max(20, math.ceil(span / 10) * 10)
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    return cx - span / 2, cy - span / 2, span


def text(x, y, value, size=11, color="#334155", anchor="start"):
    return f'<text x="{x:.2f}" y="{y:.2f}" font-size="{size}" fill="{color}" text-anchor="{anchor}">{esc(value)}</text>'


def panel(x, y, title, state, bounds, ident, preparation=""):
    out = [f'<g transform="translate({x},{y})">', text(10, 20, title, 15, "#0f172a")]
    if not isinstance(state, dict) or not state.get("valid", False):
        reason = state.get("reason", state.get("error", state.get("status", "Not exported"))) if isinstance(state, dict) else "Not exported"
        return "".join(out + [text(10, 55, reason), "</g>"])
    xmin, ymin, span = bounds
    scale = PLOT / span
    xy = lambda p: (PAD + (p[0] - xmin) * scale, 42 + PLOT - (p[1] - ymin) * scale)
    tick = 10 * max(1, math.ceil(span / 100))
    out += [f'<rect x="{PAD}" y="42" width="{PLOT}" height="{PLOT}" fill="#f8fafc" stroke="#cbd5e1"/>']
    for axis, start in ((0, xmin), (1, ymin)):
        for value in range(math.ceil(start / tick) * tick, math.floor((start + span) / tick) * tick + 1, tick):
            pos = xy([value, value])[axis]
            color = "#94a3b8" if value == 0 else "#e2e8f0"
            if axis == 0:
                out += [f'<path d="M {pos:.2f} 42 V {42 + PLOT}" stroke="{color}"/>', text(pos, 328, value, 9, anchor="middle")]
            else:
                out += [f'<path d="M {PAD} {pos:.2f} H {PAD + PLOT}" stroke="{color}"/>', text(PAD - 5, pos + 3, value, 9, anchor="end")]
    out += [text(PAD + PLOT / 2, 343, "u (mm)", 10, anchor="middle"), text(10, 36, "v (mm)", 10)]
    out += [f'<clipPath id="clip{ident}"><rect x="{PAD}" y="42" width="{PLOT}" height="{PLOT}"/></clipPath>', f'<g clip-path="url(#clip{ident})">']
    chain = points(state.get("zero_points_2d_mm"))
    radii = numbers(state.get("capsule_radii_mm", []))
    for index in range(min(len(chain) - 1, len(radii))):
        a, b = xy(chain[index]), xy(chain[index + 1])
        out += [f'<line x1="{a[0]:.3f}" y1="{a[1]:.3f}" x2="{b[0]:.3f}" y2="{b[1]:.3f}" stroke="#2563eb" stroke-width="{2 * radii[index] * scale:.3f}" stroke-linecap="round" opacity="0.18"/>']
    for contour in state.get("handle_contours_2d_mm", []):
        outline = points(contour)
        coords = " ".join(f"{a:.3f},{b:.3f}" for a, b in map(xy, outline + outline[:1]))
        out += [f'<polyline points="{coords}" fill="none" stroke="#dc2626" stroke-width="1.7"/>']
    if state.get("slice_status") != "closed_contours":
        for segment in state.get("handle_segments_2d_mm", []):
            coords = " ".join(f"{a:.3f},{b:.3f}" for a, b in map(xy, points(segment)))
            out += [f'<polyline points="{coords}" fill="none" stroke="#dc2626" stroke-width="1.3" stroke-dasharray="3 2"/>']
    for index, sample in enumerate(samples(state)):
        coords = " ".join(f"{a:.3f},{b:.3f}" for a, b in map(xy, points(sample.get("points_2d_mm"))))
        caption = f'{sample.get("label", index)}; angles: {sample.get("angles_degrees", [])}; depth mm: {sample.get("depths_mm", [])}'
        out += [f'<polyline points="{coords}" fill="none" stroke="{COLORS[index % len(COLORS)]}" stroke-width="1" opacity="0.65"><title>{esc(caption)}</title></polyline>']
    coords = " ".join(f"{a:.3f},{b:.3f}" for a, b in map(xy, chain))
    out += [f'<polyline points="{coords}" fill="none" stroke="#1d4ed8" stroke-width="2"/>']
    for index, point in enumerate(chain):
        a, b = xy(point)
        out += [f'<circle cx="{a:.3f}" cy="{b:.3f}" r="3" fill="#1d4ed8"/>', text(a + 5, b - 4, index, 10, "#1d4ed8")]
    out += ["</g>"]
    info = [f'Lengths mm: {sequence(state.get("section_lengths_mm"))}', f'Proxy radii mm: {sequence(state.get("capsule_radii_mm"))}',
            f'Zero |depth| max: {maximum(state.get("zero_depths_mm"))} mm',
            f'Sample |depth| max: {maximum([s.get("depths_mm") for s in samples(state)])} mm',
            f'Sample |normal tilt| max: {maximum([s.get("normal_tilts_degrees") for s in samples(state)])} deg',
            f'Limits deg: {state.get("angle_limits_degrees", "unavailable")}',
            f'Slice: {state.get("slice_status", "unavailable")}; {state.get("timing_ms", "?")} ms',
            f'Plane: {state.get("plane_origin_id", "unavailable")}']
    if preparation:
        info.append(f'Preparation: {preparation}')
    for index, line in enumerate(info):
        out += [text(10, 361 + index * 15, line, 10)]
    return "".join(out + ["</g>"])


def render(records):
    bounds = extent(records)
    columns = [(d, "raw") for d in DIGITS]
    if any("prepared" in data.get("digits", {}).get("thumb", {}) for _, data in records):
        columns.append(("thumb", "prepared"))
    width, height = len(columns) * PANEL_W, 145 + len(records) * (PANEL_H + 52)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" font-family="Arial, sans-serif">', '<rect width="100%" height="100%" fill="white"/>']
    captions = [("Measured digit motion and Handle slices", 23),
                ("Blue: zero chain and calibrated capsule proxies. Red: exact Handle intersection. Thin colors: recorded samples, not solved grips.", 13),
                ("All panels use identical mm axis bounds and equal u/v scale. Proxy capsules represent calibration, not the character skin mesh.", 13),
                ("Depth and normal tilt describe departure from each fixed digit plane. A 2D projection alone does not prove coplanarity or contact.", 13)]
    for index, (caption, size) in enumerate(captions):
        out += [text(15, 32 + index * 25, caption, size)]
    for row, (path, data) in enumerate(records):
        top = 145 + row * (PANEL_H + 52)
        label = f'{data.get("slot", "?")} | input: {data.get("input", path.name)} | root: {data.get("root_origin_id", "?")} | phase: {data.get("resolve_phase", "?")}'
        out += [text(15, top, label, 13, "#0f172a"), text(15, top + 18, path.name, 10)]
        for col, (digit, kind) in enumerate(columns):
            record = data.get("digits", {}).get(digit, {})
            out += [panel(col * PANEL_W, top + 30, f"{digit.title()} / {kind}", record.get(kind), bounds, f"{row}_{col}", record.get("preparation_status", "") if kind == "prepared" else "")]
    return "".join(out + ["</svg>"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path, help="Output filename stem")
    args = parser.parse_args()
    records = [(path, json.loads(path.read_text(encoding="utf-8-sig"))) for path in args.inputs]
    for path, data in records:
        if data.get("schema") != "digit_motion_slices_v1":
            raise ValueError(f"Unsupported schema in {path}")
    svg = render(records)
    stem = args.output.with_suffix("") if args.output.suffix in (".svg", ".html") else args.output
    stem.parent.mkdir(parents=True, exist_ok=True)
    stem.with_suffix(".svg").write_text(svg, encoding="utf-8")
    sources = "".join(f"<li>{esc(path)}</li>" for path, _ in records)
    page = f'<!doctype html><html lang="en"><meta charset="utf-8"><title>Digit motion slices</title><style>body{{margin:20px;font-family:Arial;background:#e2e8f0}}.figure{{overflow:auto;background:white}}svg{{display:block}}p{{max-width:1000px}}</style><p>Measured exports only. Scroll to compare panels or open the accompanying SVG for scalable inspection. Hover a thin sample chain to inspect its label, angles and depths. This figure does not certify a solved grip.</p><div class="figure">{svg}</div><p>Source exports:</p><ul>{sources}</ul></html>'
    stem.with_suffix(".html").write_text(page, encoding="utf-8")
    print(stem.with_suffix(".svg"))
    print(stem.with_suffix(".html"))


if __name__ == "__main__":
    main()
