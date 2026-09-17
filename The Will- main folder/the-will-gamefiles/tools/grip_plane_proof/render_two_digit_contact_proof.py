"""Read two_digit_contact_proof_v1 JSON and write a standalone SVG + HTML review.

No dependencies, engine calls, invented candidates, or source-data writes.
"""
import argparse
import html
import json
import math
from pathlib import Path

WIDTH, HEIGHT, PLOT, LEFT, TOP = 610, 870, 470, 65, 82


def esc(value):
    return html.escape(str(value), quote=True)


def num(value, fallback=0):
    return float(value) if isinstance(value, (int, float)) and math.isfinite(value) else fallback


def fmt(value, decimals=3):
    return f"{value:.{decimals}f}" if isinstance(value, (int, float)) and math.isfinite(value) else "unavailable"


def triple(values, factor=1):
    return " / ".join(fmt(num(value) * factor, 2) for value in values or []) or "unavailable"


def points(value):
    return [p for p in value or [] if isinstance(p, list) and len(p) == 2 and all(isinstance(n, (int, float)) and math.isfinite(n) for n in p)]


def text(x, y, value, size=12, color="#334155", anchor="start"):
    return f'<text x="{x:.2f}" y="{y:.2f}" font-size="{size}" fill="{color}" text-anchor="{anchor}">{esc(value)}</text>'


def zero_chain(digit):
    for sample in digit.get("preparation", {}).get("plane_metrics", {}).get("samples", []):
        angles = sample.get("angles_rad", [])
        if len(angles) == 3 and all(abs(num(a)) < 1e-9 for a in angles):
            return points(sample.get("points_plane_m"))
    return []


def disk_radius(digit):
    section = digit.get("slice", {})
    return num(section.get("search_radius_m"), num(section.get("reach_m")) + num(section.get("skin_padding_m")))


def skin_rays(digit):
    prep = digit.get("preparation", {})
    measured = digit.get("skin_surface_measurement", prep.get("skin_surface_measurement", prep))
    rays, normal_hits = [], 0
    for section_index, section in enumerate(measured.get("sections", [])):
        for cross_section in section.get("cross_sections", []):
            for name, ray in cross_section.get("rays", {}).items():
                if not ray.get("hit", False):
                    continue
                if name in ("normal_plus", "normal_minus"):
                    normal_hits += 1
                elif name in ("u_plus", "u_minus"):
                    start, hit = ray.get("start_in_plane_m", []), ray.get("position_in_plane_m", [])
                    if len(start) == 3 and len(hit) == 3:
                        rays.append((start, hit, name, section_index))
    return rays, normal_hits


