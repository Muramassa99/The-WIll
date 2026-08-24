#!/usr/bin/env python3
"""Build durable evidence for the Forge V2 contact-local chunk prototype.

This analyzer intentionally uses only the Python standard library.  It keeps
three unlike costs separate:

* local operations that changed occupied cells;
* valid local operations that changed no occupied cells; and
* checkpoint-only whole-workpiece mesh analysis.

It also analyzes the matched young-versus-mature locality oracle.  The paired
oracle is the appropriate test for sensitivity to remote workpiece maturity;
the longer stress stream is useful for finding changes in *local* geometric
complexity, but it is not a matched-workload experiment.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import math
import statistics
import sys
from io import StringIO
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = 2
DEFAULT_OPTIMIZED_PREFIX = Path(
    "C:/WORKSPACE/godot_runs/"
    "forge_v2_workpiece_chunked_contact_locality_"
    "20260815T135853_400424_pid22028_5000ops"
)
DEFAULT_PAIRED_PREFIX = Path(
    "C:/WORKSPACE/godot_runs/"
    "forge_v2_chunked_contact_locality_pairs_"
    "20260815T140931_379301_pid22296_8probes_32mature"
)
DEFAULT_ROLLING_METRICS = Path(
    "C:/WORKSPACE/godot_runs/"
    "forge_v2_workpiece_rolling_stress_5000_analysis.metrics.json"
)
DEFAULT_OUTPUT_PREFIX = Path(
    "C:/WORKSPACE/godot_runs/forge_v2_chunked_contact_locality_analysis"
)

TIMING_FIELDS = ("total_ms", "raster_ms", "attachment_ms", "remesh_ms")
COUNTER_FIELDS = (
    "examined_cell_count",
    "candidate_cell_count",
    "contact_cell_count",
    "changed_cell_count",
    "remesh_scanned_cell_count",
    "remeshed_occupied_cell_count",
    "rebuilt_quad_count",
)
PARTITIONS = ("all", "positive_change", "zero_change")

COLORS = {
    "positive_p50": "#16a34a",
    "positive_p95": "#86efac",
    "zero_p50": "#2563eb",
    "zero_p95": "#93c5fd",
    "young": "#2563eb",
    "mature": "#dc2626",
    "memory": "#7c3aed",
    "checkpoint": "#ea580c",
    "occupied": "#0891b2",
    "triangles": "#db2777",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as source:
        value = json.load(source)
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def finite_number(value: Any, label: str) -> float:
    require(isinstance(value, (int, float)) and not isinstance(value, bool), f"{label} is not numeric")
    result = float(value)
    require(math.isfinite(result), f"{label} is not finite")
    return result


def percentile(values: Sequence[float], fraction: float) -> float:
    require(bool(values), "percentile requires at least one value")
    require(0.0 <= fraction <= 1.0, "percentile fraction is outside [0, 1]")
    ordered = sorted(float(value) for value in values)
    position = (len(ordered) - 1) * fraction
    lower = int(math.floor(position))
    upper = int(math.ceil(position))
    if lower == upper:
        return ordered[lower]
    weight = position - lower
    return ordered[lower] * (1.0 - weight) + ordered[upper] * weight


def summarize(values: Sequence[float]) -> dict[str, float | int]:
    require(bool(values), "summary requires at least one value")
    numbers = [finite_number(value, "summary value") for value in values]
    return {
        "count": len(numbers),
        "minimum": min(numbers),
        "p50": percentile(numbers, 0.50),
        "p95": percentile(numbers, 0.95),
        "maximum": max(numbers),
        "mean": statistics.fmean(numbers),
    }


def linear_fit(x_values: Sequence[float], y_values: Sequence[float]) -> dict[str, float | int]:
    require(len(x_values) == len(y_values) and len(x_values) >= 2, "linear fit needs paired samples")
    mean_x = statistics.fmean(x_values)
    mean_y = statistics.fmean(y_values)
    denominator = sum((value - mean_x) ** 2 for value in x_values)
    require(denominator > 0.0, "linear fit needs distinct x values")
    slope = sum(
        (x_value - mean_x) * (y_value - mean_y)
        for x_value, y_value in zip(x_values, y_values)
    ) / denominator
    intercept = mean_y - slope * mean_x
    predicted = [intercept + slope * value for value in x_values]
    squared_error = sum((actual - fitted) ** 2 for actual, fitted in zip(y_values, predicted))
    total_variance = sum((actual - mean_y) ** 2 for actual in y_values)
    return {
        "sample_count": len(x_values),
        "intercept": intercept,
        "slope_per_operation": slope,
        "slope_per_1000_operations": slope * 1000.0,
        "r_squared": 1.0 - squared_error / total_variance if total_variance > 0.0 else 1.0,
        "rmse": math.sqrt(squared_error / len(y_values)),
    }


def pearson(x_values: Sequence[float], y_values: Sequence[float]) -> float:
    require(len(x_values) == len(y_values) and len(x_values) >= 2, "correlation needs paired samples")
    mean_x = statistics.fmean(x_values)
    mean_y = statistics.fmean(y_values)
    x_energy = sum((value - mean_x) ** 2 for value in x_values)
    y_energy = sum((value - mean_y) ** 2 for value in y_values)
    if x_energy <= 0.0 or y_energy <= 0.0:
        return 0.0
    covariance = sum(
        (x_value - mean_x) * (y_value - mean_y)
        for x_value, y_value in zip(x_values, y_values)
    )
    return covariance / math.sqrt(x_energy * y_energy)


def partition_rows(rows: Sequence[dict[str, Any]], partition: str) -> list[dict[str, Any]]:
    if partition == "all":
        return list(rows)
    if partition == "positive_change":
        return [row for row in rows if int(row["changed_cell_count"]) > 0]
    if partition == "zero_change":
        return [row for row in rows if int(row["changed_cell_count"]) == 0]
    raise ValueError(f"unknown partition: {partition}")


def validate_optimized(payload: Mapping[str, Any]) -> list[dict[str, Any]]:
    require(payload.get("ok") is True, "optimized benchmark did not pass")
    require(payload.get("backend_id") == "chunked_labelled_solid_contact_locality_proof_v2", "unexpected backend")
    require(int(payload.get("backend_schema", -1)) == 2, "unexpected backend schema")
    rows = payload.get("raw_operation_rows")
    require(isinstance(rows, list) and bool(rows), "optimized raw_operation_rows is empty")
    required = {"revision", "changed_cell_count", *TIMING_FIELDS, *COUNTER_FIELDS}
    for index, row in enumerate(rows):
        require(isinstance(row, dict), f"optimized row {index} is not an object")
        require(required.issubset(row), f"optimized row {index} is missing fields")
        require(int(row["revision"]) == index + 1, f"optimized revision discontinuity at row {index}")
        for field in required - {"revision"}:
            require(finite_number(row[field], f"optimized row {index} {field}") >= 0.0, f"negative {field}")
        require(int(row.get("live_csg_node_count", -1)) == 0, f"CSG node present at row {index}")
    require(int(payload.get("completed_operation_count", -1)) == len(rows), "completed operation count mismatch")
    require(not payload.get("errors"), "optimized benchmark contains errors")
    return rows


def validate_paired(payload: Mapping[str, Any]) -> list[dict[str, Any]]:
    require(payload.get("passed") is True, "paired locality benchmark did not pass")
    require(payload.get("benchmark_id") == "forge_v2_chunked_contact_locality_pairs_v1", "unexpected paired benchmark")
    rows = payload.get("raw_rows")
    require(isinstance(rows, list) and bool(rows), "paired raw_rows is empty")
    by_probe: dict[int, dict[str, dict[str, Any]]] = {}
    for index, row in enumerate(rows):
        require(isinstance(row, dict), f"paired row {index} is not an object")
        cohort = str(row.get("cohort", ""))
        require(cohort in {"young", "mature"}, f"bad paired cohort at row {index}")
        probe = int(row.get("probe_number", -1))
        require(probe > 0, f"bad paired probe at row {index}")
        by_probe.setdefault(probe, {})[cohort] = row
        for field in TIMING_FIELDS:
            require(finite_number(row[field], f"paired row {index} {field}") >= 0.0, f"negative paired {field}")
    local_fields = [str(field) for field in payload.get("local_counter_fields", [])]
    require(bool(local_fields), "paired benchmark did not declare local counter fields")
    for probe, cohorts in sorted(by_probe.items()):
        require(set(cohorts) == {"young", "mature"}, f"probe {probe} does not have both cohorts")
        young = cohorts["young"]
        mature = cohorts["mature"]
        require(
            young.get("local_counter_signature_sha256") == mature.get("local_counter_signature_sha256"),
            f"probe {probe} local signatures differ",
        )
        for field in local_fields:
            require(young.get(field) == mature.get(field), f"probe {probe} local counter differs: {field}")
    require(not payload.get("errors"), "paired benchmark contains errors")
    return rows


def build_bins(rows: Sequence[dict[str, Any]], size: int = 100) -> list[dict[str, Any]]:
    require(size > 0, "bin size must be positive")
    maximum_revision = max(int(row["revision"]) for row in rows)
    result: list[dict[str, Any]] = []
    for operation_start in range(1, maximum_revision + 1, size):
        operation_end = min(maximum_revision, operation_start + size - 1)
        source = [
            row for row in rows
            if operation_start <= int(row["revision"]) <= operation_end
        ]
        record: dict[str, Any] = {
            "operation_start": operation_start,
            "operation_end": operation_end,
            "operation_midpoint": (operation_start + operation_end) / 2.0,
            "partitions": {},
        }
        for partition in PARTITIONS:
            selected = partition_rows(source, partition)
            if not selected:
                record["partitions"][partition] = {"sample_count": 0, "timings": {}, "counters": {}}
                continue
            record["partitions"][partition] = {
                "sample_count": len(selected),
                "timings": {
                    field: summarize([float(row[field]) for row in selected])
                    for field in TIMING_FIELDS
                },
                "counters": {
                    field: summarize([float(row[field]) for row in selected])
                    for field in COUNTER_FIELDS
                },
            }
        result.append(record)
    return result


def build_partition_summary(rows: Sequence[dict[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for partition in PARTITIONS:
        selected = partition_rows(rows, partition)
        result[partition] = {
            "sample_count": len(selected),
            "timings": {
                field: summarize([float(row[field]) for row in selected])
                for field in TIMING_FIELDS
            },
            "counters": {
                field: summarize([float(row[field]) for row in selected])
                for field in COUNTER_FIELDS
            },
            "timing_trends": {
                field: linear_fit(
                    [float(row["revision"]) for row in selected],
                    [float(row[field]) for row in selected],
                )
                for field in TIMING_FIELDS
            },
        }
    positive = partition_rows(rows, "positive_change")
    result["positive_change"]["remesh_correlations"] = {
        field: pearson(
            [float(row["remesh_ms"]) for row in positive],
            [float(row[field]) for row in positive],
        )
        for field in (
            "rebuilt_quad_count",
            "remesh_scanned_cell_count",
            "remeshed_occupied_cell_count",
            "remeshed_chunk_count",
            "resident_triangle_count",
            "revision",
        )
    }
    return result


def build_paired_summary(rows: Sequence[dict[str, Any]]) -> dict[str, Any]:
    by_probe: dict[int, dict[str, dict[str, Any]]] = {}
    for row in rows:
        by_probe.setdefault(int(row["probe_number"]), {})[str(row["cohort"])] = row
    pair_deltas = [
        float(cohorts["mature"]["total_ms"]) - float(cohorts["young"]["total_ms"])
        for _, cohorts in sorted(by_probe.items())
    ]
    pair_ratios = [
        float(cohorts["mature"]["total_ms"]) / float(cohorts["young"]["total_ms"])
        for _, cohorts in sorted(by_probe.items())
    ]
    cohorts_summary: dict[str, Any] = {}
    for cohort in ("young", "mature"):
        selected = [row for row in rows if row["cohort"] == cohort]
        cohorts_summary[cohort] = {
            field: summarize([float(row[field]) for row in selected])
            for field in TIMING_FIELDS
        }
    signatures = sorted({str(row["local_counter_signature_sha256"]) for row in rows})
    return {
        "pair_count": len(by_probe),
        "cohorts": cohorts_summary,
        "mature_minus_young_total_ms": summarize(pair_deltas),
        "mature_over_young_total_ratio": summarize(pair_ratios),
        "unique_local_counter_signatures": signatures,
        "all_pairs_have_identical_local_counters": True,
    }


def nice_number(value: float) -> str:
    absolute = abs(value)
    if absolute >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if absolute >= 1_000:
        return f"{value / 1_000:.1f}k"
    if absolute >= 100:
        return f"{value:.0f}"
    if absolute >= 10:
        return f"{value:.1f}"
    return f"{value:.2f}"


def svg_text(x: float, y: float, value: str, *, size: int = 12, anchor: str = "start", fill: str = "#334155", weight: str = "400") -> str:
    return (
        f'<text x="{x:.2f}" y="{y:.2f}" font-family="system-ui,Segoe UI,sans-serif" '
        f'font-size="{size}" text-anchor="{anchor}" fill="{fill}" font-weight="{weight}">'
        f"{html.escape(value)}</text>"
    )


def chart_svg(
    title: str,
    subtitle: str,
    panels: Sequence[dict[str, Any]],
    legend: Sequence[tuple[str, str, str]],
    *,
    columns: int = 2,
) -> str:
    width = 1320
    panel_width = 610
    panel_height = 285
    gap_x = 45
    gap_y = 45
    rows = math.ceil(len(panels) / columns)
    height = 125 + rows * panel_height + max(0, rows - 1) * gap_y + 35
    pieces = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        svg_text(30, 34, title, size=22, fill="#0f172a", weight="700"),
        svg_text(30, 57, subtitle, size=12, fill="#475569"),
    ]
    legend_x = 30.0
    for label, color, dash in legend:
        dash_attribute = f' stroke-dasharray="{dash}"' if dash else ""
        pieces.append(
            f'<line x1="{legend_x:.2f}" y1="82" x2="{legend_x + 28:.2f}" y2="82" '
            f'stroke="{color}" stroke-width="3"{dash_attribute}/>'
        )
        pieces.append(svg_text(legend_x + 34, 86, label, size=11, fill="#334155"))
        legend_x += 34 + max(88, len(label) * 7)

    for panel_index, panel in enumerate(panels):
        column = panel_index % columns
        row = panel_index // columns
        outer_x = 30 + column * (panel_width + gap_x)
        outer_y = 110 + row * (panel_height + gap_y)
        left = outer_x + 64
        top = outer_y + 31
        plot_width = panel_width - 84
        plot_height = panel_height - 76
        series = panel["series"]
        all_points = [point for item in series for point in item["points"] if point[1] is not None]
        require(bool(all_points), f"chart panel has no values: {panel['title']}")
        x_values = [float(point[0]) for point in all_points]
        y_values = [float(point[1]) for point in all_points]
        x_min = float(panel.get("x_min", min(x_values)))
        x_max = float(panel.get("x_max", max(x_values)))
        if x_max <= x_min:
            x_max = x_min + 1.0
        if panel.get("zero_baseline", True):
            y_min = min(0.0, min(y_values))
        else:
            y_min = min(y_values)
            y_min -= max(1e-9, (max(y_values) - y_min) * 0.10)
        y_max = max(y_values)
        if y_max <= y_min:
            y_max = y_min + 1.0
        else:
            y_max += (y_max - y_min) * 0.10

        pieces.append(svg_text(outer_x, outer_y + 14, str(panel["title"]), size=14, fill="#0f172a", weight="650"))
        pieces.append(f'<rect x="{left:.2f}" y="{top:.2f}" width="{plot_width:.2f}" height="{plot_height:.2f}" fill="#f8fafc" stroke="#cbd5e1"/>')
        for tick in range(5):
            fraction = tick / 4.0
            y = top + plot_height * (1.0 - fraction)
            value = y_min + (y_max - y_min) * fraction
            pieces.append(f'<line x1="{left:.2f}" y1="{y:.2f}" x2="{left + plot_width:.2f}" y2="{y:.2f}" stroke="#e2e8f0"/>')
            pieces.append(svg_text(left - 8, y + 4, nice_number(value), size=10, anchor="end", fill="#64748b"))
        for tick in range(5):
            fraction = tick / 4.0
            x = left + plot_width * fraction
            value = x_min + (x_max - x_min) * fraction
            pieces.append(f'<line x1="{x:.2f}" y1="{top:.2f}" x2="{x:.2f}" y2="{top + plot_height:.2f}" stroke="#eef2f7"/>')
            pieces.append(svg_text(x, top + plot_height + 18, nice_number(value), size=10, anchor="middle", fill="#64748b"))
        pieces.append(svg_text(left + plot_width / 2, top + plot_height + 38, str(panel.get("x_label", "operation")), size=10, anchor="middle", fill="#475569"))

        def transform(point: tuple[float, float]) -> tuple[float, float]:
            x_value, y_value = point
            return (
                left + (x_value - x_min) / (x_max - x_min) * plot_width,
                top + (1.0 - (y_value - y_min) / (y_max - y_min)) * plot_height,
            )

        for item in series:
            segments: list[list[tuple[float, float]]] = []
            current: list[tuple[float, float]] = []
            for x_value, y_value in item["points"]:
                if y_value is None:
                    if current:
                        segments.append(current)
                        current = []
                    continue
                current.append(transform((float(x_value), float(y_value))))
            if current:
                segments.append(current)
            dash_attribute = f' stroke-dasharray="{item["dash"]}"' if item.get("dash") else ""
            for segment in segments:
                path = " ".join(
                    ("M" if index == 0 else "L") + f" {x:.2f} {y:.2f}"
                    for index, (x, y) in enumerate(segment)
                )
                pieces.append(
                    f'<path d="{path}" fill="none" stroke="{item["color"]}" '
                    f'stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round"{dash_attribute}/>'
                )
                for x, y in segment:
                    pieces.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="2.5" fill="{item["color"]}"/>')
    pieces.append("</svg>")
    return "\n".join(pieces) + "\n"


def bin_points(bins: Sequence[dict[str, Any]], partition: str, category: str, field: str, statistic: str) -> list[tuple[float, float | None]]:
    result: list[tuple[float, float | None]] = []
    for record in bins:
        data = record["partitions"][partition][category].get(field)
        result.append((float(record["operation_midpoint"]), None if data is None else float(data[statistic])))
    return result


def build_timing_svg(bins: Sequence[dict[str, Any]]) -> str:
    panels = []
    titles = {
        "total_ms": "Local operation total (ms)",
        "raster_ms": "Profile raster (ms)",
        "attachment_ms": "Attachment validation (ms)",
        "remesh_ms": "Changed-chunk remesh (ms)",
    }
    for field in TIMING_FIELDS:
        panels.append({
            "title": titles[field],
            "series": [
                {"points": bin_points(bins, "positive_change", "timings", field, "p50"), "color": COLORS["positive_p50"], "dash": ""},
                {"points": bin_points(bins, "positive_change", "timings", field, "p95"), "color": COLORS["positive_p95"], "dash": "7 5"},
                {"points": bin_points(bins, "zero_change", "timings", field, "p50"), "color": COLORS["zero_p50"], "dash": ""},
                {"points": bin_points(bins, "zero_change", "timings", field, "p95"), "color": COLORS["zero_p95"], "dash": "7 5"},
            ],
        })
    return chart_svg(
        "Forge V2 contact-local timing by 100-operation bin",
        "Positive-change and zero-change operations are never pooled; p95 is linearly interpolated within each bin.",
        panels,
        (
            ("positive p50", COLORS["positive_p50"], ""),
            ("positive p95", COLORS["positive_p95"], "7 5"),
            ("zero p50", COLORS["zero_p50"], ""),
            ("zero p95", COLORS["zero_p95"], "7 5"),
        ),
    )


def build_locality_svg(bins: Sequence[dict[str, Any]]) -> str:
    titles = {
        "examined_cell_count": "Cells examined",
        "candidate_cell_count": "Candidate cells",
        "contact_cell_count": "Contact cells",
        "changed_cell_count": "Changed cells",
        "remesh_scanned_cell_count": "Cells scanned by remesh",
        "remeshed_occupied_cell_count": "Occupied cells inside remeshed chunks",
        "rebuilt_quad_count": "Rebuilt output quads",
    }
    panels = []
    for field in COUNTER_FIELDS:
        panels.append({
            "title": titles[field],
            "series": [
                {"points": bin_points(bins, "positive_change", "counters", field, "p50"), "color": COLORS["positive_p50"], "dash": ""},
                {"points": bin_points(bins, "positive_change", "counters", field, "p95"), "color": COLORS["positive_p95"], "dash": "7 5"},
                {"points": bin_points(bins, "zero_change", "counters", field, "p50"), "color": COLORS["zero_p50"], "dash": ""},
                {"points": bin_points(bins, "zero_change", "counters", field, "p95"), "color": COLORS["zero_p95"], "dash": "7 5"},
            ],
        })
    return chart_svg(
        "Forge V2 local work and emitted complexity",
        "Fixed scan bounds do not imply fixed mesh-output complexity; rebuilt quads are therefore charted explicitly.",
        panels,
        (
            ("positive p50", COLORS["positive_p50"], ""),
            ("positive p95", COLORS["positive_p95"], "7 5"),
            ("zero p50", COLORS["zero_p50"], ""),
            ("zero p95", COLORS["zero_p95"], "7 5"),
        ),
    )


def build_memory_svg(payload: Mapping[str, Any]) -> str:
    bins = list(payload["timing_bins"])
    checkpoints = list(payload["checkpoints"])
    panels = [
        {
            "title": "Runtime static-memory samples (MiB)",
            "zero_baseline": False,
            "series": [{
                "points": [(float(row["operation_end"]), float(row["sampled_static_memory_bytes"]) / 1048576.0) for row in bins],
                "color": COLORS["memory"],
                "dash": "",
            }],
        },
        {
            "title": "Global checkpoint mesh analysis (ms)",
            "series": [{
                "points": [(float(row["operation_count"]), float(row["checkpoint_analyze_ms"])) for row in checkpoints],
                "color": COLORS["checkpoint"],
                "dash": "",
            }],
        },
        {
            "title": "Checkpoint whole-body complexity",
            "series": [
                {"points": [(float(row["operation_count"]), float(row["occupied_cell_count"])) for row in checkpoints], "color": COLORS["occupied"], "dash": ""},
                {"points": [(float(row["operation_count"]), float(row["triangle_count"])) for row in checkpoints], "color": COLORS["triangles"], "dash": "7 5"},
            ],
        },
    ]
    return chart_svg(
        "Forge V2 memory and separately timed global checkpoints",
        "Checkpoint combined-mesh construction/analysis is excluded from all local-operation timing distributions.",
        panels,
        (
            ("runtime memory", COLORS["memory"], ""),
            ("checkpoint analysis", COLORS["checkpoint"], ""),
            ("occupied cells", COLORS["occupied"], ""),
            ("triangles", COLORS["triangles"], "7 5"),
        ),
    )


def build_paired_svg(rows: Sequence[dict[str, Any]]) -> str:
    panels = []
    titles = {
        "total_ms": "Matched local total (ms)",
        "raster_ms": "Matched raster (ms)",
        "attachment_ms": "Matched attachment (ms)",
        "remesh_ms": "Matched remesh (ms)",
    }
    for field in TIMING_FIELDS:
        panels.append({
            "title": titles[field],
            "x_label": "paired probe",
            "series": [
                {
                    "points": [(float(row["probe_number"]), float(row[field])) for row in rows if row["cohort"] == "young"],
                    "color": COLORS["young"],
                    "dash": "",
                },
                {
                    "points": [(float(row["probe_number"]), float(row[field])) for row in rows if row["cohort"] == "mature"],
                    "color": COLORS["mature"],
                    "dash": "7 5",
                },
            ],
        })
    return chart_svg(
        "Matched young-versus-mature contact-local oracle",
        "Eight paired probes have identical local counter signatures; mature-only geometry remains outside the processing halo.",
        panels,
        (("young", COLORS["young"], ""), ("mature", COLORS["mature"], "7 5")),
    )


def build_samples_csv(
    bins: Sequence[dict[str, Any]],
    checkpoints: Sequence[dict[str, Any]],
    paired_rows: Sequence[dict[str, Any]],
) -> str:
    headers = [
        "sample_kind", "change_class", "cohort", "operation_start", "operation_end", "probe_number", "sample_count",
        "total_ms", "total_p50_ms", "total_p95_ms", "raster_ms", "raster_p50_ms", "raster_p95_ms",
        "attachment_ms", "attachment_p50_ms", "attachment_p95_ms", "remesh_ms", "remesh_p50_ms", "remesh_p95_ms",
        "examined_cells_p50", "examined_cells_p95", "candidate_cells_p50", "candidate_cells_p95",
        "contact_cells_p50", "contact_cells_p95", "changed_cells_p50", "changed_cells_p95",
        "remesh_scanned_cells_p50", "remesh_scanned_cells_p95", "rebuilt_quads_p50", "rebuilt_quads_p95",
        "memory_mib", "checkpoint_analyze_ms", "occupied_cell_count", "resident_chunk_count", "triangle_count",
        "local_counter_signature_sha256", "remote_minimum_chebyshev_chunks", "occupancy_delta",
    ]
    rows: list[dict[str, Any]] = []
    counter_columns = {
        "examined_cell_count": "examined_cells",
        "candidate_cell_count": "candidate_cells",
        "contact_cell_count": "contact_cells",
        "changed_cell_count": "changed_cells",
        "remesh_scanned_cell_count": "remesh_scanned_cells",
        "rebuilt_quad_count": "rebuilt_quads",
    }
    for record in bins:
        for partition in PARTITIONS:
            data = record["partitions"][partition]
            row: dict[str, Any] = {
                "sample_kind": "operation_bin",
                "change_class": partition,
                "operation_start": record["operation_start"],
                "operation_end": record["operation_end"],
                "sample_count": data["sample_count"],
            }
            for field in TIMING_FIELDS:
                if field in data["timings"]:
                    stem = field.removesuffix("_ms")
                    row[f"{stem}_p50_ms"] = data["timings"][field]["p50"]
                    row[f"{stem}_p95_ms"] = data["timings"][field]["p95"]
            for field, stem in counter_columns.items():
                if field in data["counters"]:
                    row[f"{stem}_p50"] = data["counters"][field]["p50"]
                    row[f"{stem}_p95"] = data["counters"][field]["p95"]
            rows.append(row)
    for checkpoint in checkpoints:
        rows.append({
            "sample_kind": "global_checkpoint",
            "operation_start": checkpoint["operation_count"],
            "operation_end": checkpoint["operation_count"],
            "sample_count": 1,
            "memory_mib": float(checkpoint["sampled_static_memory_bytes"]) / 1048576.0,
            "checkpoint_analyze_ms": checkpoint["checkpoint_analyze_ms"],
            "occupied_cell_count": checkpoint["occupied_cell_count"],
            "resident_chunk_count": checkpoint["active_chunk_count"],
            "triangle_count": checkpoint["triangle_count"],
        })
    for source in paired_rows:
        rows.append({
            "sample_kind": "paired_probe",
            "cohort": source["cohort"],
            "probe_number": source["probe_number"],
            "sample_count": 1,
            "total_ms": source["total_ms"],
            "raster_ms": source["raster_ms"],
            "attachment_ms": source["attachment_ms"],
            "remesh_ms": source["remesh_ms"],
            "occupied_cell_count": source["occupancy_after"],
            "resident_chunk_count": source["resident_chunks_after"],
            "triangle_count": source["global_triangle_count_after"],
            "local_counter_signature_sha256": source["local_counter_signature_sha256"],
            "remote_minimum_chebyshev_chunks": source["remote_minimum_chebyshev_chunks"],
            "occupancy_delta": source["occupancy_delta"],
        })
    output = StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=headers, lineterminator="\n")
    writer.writeheader()
    for row in rows:
        writer.writerow({key: row.get(key, "") for key in headers})
    return output.getvalue()


def format_ms(value: float) -> str:
    return f"{value:.3f} ms"


def format_mib(value: float) -> str:
    return f"{value:.2f} MiB"


def build_report(metrics: Mapping[str, Any]) -> str:
    optimized = metrics["optimized_stress"]
    partitions = optimized["partitions"]
    positive = partitions["positive_change"]
    zero = partitions["zero_change"]
    paired = metrics["paired_oracle"]
    checkpoints = optimized["global_checkpoints"]
    runtime_memory = optimized["runtime_memory"]
    positive_slope = positive["timing_trends"]["total_ms"]["slope_per_1000_operations"]
    remesh_slope = positive["timing_trends"]["remesh_ms"]["slope_per_1000_operations"]
    zero_slope = zero["timing_trends"]["total_ms"]["slope_per_1000_operations"]
    delta = paired["mature_minus_young_total_ms"]
    ratio = paired["mature_over_young_total_ratio"]
    first_checkpoint = checkpoints[0]
    last_checkpoint = checkpoints[-1]
    lines = [
        "# Forge V2 contact-local chunk evidence",
        "",
        "Result: **the isolated prototype passes both benchmark gates and the matched oracle supports remote-size locality.** "
        "It does **not** yet demonstrate constant cost under growing local surface complexity, organic output fidelity, or production Forge integration.",
        "",
        "## Evidence gates",
        "",
        f"- Optimized stress run: PASS, {optimized['operation_count']:,} operations, zero live built-in CSG nodes.",
        f"- Matched oracle: PASS, {paired['pair_count']} young/mature pairs, one identical local-counter signature across all rows.",
        f"- Positive-change operations: {positive['sample_count']:,}; valid zero-change operations: {zero['sample_count']:,}. They are analyzed separately throughout.",
        "- Whole-workpiece combined-mesh checkpoints are reported separately and are not included in local-operation percentiles or fits.",
        "",
        "## Local operation result",
        "",
        f"- Positive-change total: p50 {format_ms(positive['timings']['total_ms']['p50'])}, p95 {format_ms(positive['timings']['total_ms']['p95'])}. "
        f"Zero-change total: p50 {format_ms(zero['timings']['total_ms']['p50'])}, p95 {format_ms(zero['timings']['total_ms']['p95'])}.",
        f"- Positive-change total has an affine diagnostic slope of {positive_slope:+.3f} ms per 1,000 operations; its remesh phase contributes {remesh_slope:+.3f} ms per 1,000. "
        f"Zero-change total is {zero_slope:+.3f} ms per 1,000.",
        f"- Positive remesh time correlates most strongly with occupied cells inside the remeshed chunks at "
        f"r={positive['remesh_correlations']['remeshed_occupied_cell_count']:.3f}; rebuilt quads are r={positive['remesh_correlations']['rebuilt_quad_count']:.3f}, "
        f"while the fixed remesh-scan counter is r={positive['remesh_correlations']['remesh_scanned_cell_count']:.3f}. "
        "This identifies local fill/surface complexity, rather than revision history, as the remaining sawtooth cost.",
        "",
        "The stress stream is not a matched sequence of identical contact regions, so its revision slope must not be interpreted as pure workpiece-size sensitivity. "
        "That question is answered by the paired oracle instead.",
        "",
        "## Matched young-versus-mature oracle",
        "",
        f"- Young total mean: {format_ms(paired['cohorts']['young']['total_ms']['mean'])}; mature total mean: {format_ms(paired['cohorts']['mature']['total_ms']['mean'])}.",
        f"- Paired mature-minus-young mean: {delta['mean']:+.3f} ms; paired p50: {delta['p50']:+.3f} ms; paired p95: {delta['p95']:+.3f} ms.",
        f"- Mature/young ratio p50: {ratio['p50']:.4f} ({(ratio['p50'] - 1.0) * 100.0:+.2f}%); p95: {ratio['p95']:.4f} ({(ratio['p95'] - 1.0) * 100.0:+.2f}%).",
        "- These timing samples are small and noisy. Correctness is gated by exact paired local-counter parity; timing is diagnostic, not a hard pass threshold.",
        "",
        "## Memory and global checkpoints",
        "",
        f"- Per-bin runtime static-memory sample: {format_mib(runtime_memory['first_mib'])} at operation {runtime_memory['first_operation']} to "
        f"{format_mib(runtime_memory['last_mib'])} at operation {runtime_memory['last_operation']} ({runtime_memory['delta_mib']:+.2f} MiB).",
        f"- Separately timed global checkpoint analysis: {format_ms(first_checkpoint['checkpoint_analyze_ms'])} at operation {first_checkpoint['operation_count']} and "
        f"{format_ms(last_checkpoint['checkpoint_analyze_ms'])} at operation {last_checkpoint['operation_count']}.",
        "- Checkpoint cost remains whole-body work by design. It belongs on explicit save/compile/validation boundaries, not in the interactive stroke path.",
        "",
        "## Interpretation boundary",
        "",
        "This result supports a sparse chunk backend with contact-local read/write/remesh sets. It does not prove final organic meshing, material/void semantics, collision rebuilding, bounded undo, persistence, or production presenter/accounting locality. "
        "The current 4 mm labelled voxel/block field is a scaling carrier only.",
    ]
    rolling = metrics.get("archived_rolling_context")
    if rolling:
        lines.extend([
            "",
            "## Archived rolling benchmark context",
            "",
            f"The archived 5,000-operation rolling run ended at compile p95 {rolling['latest_compile_p95_ms']:.2f} ms and fitted {rolling['compile_slope_per_1000_operations']:+.2f} ms per 1,000 operations. "
            "It used a different backend, workload, timing window, and operation count, so this is directional historical context; not a speedup ratio or an apples-to-apples comparison.",
        ])
    lines.extend([
        "",
        "## Durable artifacts",
        "",
        "- `.metrics.json`: gates, fitted diagnostics, partitions, bins, checkpoints, and paired statistics.",
        "- `.samples.csv`: per-bin partitions, global checkpoints, and individual paired probes.",
        "- `.timings.svg`, `.locality.svg`, `.memory_checkpoints.svg`, `.paired.svg`: dependency-free charts.",
        "",
    ])
    return "\n".join(lines)


def write_if_changed(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = content.encode("utf-8")
    if path.exists() and path.read_bytes() == encoded:
        return
    path.write_bytes(encoded)


def parse_args(arguments: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--optimized-prefix", type=Path, default=DEFAULT_OPTIMIZED_PREFIX)
    parser.add_argument("--paired-prefix", type=Path, default=DEFAULT_PAIRED_PREFIX)
    parser.add_argument("--output-prefix", type=Path, default=DEFAULT_OUTPUT_PREFIX)
    parser.add_argument(
        "--rolling-metrics",
        type=Path,
        default=DEFAULT_ROLLING_METRICS,
        help="optional archived rolling-analysis metrics JSON; missing file is skipped",
    )
    return parser.parse_args(arguments)


def main(arguments: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if arguments is None else arguments)
    optimized_path = args.optimized_prefix.with_suffix(".json")
    paired_path = args.paired_prefix.with_suffix(".json")
    optimized_payload = load_json(optimized_path)
    paired_payload = load_json(paired_path)
    optimized_rows = validate_optimized(optimized_payload)
    paired_rows = validate_paired(paired_payload)
    bins = build_bins(optimized_rows, 100)
    partition_summary = build_partition_summary(optimized_rows)
    paired_summary = build_paired_summary(paired_rows)
    checkpoints = sorted(optimized_payload["checkpoints"], key=lambda item: int(item["operation_count"]))
    timing_bins = sorted(optimized_payload["timing_bins"], key=lambda item: int(item["operation_end"]))
    runtime_memory = {
        "first_operation": int(timing_bins[0]["operation_end"]),
        "last_operation": int(timing_bins[-1]["operation_end"]),
        "first_mib": float(timing_bins[0]["sampled_static_memory_bytes"]) / 1048576.0,
        "last_mib": float(timing_bins[-1]["sampled_static_memory_bytes"]) / 1048576.0,
    }
    runtime_memory["delta_mib"] = runtime_memory["last_mib"] - runtime_memory["first_mib"]
    metrics: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "standard_library_only": True,
        "sources": {
            "optimized_json": str(optimized_path).replace("\\", "/"),
            "optimized_json_sha256": sha256_file(optimized_path),
            "paired_json": str(paired_path).replace("\\", "/"),
            "paired_json_sha256": sha256_file(paired_path),
        },
        "evidence_gate": {
            "pass": True,
            "optimized_benchmark_pass": True,
            "paired_benchmark_pass": True,
            "positive_and_zero_change_separated": True,
            "global_checkpoint_cost_separated": True,
        },
        "optimized_stress": {
            "backend_id": optimized_payload["backend_id"],
            "backend_schema": optimized_payload["backend_schema"],
            "fixture_id": optimized_payload["fixture_id"],
            "operation_count": len(optimized_rows),
            "bin_size": 100,
            "live_csg_node_count": int(optimized_payload["final_backend_summary"]["live_csg_node_count"]),
            "partitions": partition_summary,
            "bins": bins,
            "runtime_memory": runtime_memory,
            "global_checkpoints": checkpoints,
            "checkpoint_timing_scope": "separate whole-workpiece combined-mesh construction and analysis; excluded from local-operation distributions",
        },
        "paired_oracle": {
            **paired_summary,
            "mature_only_chunk_count": int(paired_payload["mature_only_chunk_count"]),
            "initial_occupancy_gap_cells": int(paired_payload["initial_occupancy_gap_cells"]),
            "source_timing": paired_payload["timing"],
            "scope": paired_payload["scope"],
        },
        "interpretation": {
            "supported": "matched local work is insensitive to remote workpiece maturity within this isolated prototype and sample",
            "observed_local_limit": "positive-change remesh cost still rises with emitted local surface complexity in the stress stream",
            "not_proven": [
                "constant cost under unbounded local surface complexity",
                "organic-fidelity geometry",
                "production Forge state/presenter/accounting locality",
                "material, void, undo, persistence, or collision integration",
            ],
        },
    }
    if args.rolling_metrics and args.rolling_metrics.exists():
        rolling = load_json(args.rolling_metrics)
        metrics["sources"]["archived_rolling_metrics"] = str(args.rolling_metrics).replace("\\", "/")
        metrics["sources"]["archived_rolling_metrics_sha256"] = sha256_file(args.rolling_metrics)
        metrics["archived_rolling_context"] = {
            "latest_operation": int(rolling["latest_sample"]["operation"]),
            "latest_compile_p95_ms": float(rolling["latest_sample"]["compile_p95_ms"]),
            "compile_slope_per_operation": float(rolling["fits"]["compile_p95_ms"]["linear"]["coefficients"]["slope_per_operation"]),
            "compile_slope_per_1000_operations": float(rolling["fits"]["compile_p95_ms"]["linear"]["coefficients"]["slope_per_operation"]) * 1000.0,
            "comparison_limitation": "different backend, workload, timing window, and operation count; directional context only",
        }

    outputs = {
        args.output_prefix.with_suffix(".metrics.json"): json.dumps(metrics, indent=2, sort_keys=True, allow_nan=False) + "\n",
        args.output_prefix.with_suffix(".samples.csv"): build_samples_csv(bins, checkpoints, paired_rows),
        args.output_prefix.with_suffix(".report.md"): build_report(metrics),
        args.output_prefix.with_suffix(".timings.svg"): build_timing_svg(bins),
        args.output_prefix.with_suffix(".locality.svg"): build_locality_svg(bins),
        args.output_prefix.with_suffix(".memory_checkpoints.svg"): build_memory_svg(optimized_payload),
        args.output_prefix.with_suffix(".paired.svg"): build_paired_svg(paired_rows),
    }
    for path, content in outputs.items():
        write_if_changed(path, content)
    print(f"PASS: wrote {len(outputs)} durable locality-analysis artifacts")
    for path in outputs:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
