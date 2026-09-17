"""Render actual solver geometry from its JSON report, using only stdlib.

Vector2 coordinates are physical meters in each report's registered plane.
This presentation never modifies solver data or closes raw slice segments.
"""
import argparse
import html
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("report", type=Path)
args = parser.parse_args()
report = json.loads(args.report.read_text(encoding="utf-8"))
rows = [row for row in report["digits"] if row.get("valid")]
width, height, gap = 340, 365, 18
columns = max((len(row["poses"]) for row in rows), default=1)
parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{columns*width}" height="{len(rows)*height+65}" viewBox="0 0 {columns*width} {len(rows)*height+65}">',
         '<rect width="100%" height="100%" fill="#101820"/>',
         '<style>text{font-family:Arial,sans-serif;fill:#e6edf4;font-size:12px}.title{font-size:16px;font-weight:bold}</style>',
         '<text x="16" y="23" class="title">Prepared skin contact — measured slices, not a certified 3D grip</text>',
         '<text x="16" y="45">Orange: weapon. Cyan: moving skin. Gray: retained static skin. White: joints. Axes in mm.</text>']
for row_index, row in enumerate(rows):
    for column, pose in enumerate(row["poses"]):
        x0, y0 = column * width, row_index * height + 65
        radius = row["query_radius_m"] * 1000
        scale = (width - 2 * gap) / (2 * radius)
        cx, cy = x0 + width / 2, y0 + height / 2 + 12
        def point(p):
            return cx + p[0] * 1000 * scale, cy - p[1] * 1000 * scale
        def line(a, b, color, thickness=1):
            ax, ay = point(a)
            bx, by = point(b)
            return f'<path d="M{ax:.3f},{ay:.3f}L{bx:.3f},{by:.3f}" fill="none" stroke="{color}" stroke-width="{thickness}"/>'
        clip = f"cell_{row_index}_{column}"
        parts += [f'<defs><clipPath id="{clip}"><circle cx="{cx}" cy="{cy}" r="{radius*scale}"/></clipPath></defs>',
                  f'<text x="{x0+12}" y="{y0+19}">{html.escape(row["slot"]+" / "+row["digit"]+" / "+pose["label"])}</text>',
                  f'<g clip-path="url(#{clip})">']
        for tick in range(-100, 101, 20):
            parts += [line([tick/1000, -radius/1000], [tick/1000, radius/1000], "#24323e"),
                      line([-radius/1000, tick/1000], [radius/1000, tick/1000], "#24323e")]
        for a, b in row["target_segments"]:
            parts.append(line(a, b, "#ffb454", 1.8))
        for edge in pose.get("skin_segments", []):
            parts.append(line(edge["a"], edge["b"], "#52d4e9" if edge["dynamic"] else "#88949f", 1.5))
        joints = pose.get("joint_points_m", [])
        for a, b in zip(joints, joints[1:]):
            parts.append(line(a, b, "#f5f7ff", 1.5))
        for p in joints:
            x, y = point(p)
            parts.append(f'<circle cx="{x}" cy="{y}" r="3" fill="#f5f7ff"/>')
        parts += ['</g>', f'<circle cx="{cx}" cy="{cy}" r="{radius*scale}" fill="none" stroke="#46515b"/>']
        for tick in [-80, -40, 0, 40, 80]:
            x, y = point([tick/1000, 0])
            parts.append(f'<text x="{x+2}" y="{y+13}">{tick}</text>')
        contact = pose.get("contact", {})
        moving = contact.get("dynamic", {})
        status = f'Crossings: {moving.get("proper_crossings", "?")} | pose {pose.get("total_pose_ms",0):.2f} ms'
        parts.append(f'<text x="{x0+12}" y="{y0+height-10}">{html.escape(status)}</text>')
parts.append('</svg>')
svg = args.report.with_suffix('.svg')
svg.write_text(''.join(parts), encoding='utf-8')
page = args.report.with_suffix('.html')
page.write_text('<!doctype html><meta charset="utf-8"><title>Prepared skin contact</title>'
                '<style>body{margin:0;background:#101820;color:white;font-family:Arial}p{margin:16px}img{max-width:none}</style>'
                '<p>Each panel retains the measured reach window. Scroll to compare. Open SVG to zoom without losing detail.</p>'
                f'<p><a style="color:#52d4e9" href="{html.escape(svg.name)}">Open SVG</a></p>'
                f'<img src="{html.escape(svg.name)}">', encoding='utf-8')
print(page)
print(svg)