def panel(digit, name, slot, row, column, radius_mm):
    prep, candidate, summary = (digit.get(k, {}) for k in ("preparation", "candidate", "summary"))
    section, hand = digit.get("slice", {}), digit.get("hand", {})
    status = candidate.get("status", prep.get("error", "preparation unavailable"))
    validation = summary.get("validation", {})
    skin_verified = validation.get("actual_skin_contact_verified", False)
    rejected_proxy = candidate.get("boundary_status", candidate.get("status")) == "blocked_fixed_origin"
    out = [f'<g transform="translate({column * WIDTH},{165 + row * HEIGHT})">', text(15, 20, f"{slot} · {name.title()}", 19, "#0f172a"), text(15, 43, f"Candidate: {status}", 13)]
    has_candidate = bool(candidate.get("angles_rad")) and len(points(candidate.get("points_m"))) == 4
    caption = "Candidate shown; inspect validation below." if has_candidate else "NO CANDIDATE — gray zero chain is an illustration, not a grip."
    if rejected_proxy:
        caption = "REJECTED CENTERED CAPSULE — fixed origin blocked; no grip evaluated."
    out += [text(15, 64, caption, 11, "#9a3412")]
    scale = PLOT / (radius_mm * 2)
    xy = lambda p: (LEFT + PLOT / 2 + p[0] * 1000 * scale, TOP + PLOT / 2 - p[1] * 1000 * scale)
    center = xy([0, 0])
    out += [f'<rect x="{LEFT}" y="{TOP}" width="{PLOT}" height="{PLOT}" fill="#f8fafc" stroke="#cbd5e1"/>']
    tick = 10 * max(1, math.ceil(radius_mm / 60))
    for value in range(math.ceil(-radius_mm / tick) * tick, math.floor(radius_mm / tick) * tick + 1, tick):
        x, y = xy([value / 1000, value / 1000])
        color = "#94a3b8" if value == 0 else "#e2e8f0"
        out += [f'<path d="M {x:.2f} {TOP} V {TOP + PLOT} M {LEFT} {y:.2f} H {LEFT + PLOT}" stroke="{color}"/>', text(x, TOP + PLOT + 18, value, 10, anchor="middle"), text(LEFT - 7, y + 3, value, 10, anchor="end")]
    out += [text(LEFT + PLOT / 2, TOP + PLOT + 35, "u (mm)", 12, anchor="middle"), text(LEFT - 35, TOP - 8, "v (mm)", 12)]
    ident = f"plot_{row}_{column}"
    out += [f'<clipPath id="{ident}"><rect x="{LEFT}" y="{TOP}" width="{PLOT}" height="{PLOT}"/></clipPath>', f'<g clip-path="url(#{ident})">']
    out += [f'<circle cx="{center[0]:.3f}" cy="{center[1]:.3f}" r="{disk_radius(digit) * 1000 * scale:.3f}" fill="none" stroke="#64748b" stroke-dasharray="6 5"/>']
    zero = zero_chain(digit)
    selected = points(candidate.get("points_m")) if has_candidate else zero
    radii = hand.get("radii_m", prep.get("radii_m", []))
    color = "#2563eb" if has_candidate else "#64748b"
    for i in range(min(len(selected) - 1, len(radii))):
        a, b = xy(selected[i]), xy(selected[i + 1])
        opacity = "0.08" if rejected_proxy else "0.17"
        out += [f'<line x1="{a[0]:.3f}" y1="{a[1]:.3f}" x2="{b[0]:.3f}" y2="{b[1]:.3f}" stroke="{color}" stroke-width="{2 * num(radii[i]) * 1000 * scale:.3f}" stroke-linecap="round" opacity="{opacity}"/>']
    for edge in section.get("segments", []):
        pair = points(edge)
        if len(pair) == 2:
            a, b = xy(pair[0]), xy(pair[1])
            out += [f'<line x1="{a[0]:.3f}" y1="{a[1]:.3f}" x2="{b[0]:.3f}" y2="{b[1]:.3f}" stroke="#dc2626" stroke-width="1.6"/>']
    for chain, stroke, dash in ((zero, "#64748b", "4 3"), (selected if has_candidate else [], "#1d4ed8", "none")):
        coords = " ".join(f"{a:.3f},{b:.3f}" for a, b in map(xy, chain))
        out += [f'<polyline points="{coords}" fill="none" stroke="{stroke}" stroke-width="2" stroke-dasharray="{dash}"/>']
        for i, point in enumerate(chain):
            a, b = xy(point)
            out += [f'<circle cx="{a:.3f}" cy="{b:.3f}" r="3" fill="{stroke}"/>', text(a + 5, b - 5, i, 10, stroke)]
    hit_count = 0
    for record in prep.get("sections", []):
        for key in ("ray_hits_plane_m", "skin_ray_hits_plane_m"):
            for hit in points(record.get(key)):
                a, b = xy(hit)
                out += [f'<circle cx="{a:.3f}" cy="{b:.3f}" r="1.8" fill="#c2410c"/>']
                hit_count += 1
    measured_rays, normal_hits = skin_rays(digit)
    paths = {}
    for start, hit, name, section_index in measured_rays:
        a, b = xy(start), xy(hit)
        color = "#c2410c" if name == "u_plus" else "#7c3aed"
        paths.setdefault((section_index, name), []).append(hit)
        label = f'Measured zero-pose in-plane-direction ray; start depth {start[2] * 1000:.6f} mm; hit depth {hit[2] * 1000:.6f} mm'
        out += [f'<g><title>{esc(label)}</title><line x1="{a[0]:.3f}" y1="{a[1]:.3f}" x2="{b[0]:.3f}" y2="{b[1]:.3f}" stroke="{color}" stroke-width="0.8"/><circle cx="{b[0]:.3f}" cy="{b[1]:.3f}" r="2" fill="{color}"/></g>']
        hit_count += 1
    for (_, name), hits in paths.items():
        coords = " ".join(f"{a:.3f},{b:.3f}" for a, b in map(xy, hits))
        color = "#c2410c" if name == "u_plus" else "#7c3aed"
        out += [f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="1.7"><title>Connects measured hits within one section; not a fitted or certified skin boundary.</title></polyline>']
    out += ["</g>"]
    timings = " / ".join(fmt(summary.get(k), 2) for k in ("preparation_ms", "slice_ms", "solve_ms"))
    metrics = prep.get("plane_metrics", {})
    lines = [f'Lengths mm: {triple(hand.get("lengths_m"), 1000)}; proxy radii mm: {triple(radii, 1000)}',
             f'Reach + padding: {fmt(section.get("reach_m", 0) * 1000, 2)} + {fmt(section.get("skin_padding_m", 0) * 1000, 2)} mm; in-plane rays: {hit_count}; normal hits (not drawn): {normal_hits}',
             f'Angles deg: {triple(summary.get("angles_degrees"))}; contact sections: {candidate.get("contact_count", "unavailable")}',
             f'2D safe: {candidate.get("safe", "unavailable")}; 3D capsules safe: {validation.get("capsules_safe_in_3d", "not evaluated")}',
             f'ACTUAL SKIN CONTACT VERIFIED: {str(skin_verified).upper()}',
             f'Plane sample depth max: {fmt(num(metrics.get("max_sample_depth_m")) * 1000)} mm; normal tilt max: {fmt(metrics.get("max_sample_normal_tilt_degrees"))} deg',
             f'Prep / slice / solve: {timings} ms; poses: {candidate.get("evaluations", 0)}',
             f'Slice: {section.get("status", "unavailable")}; classification incomplete: {section.get("classification_incomplete", "unavailable")}',
             f'Plane origin: {prep.get("plane_origin_id", "unavailable")}']
    measurement = digit.get("skin_surface_measurement", {})
    for index, measured_section in enumerate(measurement.get("sections", [])):
        rows = measured_section.get("cross_sections", [])
        fractions = "/".join(str(round(num(r.get("fraction")) * 100)) for r in rows)
        spans = [triple([r.get("rays", {}).get(key, {}).get("distance_m") for r in rows], 1000) for key in ("u_plus", "u_minus")]
        lines.append(f'S{index + 1} at {fractions}%: u+ {spans[0]}; u− {spans[1]} mm')
    normal_max = [max([0] + [num(row.get("rays", {}).get(key, {}).get("distance_m")) * 1000 for sec in measurement.get("sections", []) for row in sec.get("cross_sections", [])]) for key in ("normal_plus", "normal_minus")]
    lines.append(f'Largest normal-ray distances (+ / −), not projected: {triple(normal_max)} mm')
    for i, line in enumerate(lines):
        out += [text(15, TOP + PLOT + 60 + i * 18, line, 11, "#9a3412" if i == 4 and not skin_verified else "#334155")]
    return "".join(out + ["</g>"])


def render(records):
    maximum = max([0.01] + [disk_radius(d) for _, data in records for d in data.get("digits", {}).values()])
    radius_mm = math.ceil(maximum * 1000 / 10) * 10 + 10
    width, height = WIDTH * 2, 185 + HEIGHT * len(records)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" font-family="Arial,sans-serif">', '<rect width="100%" height="100%" fill="white"/>']
    out += [text(15, 31, "Middle and thumb · measured skin asymmetry", 23, "#0f172a"), text(15, 57, "Red: nearby object slice. Dashed circle: search disk. Gray: zero chain / capsule approximation. Orange: u+ rays. Purple: u− rays.", 12), text(15, 79, "Colored paths connect measured zero-pose hits, not fitted skin boundaries. Normal rays are reported numerically, not projected.", 12), text(15, 101, "Identical mm scales. A rejected centered radius does not invalidate planar search; no valid grip or skin-contact certificate is shown.", 12)]
    rejected = any("contributing_weight" in str(d.get("preparation", {}).get("sampling_method", "")) for _, data in records for d in data.get("digits", {}).values())
    if rejected:
        out += [text(15, 128, "REJECTED MEASUREMENT SOURCE INCLUDED: skin-weight membership is not an anatomical boundary. Historical diagnostic only.", 12, "#b91c1c")]
    for row, (path, data) in enumerate(records):
        for column, name in enumerate(("middle", "thumb")):
            out += [panel(data.get("digits", {}).get(name, {}), name, data.get("slot", "?"), row, column, radius_mm)]
        out += [text(15, 165 + row * HEIGHT + HEIGHT - 7, path.name, 10)]
    return "".join(out + ["</svg>"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    records = [(path, json.loads(path.read_text(encoding="utf-8-sig"))) for path in args.inputs]
    for path, data in records:
        if data.get("schema") != "two_digit_contact_proof_v1":
            raise ValueError(f"Unsupported schema: {path}")
    svg = render(records)
    stem = args.output.with_suffix("") if args.output.suffix in (".svg", ".html") else args.output
    stem.parent.mkdir(parents=True, exist_ok=True)
    stem.with_suffix(".svg").write_text(svg, encoding="utf-8")
    sources = "".join(f'<li>{esc(path)}<br>Skin input: {esc(data.get("skin_input", "unavailable"))}</li>' for path, data in records)
    page = f'<!doctype html><html lang="en"><meta charset="utf-8"><title>Two-digit contact proof</title><style>body{{font-family:Arial;margin:16px;background:#e2e8f0}}.figure{{overflow:auto;background:white}}svg{{display:block;max-width:100%;height:auto}}li{{margin:12px 0}}p{{max-width:1100px}}</style><p>Diagnostic proof from captured data. Read candidate status and actual-skin verification separately. Open the accompanying SVG for scalable inspection.</p><div class="figure">{svg}</div><p>Sources:</p><ul>{sources}</ul></html>'
    stem.with_suffix(".html").write_text(page, encoding="utf-8")
    print(stem.with_suffix(".svg"))
    print(stem.with_suffix(".html"))


if __name__ == "__main__":
    main()
