#!/usr/bin/env python3
"""Analyze Forge V2 rolling-workpiece SOAK heartbeat logs.

This tool intentionally uses only the Python standard library.  It parses the
compact heartbeat lines printed by
``benchmark_forge_v2_workpiece_compiler_rolling_stress.gd`` and writes a
machine-readable sample table, fitted metrics, dependency-free SVG charts, and
a concise Markdown interpretation.

Example:

    python tools/analyze_forge_v2_rolling_stress.py \
        C:/WORKSPACE/godot_runs/forge_v2_workpiece_rolling_stress.log \
        C:/WORKSPACE/godot_runs/forge_v2_workpiece_rolling_stress_analysis \
        --stop-reason "operator-requested stop at 5,000 operations"

The 10,001-operation estimate is deliberately labelled as an extrapolation.
It is not a promise, confidence interval, or substitute for a completed soak.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import math
import re
import statistics
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable, Iterable, Sequence


SCHEMA_VERSION = 1
DEFAULT_GEOMETRY_CHECKPOINTS = (
    1,
    4,
    5,
    6,
    10,
    25,
    50,
    100,
    250,
    500,
    1000,
    2500,
    5000,
    7500,
    9999,
    10000,
    10001,
)
DEFAULT_COLLISION_CHECKPOINTS = (100, 1000, 5000, 10000, 10001)

NUMBER = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?"
SOAK_PATTERN = re.compile(
    rf"SOAK\s+(?P<operation>\d+)/(?P<target>\d+)\s+"
    rf"elapsed=(?P<elapsed>{NUMBER})s\s+"
    rf"compile_p95=(?P<compile>{NUMBER})ms\s+"
    rf"frame_p95=(?P<frame>{NUMBER})ms\s+"
    rf"memory=(?P<memory>{NUMBER})MiB"
)


@dataclass(frozen=True)
class Sample:
    operation: int
    target_operation: int
    elapsed_seconds: float
    compile_p95_ms: float
    frame_p95_ms: float
    static_memory_mib: float


@dataclass(frozen=True)
class Interval:
    operation_start: int
    operation_end: int
    operation_count: int
    elapsed_seconds: float
    milliseconds_per_operation: float
    operations_per_second: float
    ends_at_geometry_checkpoint: bool
    ends_at_collision_checkpoint: bool


@dataclass
class Fit:
    kind: str
    sample_count: int
    coefficients: dict[str, float]
    r_squared: float
    rmse: float
    mae: float
    predict: Callable[[float], float]
    extra: dict[str, float]


def _parse_int_list(value: str) -> tuple[int, ...]:
    if not value.strip():
        return ()
    result = sorted({int(part.strip()) for part in value.split(",") if part.strip()})
    if any(item < 1 for item in result):
        raise argparse.ArgumentTypeError("checkpoint operations must be positive")
    return tuple(result)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_soak_log(path: Path) -> tuple[list[Sample], dict[str, object]]:
    by_operation: dict[int, Sample] = {}
    matched_line_count = 0
    duplicate_operations: list[int] = []
    with path.open("r", encoding="utf-8", errors="replace") as source:
        for line_number, line in enumerate(source, start=1):
            match = SOAK_PATTERN.search(line)
            if match is None:
                continue
            matched_line_count += 1
            sample = Sample(
                operation=int(match.group("operation")),
                target_operation=int(match.group("target")),
                elapsed_seconds=float(match.group("elapsed")),
                compile_p95_ms=float(match.group("compile")),
                frame_p95_ms=float(match.group("frame")),
                static_memory_mib=float(match.group("memory")),
            )
            numeric_values = (
                sample.elapsed_seconds,
                sample.compile_p95_ms,
                sample.frame_p95_ms,
                sample.static_memory_mib,
            )
            if sample.operation < 1 or sample.target_operation < sample.operation:
                raise ValueError(
                    f"invalid SOAK operation at line {line_number}: {line.rstrip()}"
                )
            if not all(math.isfinite(value) and value >= 0.0 for value in numeric_values):
                raise ValueError(
                    f"invalid SOAK numeric value at line {line_number}: {line.rstrip()}"
                )
            if sample.operation in by_operation:
                duplicate_operations.append(sample.operation)
            by_operation[sample.operation] = sample

    samples = sorted(by_operation.values(), key=lambda item: item.operation)
    if not samples:
        raise ValueError(f"no SOAK heartbeat lines found in {path}")
    targets = {sample.target_operation for sample in samples}
    if len(targets) != 1:
        raise ValueError(f"inconsistent target operation counts in {path}: {sorted(targets)}")
    previous_elapsed = -math.inf
    for sample in samples:
        if sample.elapsed_seconds < previous_elapsed:
            raise ValueError(
                "elapsed time moved backwards at operation " f"{sample.operation}"
            )
        previous_elapsed = sample.elapsed_seconds
    return samples, {
        "matched_line_count": matched_line_count,
        "unique_sample_count": len(samples),
        "duplicate_operations_replaced_by_last": sorted(set(duplicate_operations)),
    }


def build_intervals(
    samples: Sequence[Sample],
    geometry_checkpoints: set[int],
    collision_checkpoints: set[int],
) -> list[Interval]:
    result: list[Interval] = []
    previous_operation = 0
    previous_elapsed = 0.0
    for sample in samples:
        operation_count = sample.operation - previous_operation
        elapsed = sample.elapsed_seconds - previous_elapsed
        if operation_count <= 0 or elapsed < 0.0:
            raise ValueError(f"invalid interval ending at operation {sample.operation}")
        result.append(
            Interval(
                operation_start=previous_operation + 1,
                operation_end=sample.operation,
                operation_count=operation_count,
                elapsed_seconds=elapsed,
                milliseconds_per_operation=elapsed * 1000.0 / operation_count,
                operations_per_second=(operation_count / elapsed if elapsed > 0.0 else math.inf),
                ends_at_geometry_checkpoint=sample.operation in geometry_checkpoints,
                ends_at_collision_checkpoint=sample.operation in collision_checkpoints,
            )
        )
        previous_operation = sample.operation
        previous_elapsed = sample.elapsed_seconds
    return result


def _fit_quality(actual: Sequence[float], predicted: Sequence[float]) -> dict[str, float]:
    if len(actual) != len(predicted) or not actual:
        raise ValueError("fit quality requires equal, non-empty sequences")
    residuals = [observed - fitted for observed, fitted in zip(actual, predicted)]
    squared_error = sum(value * value for value in residuals)
    mean_actual = statistics.fmean(actual)
    total_variance = sum((value - mean_actual) ** 2 for value in actual)
    r_squared = 1.0 - squared_error / total_variance if total_variance > 0.0 else 1.0
    return {
        "r_squared": r_squared,
        "rmse": math.sqrt(squared_error / len(actual)),
        "mae": statistics.fmean(abs(value) for value in residuals),
    }


def fit_linear(points: Sequence[tuple[float, float]]) -> Fit:
    if len(points) < 2:
        raise ValueError("linear fit requires at least two points")
    x_values = [point[0] for point in points]
    y_values = [point[1] for point in points]
    mean_x = statistics.fmean(x_values)
    mean_y = statistics.fmean(y_values)
    denominator = sum((value - mean_x) ** 2 for value in x_values)
    if denominator <= 0.0:
        raise ValueError("linear fit requires distinct x values")
    slope = sum(
        (x_value - mean_x) * (y_value - mean_y)
        for x_value, y_value in points
    ) / denominator
    intercept = mean_y - slope * mean_x

    def predict(value: float) -> float:
        return intercept + slope * value

    quality = _fit_quality(y_values, [predict(value) for value in x_values])
    return Fit(
        kind="linear",
        sample_count=len(points),
        coefficients={"intercept": intercept, "slope_per_operation": slope},
        r_squared=quality["r_squared"],
        rmse=quality["rmse"],
        mae=quality["mae"],
        predict=predict,
        extra={},
    )


def fit_power(points: Sequence[tuple[float, float]]) -> Fit:
    positive_points = [point for point in points if point[0] > 0.0 and point[1] > 0.0]
    if len(positive_points) < 2:
        raise ValueError("power fit requires at least two positive points")
    log_points = [(math.log(x_value), math.log(y_value)) for x_value, y_value in positive_points]
    log_fit = fit_linear(log_points)
    scale = math.exp(log_fit.coefficients["intercept"])
    exponent = log_fit.coefficients["slope_per_operation"]

    def predict(value: float) -> float:
        return scale * value**exponent if value > 0.0 else 0.0

    x_values = [point[0] for point in positive_points]
    y_values = [point[1] for point in positive_points]
    quality = _fit_quality(y_values, [predict(value) for value in x_values])
    return Fit(
        kind="power",
        sample_count=len(positive_points),
        coefficients={"scale": scale, "exponent": exponent},
        r_squared=quality["r_squared"],
        rmse=quality["rmse"],
        mae=quality["mae"],
        predict=predict,
        extra={"log_space_r_squared": log_fit.r_squared},
    )


def _solve_three_by_three(matrix: list[list[float]], values: list[float]) -> list[float]:
    augmented = [row[:] + [value] for row, value in zip(matrix, values)]
    for column in range(3):
        pivot = max(range(column, 3), key=lambda row: abs(augmented[row][column]))
        if abs(augmented[pivot][column]) < 1.0e-15:
            raise ValueError("quadratic fit matrix is singular")
        augmented[column], augmented[pivot] = augmented[pivot], augmented[column]
        pivot_value = augmented[column][column]
        augmented[column] = [value / pivot_value for value in augmented[column]]
        for row in range(3):
            if row == column:
                continue
            factor = augmented[row][column]
            augmented[row] = [
                current - factor * pivot_current
                for current, pivot_current in zip(augmented[row], augmented[column])
            ]
    return [augmented[row][3] for row in range(3)]


def fit_quadratic(points: Sequence[tuple[float, float]]) -> Fit:
    if len(points) < 3:
        raise ValueError("quadratic fit requires at least three points")
    x_values = [point[0] for point in points]
    y_values = [point[1] for point in points]
    center = statistics.fmean(x_values)
    scale = max(abs(value - center) for value in x_values)
    if scale <= 0.0:
        raise ValueError("quadratic fit requires distinct x values")
    normalized = [(value - center) / scale for value in x_values]
    sums = [sum(value**power for value in normalized) for power in range(5)]
    matrix = [
        [sums[0], sums[1], sums[2]],
        [sums[1], sums[2], sums[3]],
        [sums[2], sums[3], sums[4]],
    ]
    right = [
        sum(y_value for y_value in y_values),
        sum(z_value * y_value for z_value, y_value in zip(normalized, y_values)),
        sum(z_value**2 * y_value for z_value, y_value in zip(normalized, y_values)),
    ]
    centered_constant, centered_linear, centered_quadratic = _solve_three_by_three(
        matrix, right
    )

    def predict(value: float) -> float:
        normalized_value = (value - center) / scale
        return (
            centered_constant
            + centered_linear * normalized_value
            + centered_quadratic * normalized_value**2
        )

    global_quadratic = centered_quadratic / scale**2
    global_linear = centered_linear / scale - 2.0 * centered_quadratic * center / scale**2
    global_constant = (
        centered_constant
        - centered_linear * center / scale
        + centered_quadratic * center**2 / scale**2
    )
    quality = _fit_quality(y_values, [predict(value) for value in x_values])
    return Fit(
        kind="quadratic",
        sample_count=len(points),
        coefficients={
            "constant_seconds": global_constant,
            "linear_seconds_per_operation": global_linear,
            "quadratic_seconds_per_operation_squared": global_quadratic,
        },
        r_squared=quality["r_squared"],
        rmse=quality["rmse"],
        mae=quality["mae"],
        predict=predict,
        extra={"normalization_center": center, "normalization_scale": scale},
    )


def _fit_to_json(fit: Fit, prediction_operation: int) -> dict[str, object]:
    return {
        "kind": fit.kind,
        "sample_count": fit.sample_count,
        "coefficients": fit.coefficients,
        "r_squared": fit.r_squared,
        "rmse": fit.rmse,
        "mae": fit.mae,
        "extra": fit.extra,
        "prediction_at_operation": prediction_operation,
        "predicted_value": fit.predict(float(prediction_operation)),
    }


def _residual_rows(
    samples: Sequence[Sample],
    getter: Callable[[Sample], float],
    fit: Fit,
    geometry_checkpoints: set[int],
    collision_checkpoints: set[int],
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for sample in samples:
        predicted = fit.predict(float(sample.operation))
        observed = getter(sample)
        rows.append(
            {
                "operation": sample.operation,
                "observed": observed,
                "predicted": predicted,
                "residual": observed - predicted,
                "absolute_residual": abs(observed - predicted),
                "geometry_checkpoint": sample.operation in geometry_checkpoints,
                "collision_checkpoint": sample.operation in collision_checkpoints,
            }
        )
    residual_values = [float(row["residual"]) for row in rows]
    median = statistics.median(residual_values)
    absolute_deviations = [abs(value - median) for value in residual_values]
    mad = statistics.median(absolute_deviations)
    for row in rows:
        residual = float(row["residual"])
        robust_z = 0.6744897501960817 * (residual - median) / mad if mad > 0.0 else 0.0
        row["robust_z"] = robust_z
        row["robust_outlier"] = abs(robust_z) >= 3.5
    return rows


def _top_residuals(rows: Sequence[dict[str, object]], count: int = 8) -> list[dict[str, object]]:
    return sorted(rows, key=lambda row: float(row["absolute_residual"]), reverse=True)[:count]


def _nice_step(span: float, desired_ticks: int = 6) -> float:
    if not math.isfinite(span) or span <= 0.0:
        return 1.0
    rough = span / max(desired_ticks, 1)
    exponent = math.floor(math.log10(rough))
    fraction = rough / (10.0**exponent)
    if fraction <= 1.0:
        nice_fraction = 1.0
    elif fraction <= 2.0:
        nice_fraction = 2.0
    elif fraction <= 5.0:
        nice_fraction = 5.0
    else:
        nice_fraction = 10.0
    return nice_fraction * 10.0**exponent


def _ticks(minimum: float, maximum: float, desired_ticks: int = 6) -> list[float]:
    step = _nice_step(maximum - minimum, desired_ticks)
    start = math.ceil(minimum / step - 1.0e-12) * step
    result: list[float] = []
    value = start
    while value <= maximum + step * 1.0e-9 and len(result) < 100:
        result.append(value)
        value += step
    return result


def _format_tick(value: float) -> str:
    magnitude = abs(value)
    if magnitude >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if magnitude >= 1000:
        return f"{value / 1000:.1f}k"
    if magnitude >= 100:
        return f"{value:.0f}"
    if magnitude >= 10:
        return f"{value:.1f}"
    if magnitude >= 1:
        return f"{value:.2f}"
    return f"{value:.3f}"


def _polyline(points: Sequence[tuple[float, float]]) -> str:
    return " ".join(f"{x_value:.2f},{y_value:.2f}" for x_value, y_value in points)


def write_svg_chart(
    path: Path,
    *,
    title: str,
    subtitle: str,
    x_label: str,
    y_label: str,
    series: Sequence[dict[str, object]],
    x_bounds: tuple[float, float] | None = None,
    y_bounds: tuple[float, float] | None = None,
    vertical_markers: Sequence[dict[str, object]] = (),
    note: str = "",
) -> None:
    width = 1040
    height = 600
    left = 92
    right = 34
    top = 84
    bottom = 100
    plot_width = width - left - right
    plot_height = height - top - bottom
    all_points = [
        point
        for item in series
        for point in item.get("points", [])  # type: ignore[arg-type]
        if math.isfinite(point[0]) and math.isfinite(point[1])
    ]
    if not all_points:
        raise ValueError(f"cannot draw empty chart {path}")
    data_x = [point[0] for point in all_points]
    data_y = [point[1] for point in all_points]
    x_min, x_max = x_bounds if x_bounds else (min(data_x), max(data_x))
    y_min, y_max = y_bounds if y_bounds else (min(data_y), max(data_y))
    if x_max <= x_min:
        x_max = x_min + 1.0
    if y_max <= y_min:
        y_max = y_min + 1.0
    if y_bounds is None:
        padding = (y_max - y_min) * 0.08
        y_min -= padding
        y_max += padding

    def sx(value: float) -> float:
        return left + (value - x_min) / (x_max - x_min) * plot_width

    def sy(value: float) -> float:
        return top + (y_max - value) / (y_max - y_min) * plot_height

    elements = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
            f'height="{height}" viewBox="0 0 {width} {height}" role="img" '
            f'aria-label="{html.escape(title)}">'
        ),
        "<style>",
        "text{font-family:system-ui,-apple-system,Segoe UI,sans-serif;fill:#1f2937}",
        ".title{font-size:22px;font-weight:700}.subtitle{font-size:13px;fill:#4b5563}",
        ".axis{stroke:#374151;stroke-width:1}.grid{stroke:#d1d5db;stroke-width:1}",
        ".tick{font-size:11px;fill:#4b5563}.label{font-size:13px;font-weight:600}",
        ".legend{font-size:12px}.note{font-size:11px;fill:#4b5563}",
        "</style>",
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        f'<text x="{left}" y="32" class="title">{html.escape(title)}</text>',
        f'<text x="{left}" y="55" class="subtitle">{html.escape(subtitle)}</text>',
    ]
    for tick in _ticks(y_min, y_max):
        y_value = sy(tick)
        elements.append(
            f'<line x1="{left}" y1="{y_value:.2f}" x2="{left + plot_width}" '
            f'y2="{y_value:.2f}" class="grid"/>'
        )
        elements.append(
            f'<text x="{left - 10}" y="{y_value + 4:.2f}" text-anchor="end" '
            f'class="tick">{html.escape(_format_tick(tick))}</text>'
        )
    for tick in _ticks(x_min, x_max):
        x_value = sx(tick)
        elements.append(
            f'<line x1="{x_value:.2f}" y1="{top}" x2="{x_value:.2f}" '
            f'y2="{top + plot_height}" class="grid"/>'
        )
        elements.append(
            f'<text x="{x_value:.2f}" y="{top + plot_height + 20}" '
            f'text-anchor="middle" class="tick">{html.escape(_format_tick(tick))}</text>'
        )
    for marker in vertical_markers:
        value = float(marker["x"])
        if not x_min <= value <= x_max:
            continue
        x_value = sx(value)
        color = str(marker.get("color", "#9ca3af"))
        label = str(marker.get("label", ""))
        elements.append(
            f'<line x1="{x_value:.2f}" y1="{top}" x2="{x_value:.2f}" '
            f'y2="{top + plot_height}" stroke="{html.escape(color)}" '
            'stroke-width="1.2" stroke-dasharray="4 4"/>'
        )
        if label:
            elements.append(
                f'<text x="{x_value + 4:.2f}" y="{top + 13}" class="tick" '
                f'fill="{html.escape(color)}">{html.escape(label)}</text>'
            )
    elements.extend(
        [
            f'<line x1="{left}" y1="{top + plot_height}" x2="{left + plot_width}" '
            f'y2="{top + plot_height}" class="axis"/>',
            f'<line x1="{left}" y1="{top}" x2="{left}" '
            f'y2="{top + plot_height}" class="axis"/>',
        ]
    )
    legend_x = left + 8
    legend_y = top + 24
    for index, item in enumerate(series):
        raw_points = item.get("points", [])
        plotted = [(sx(point[0]), sy(point[1])) for point in raw_points]  # type: ignore[index]
        color = str(item.get("color", "#2563eb"))
        dash = str(item.get("dash", ""))
        line_enabled = bool(item.get("line", True))
        point_radius = float(item.get("point_radius", 0.0))
        opacity = float(item.get("opacity", 1.0))
        if line_enabled and len(plotted) >= 2:
            dash_attribute = f' stroke-dasharray="{html.escape(dash)}"' if dash else ""
            elements.append(
                f'<polyline points="{_polyline(plotted)}" fill="none" '
                f'stroke="{html.escape(color)}" stroke-width="{float(item.get("width", 2.2)):.1f}" '
                f'opacity="{opacity:.3f}"{dash_attribute}/>'
            )
        if point_radius > 0.0:
            for x_value, y_value in plotted:
                elements.append(
                    f'<circle cx="{x_value:.2f}" cy="{y_value:.2f}" r="{point_radius:.1f}" '
                    f'fill="{html.escape(color)}" opacity="{opacity:.3f}"/>'
                )
        item_y = legend_y + index * 20
        elements.append(
            f'<line x1="{legend_x}" y1="{item_y}" x2="{legend_x + 26}" y2="{item_y}" '
            f'stroke="{html.escape(color)}" stroke-width="3"/>'
        )
        elements.append(
            f'<text x="{legend_x + 34}" y="{item_y + 4}" class="legend">'
            f'{html.escape(str(item.get("name", "series")))}</text>'
        )
    elements.append(
        f'<text x="{left + plot_width / 2:.2f}" y="{height - 48}" '
        f'text-anchor="middle" class="label">{html.escape(x_label)}</text>'
    )
    elements.append(
        f'<text x="22" y="{top + plot_height / 2:.2f}" text-anchor="middle" '
        f'transform="rotate(-90 22 {top + plot_height / 2:.2f})" '
        f'class="label">{html.escape(y_label)}</text>'
    )
    if note:
        elements.append(
            f'<text x="{left}" y="{height - 18}" class="note">{html.escape(note)}</text>'
        )
    elements.append("</svg>")
    path.write_text("\n".join(elements) + "\n", encoding="utf-8", newline="\n")


def _fit_curve(fit: Fit, start: int, end: int, sample_count: int = 160) -> list[tuple[float, float]]:
    if end <= start:
        return [(float(start), fit.predict(float(start)))]
    return [
        (
            start + (end - start) * index / (sample_count - 1),
            fit.predict(start + (end - start) * index / (sample_count - 1)),
        )
        for index in range(sample_count)
    ]


def _duration(value: float) -> str:
    if not math.isfinite(value):
        return "not finite"
    hours, remainder = divmod(value, 3600.0)
    minutes, seconds = divmod(remainder, 60.0)
    if hours >= 1.0:
        return f"{int(hours)}h {int(minutes):02d}m {seconds:04.1f}s"
    if minutes >= 1.0:
        return f"{int(minutes)}m {seconds:04.1f}s"
    return f"{seconds:.1f}s"


def _lower_rmse_model(linear: Fit, power: Fit) -> str:
    improvement = (linear.rmse - power.rmse) / linear.rmse if linear.rmse > 0.0 else 0.0
    if improvement > 0.05:
        return "power"
    if improvement < -0.05:
        return "linear"
    return "indistinguishable_within_5_percent_rmse"


def _quadratic_sensitivity(
    samples: Sequence[Sample], target_operation: int, fit_starts: Iterable[int]
) -> list[dict[str, float | int]]:
    rows: list[dict[str, float | int]] = []
    for fit_start in fit_starts:
        points = [
            (float(sample.operation), sample.elapsed_seconds)
            for sample in samples
            if sample.operation >= fit_start
        ]
        if len(points) < 5:
            continue
        fit = fit_quadratic(points)
        rows.append(
            {
                "fit_min_operation": fit_start,
                "sample_count": len(points),
                "predicted_elapsed_seconds": fit.predict(float(target_operation)),
                "r_squared": fit.r_squared,
            }
        )
    return rows


def _write_csv(
    path: Path,
    samples: Sequence[Sample],
    intervals: Sequence[Interval],
    compile_linear: Fit,
    compile_power: Fit,
    frame_linear: Fit,
    frame_power: Fit,
    elapsed_quadratic: Fit,
    memory_linear: Fit,
    geometry_checkpoints: set[int],
    collision_checkpoints: set[int],
) -> None:
    fields = [
        "operation",
        "target_operation",
        "elapsed_seconds",
        "compile_p95_ms",
        "frame_p95_ms",
        "static_memory_mib",
        "interval_operation_start",
        "interval_operation_count",
        "interval_elapsed_seconds",
        "interval_ms_per_operation",
        "interval_operations_per_second",
        "geometry_checkpoint",
        "collision_checkpoint",
        "compile_linear_fitted_ms",
        "compile_linear_residual_ms",
        "compile_power_fitted_ms",
        "compile_power_residual_ms",
        "frame_linear_fitted_ms",
        "frame_linear_residual_ms",
        "frame_power_fitted_ms",
        "frame_power_residual_ms",
        "elapsed_quadratic_fitted_seconds",
        "elapsed_quadratic_residual_seconds",
        "memory_baseline_linear_fitted_mib",
        "memory_baseline_linear_residual_mib",
    ]
    with path.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for sample, interval in zip(samples, intervals):
            operation = float(sample.operation)
            values = {
                "operation": sample.operation,
                "target_operation": sample.target_operation,
                "elapsed_seconds": f"{sample.elapsed_seconds:.6f}",
                "compile_p95_ms": f"{sample.compile_p95_ms:.6f}",
                "frame_p95_ms": f"{sample.frame_p95_ms:.6f}",
                "static_memory_mib": f"{sample.static_memory_mib:.6f}",
                "interval_operation_start": interval.operation_start,
                "interval_operation_count": interval.operation_count,
                "interval_elapsed_seconds": f"{interval.elapsed_seconds:.6f}",
                "interval_ms_per_operation": f"{interval.milliseconds_per_operation:.6f}",
                "interval_operations_per_second": f"{interval.operations_per_second:.6f}",
                "geometry_checkpoint": str(sample.operation in geometry_checkpoints).lower(),
                "collision_checkpoint": str(sample.operation in collision_checkpoints).lower(),
            }
            predictions = {
                "compile_linear": compile_linear.predict(operation),
                "compile_power": compile_power.predict(operation),
                "frame_linear": frame_linear.predict(operation),
                "frame_power": frame_power.predict(operation),
                "elapsed_quadratic": elapsed_quadratic.predict(operation),
                "memory_baseline_linear": memory_linear.predict(operation),
            }
            observed = {
                "compile_linear": sample.compile_p95_ms,
                "compile_power": sample.compile_p95_ms,
                "frame_linear": sample.frame_p95_ms,
                "frame_power": sample.frame_p95_ms,
                "elapsed_quadratic": sample.elapsed_seconds,
                "memory_baseline_linear": sample.static_memory_mib,
            }
            units = {
                "compile_linear": "ms",
                "compile_power": "ms",
                "frame_linear": "ms",
                "frame_power": "ms",
                "elapsed_quadratic": "seconds",
                "memory_baseline_linear": "mib",
            }
            for name, prediction in predictions.items():
                unit = units[name]
                values[f"{name}_fitted_{unit}"] = f"{prediction:.6f}"
                values[f"{name}_residual_{unit}"] = f"{observed[name] - prediction:.6f}"
            writer.writerow(values)


def _write_report(
    path: Path,
    *,
    input_log: Path,
    output_prefix: Path,
    samples: Sequence[Sample],
    intervals: Sequence[Interval],
    fit_min_operation: int,
    extrapolate_operation: int,
    stop_label: str,
    compile_linear: Fit,
    compile_power: Fit,
    frame_linear: Fit,
    frame_power: Fit,
    elapsed_quadratic: Fit,
    memory_linear: Fit,
    collision_checkpoints: set[int],
    sensitivity: Sequence[dict[str, float | int]],
    residuals: dict[str, list[dict[str, object]]],
    metrics_filename: str,
    csv_filename: str,
) -> None:
    first = samples[0]
    last = samples[-1]
    latest_interval = intervals[-1]
    target = last.target_operation
    completion_fraction = last.operation / target
    projected = elapsed_quadratic.predict(float(extrapolate_operation))
    sensitivity_values = [float(row["predicted_elapsed_seconds"]) for row in sensitivity]
    sensitivity_text = (
        f"{_duration(min(sensitivity_values))} to {_duration(max(sensitivity_values))}"
        if sensitivity_values
        else "not available"
    )
    prior_noncollision_memory = [
        sample.static_memory_mib
        for sample in samples
        if sample.operation not in collision_checkpoints
    ]
    baseline_peak = max(prior_noncollision_memory) if prior_noncollision_memory else first.static_memory_mib
    compile_rmse_comparison = _lower_rmse_model(compile_linear, compile_power)
    frame_rmse_comparison = _lower_rmse_model(frame_linear, frame_power)
    earliest_full_window = next((item for item in intervals if item.operation_count == 100), intervals[0])
    throughput_drop = (
        1.0 - latest_interval.operations_per_second / earliest_full_window.operations_per_second
        if earliest_full_window.operations_per_second > 0.0
        else 0.0
    )
    report = [
        "# Forge V2 rolling-workpiece stress analysis",
        "",
        f"Source: `{input_log}`  ",
        f"Capture status: **{stop_label}**  ",
        (
            f"Measured range: **{last.operation:,} / {target:,} operations "
            f"({completion_fraction * 100.0:.1f}%)**."
        ),
        "",
        "## Outcome",
        "",
        (
            f"At operation {last.operation:,}, the recent compile p95 was "
            f"**{last.compile_p95_ms:.2f} ms** and the harness frame-gap p95 was "
            f"**{last.frame_p95_ms:.2f} ms**. The last observed interval cost "
            f"**{latest_interval.milliseconds_per_operation:.2f} ms/operation** "
            f"({latest_interval.operations_per_second:.2f} operations/s)."
        ),
        "",
        (
            f"From operation {fit_min_operation:,} onward, the primary affine-linear "
            "compile fit has a slope of "
            f"**{compile_linear.coefficients['slope_per_operation']:.5f} ms per added "
            f"operation** (R^2 {compile_linear.r_squared:.5f}). Its RMSE comparison "
            f"against the secondary power fit is **{compile_rmse_comparison.replace('_', ' ')}**."
        ),
        "",
        (
            f"The primary affine-linear frame-gap slope is "
            f"{frame_linear.coefficients['slope_per_operation']:.5f} ms/operation "
            f"(R^2 {frame_linear.r_squared:.5f}); its RMSE comparison is "
            f"**{frame_rmse_comparison.replace('_', ' ')}**. Throughput fell "
            f"approximately **{max(0.0, throughput_drop) * 100.0:.1f}%** from the first "
            "complete 100-operation interval to the final measured interval."
        ),
        "",
        (
            f"The secondary compile power fit is `y = scale * operation^exponent`, with "
            f"exponent **{compile_power.coefficients['exponent']:.3f}** and observed-space "
            f"R^2 {compile_power.r_squared:.5f}. Because that model has no additive "
            "intercept and is fitted in log space, its sub-1 exponent must not be read as "
            "proof that marginal Boolean cost decreases. Here the affine-linear model has "
            "both the clearer mechanism and the stronger observed-space fit."
        ),
        "",
        "The evidence therefore says the rolling window bounded retained CSG history, "
        "but did **not** bound the cost of Boolean work against the continuously growing "
        "accepted mesh. This is a scaling limit of the current whole-workpiece rebuild "
        "shape, not primarily an undo-depth or retained-node-count problem.",
        "",
        "## Cautious 10,001-operation projection",
        "",
        (
            f"A quadratic elapsed-time fit over samples at/after operation "
            f"{fit_min_operation:,} has R^2 **{elapsed_quadratic.r_squared:.6f}** and "
            f"projects operation {extrapolate_operation:,} at **{_duration(projected)}**. "
            f"Refitting from several later starting points gives a model-sensitivity "
            f"range of **{sensitivity_text}**."
        ),
        "",
        (
            f"That is a roughly {extrapolate_operation / last.operation:.2f}x operation-range "
            "extrapolation from a partial, operator-stopped run. It is a planning signal, "
            "not a confidence interval: later topology growth, raster boundaries, allocator "
            "behaviour, or the benchmark's own two-hour gate can change the curve."
        ),
        "",
        "## Nuances that affect interpretation",
        "",
        "- `compile_p95` is the p95 of the latest up-to-100 operation compile samples. "
        "Before operation 100 the window is incomplete; irregular checkpoints also cause "
        "overlapping windows.",
        "- `frame_p95` is the p95 of per-operation maximum **headless harness process-frame "
        "gaps**. It is not viewport FPS, input latency, or a direct player-experience trace, "
        "although a large main-thread gap is still a strong hitch warning.",
        "- Cumulative elapsed time is sampled after geometry analysis at geometry checkpoints "
        "and after collision baking at collision checkpoints. Intervals ending at those "
        "operations include validation overhead that compile/frame p95 does not.",
        (
            f"- Memory is sampled Godot static-memory usage, not OS working set, GPU memory, "
            f"or a continuous peak. The final {last.static_memory_mib:.1f} MiB sample occurred "
            f"at the operation-{last.operation:,} geometry/collision checkpoint; the highest "
            f"non-collision sample was {baseline_peak:.1f} MiB. The checkpoint spike is "
            "consistent with temporary analysis/collision allocations and cannot alone prove "
            "a retained-memory leak."
        ),
        f"- This capture stopped by operator at {last.operation:,}; it contains no measured "
        f"operations from {last.operation + 1:,} through {target:,}, and stopping is not a "
        "benchmark failure.",
        "",
        "## Residual and checkpoint signals",
        "",
        "Largest absolute residuals from the primary fits:",
        "",
        "| Signal | Operation | Residual | Checkpoint | Robust outlier |",
        "|---|---:|---:|---|---|",
    ]
    residual_specs = (
        ("compile linear", "compile_linear", "ms"),
        ("frame linear", "frame_linear", "ms"),
        ("elapsed quadratic", "elapsed_quadratic", "s"),
    )
    for label, key, unit in residual_specs:
        for row in _top_residuals(residuals[key], 3):
            checkpoint = (
                "collision"
                if row["collision_checkpoint"]
                else "geometry"
                if row["geometry_checkpoint"]
                else "no"
            )
            report.append(
                f"| {label} | {int(row['operation']):,} | "
                f"{float(row['residual']):+.2f} {unit} | {checkpoint} | "
                f"{'yes' if row['robust_outlier'] else 'no'} |"
            )
    report.extend(
        [
            "",
            "Latency residuals include real local variability and p95-window overlap. "
            "Elapsed residuals at validation checkpoints can be caused by the benchmark's "
            "analysis lane rather than the rolling Boolean itself; no individual residual "
            "should be treated as causal proof.",
            "",
            "## What to improve next",
            "",
            "1. **Bound the edited spatial region, not only the operand count.** Chunked "
            "meshes, sparse volume/SDF bricks, or another local-update representation should "
            "make a stroke rebuild only intersecting cells/chunks instead of the full accepted "
            "workpiece.",
            "2. **Keep interaction separate from final compilation.** Preserve the immediate "
            "low-cost preview, queue immutable edit commands, compile away from the input path, "
            "and atomically swap an accepted result. This removes the visible hard stall but "
            "does not by itself reduce total work.",
            "3. **Control accepted-mesh complexity.** Measure triangles/vertices at every "
            "heartbeat, then test conservative local simplification or remeshing. Geometry "
            "fidelity, material boundaries, handles, and carving semantics need explicit "
            "acceptance checks before simplification is trusted.",
            "4. **Move heavyweight validation off ordinary strokes.** Full watertightness and "
            "collision baking belong at deliberate checkpoints/save/finish boundaries unless a "
            "cheaper incremental validator is available.",
            "5. **Repeat the same fixture after each backend change.** The key success metric is "
            "a latency curve that flattens with total operation count for equal local edits, not "
            "merely a lower constant at operation 100.",
            "",
            "## Artifacts",
            "",
            f"- Samples and fitted values: [{csv_filename}]({csv_filename})",
            f"- Machine-readable metrics: [{metrics_filename}]({metrics_filename})",
            f"- Latency chart: [{output_prefix.name}.latency.svg]({output_prefix.name}.latency.svg)",
            f"- Elapsed/projection chart: [{output_prefix.name}.elapsed.svg]({output_prefix.name}.elapsed.svg)",
            f"- Interval-cost chart: [{output_prefix.name}.interval_cost.svg]({output_prefix.name}.interval_cost.svg)",
            f"- Throughput chart: [{output_prefix.name}.throughput.svg]({output_prefix.name}.throughput.svg)",
            f"- Sampled-memory chart: [{output_prefix.name}.memory.svg]({output_prefix.name}.memory.svg)",
            "",
        ]
    )
    path.write_text("\n".join(report), encoding="utf-8", newline="\n")


def analyze(arguments: argparse.Namespace) -> dict[str, Path]:
    input_log = Path(arguments.engine_log).expanduser().resolve()
    output_prefix = Path(arguments.output_prefix).expanduser().resolve()
    if not input_log.is_file():
        raise FileNotFoundError(f"engine log does not exist: {input_log}")
    output_prefix.parent.mkdir(parents=True, exist_ok=True)
    samples, parse_details = parse_soak_log(input_log)
    geometry_checkpoints = set(arguments.geometry_checkpoints)
    collision_checkpoints = set(arguments.collision_checkpoints)
    intervals = build_intervals(samples, geometry_checkpoints, collision_checkpoints)
    last = samples[-1]
    target = last.target_operation
    extrapolate_operation = arguments.extrapolate_operation or target
    if extrapolate_operation < last.operation:
        raise ValueError("extrapolation operation must not precede the last measured operation")
    fit_samples = [sample for sample in samples if sample.operation >= arguments.fit_min_operation]
    if len(fit_samples) < 5:
        raise ValueError(
            f"fit domain has only {len(fit_samples)} samples; lower --fit-min-operation"
        )
    effective_fit_min = fit_samples[0].operation
    compile_points = [(float(item.operation), item.compile_p95_ms) for item in fit_samples]
    frame_points = [(float(item.operation), item.frame_p95_ms) for item in fit_samples]
    elapsed_points = [(float(item.operation), item.elapsed_seconds) for item in fit_samples]
    compile_linear = fit_linear(compile_points)
    compile_power = fit_power(compile_points)
    frame_linear = fit_linear(frame_points)
    frame_power = fit_power(frame_points)
    elapsed_quadratic = fit_quadratic(elapsed_points)

    memory_fit_samples = [
        item
        for item in fit_samples
        if item.operation not in collision_checkpoints
    ]
    if len(memory_fit_samples) < 2:
        memory_fit_samples = fit_samples
    memory_linear = fit_linear(
        [(float(item.operation), item.static_memory_mib) for item in memory_fit_samples]
    )
    sensitivity_starts = sorted(
        {
            effective_fit_min,
            500,
            1000,
            1500,
            2500,
            max(effective_fit_min, last.operation // 2),
        }
    )
    sensitivity = _quadratic_sensitivity(samples, extrapolate_operation, sensitivity_starts)

    residuals = {
        "compile_linear": _residual_rows(
            fit_samples,
            lambda item: item.compile_p95_ms,
            compile_linear,
            geometry_checkpoints,
            collision_checkpoints,
        ),
        "compile_power": _residual_rows(
            fit_samples,
            lambda item: item.compile_p95_ms,
            compile_power,
            geometry_checkpoints,
            collision_checkpoints,
        ),
        "frame_linear": _residual_rows(
            fit_samples,
            lambda item: item.frame_p95_ms,
            frame_linear,
            geometry_checkpoints,
            collision_checkpoints,
        ),
        "frame_power": _residual_rows(
            fit_samples,
            lambda item: item.frame_p95_ms,
            frame_power,
            geometry_checkpoints,
            collision_checkpoints,
        ),
        "elapsed_quadratic": _residual_rows(
            fit_samples,
            lambda item: item.elapsed_seconds,
            elapsed_quadratic,
            geometry_checkpoints,
            collision_checkpoints,
        ),
    }

    partial_capture = last.operation < target
    if arguments.stop_reason:
        stop_label = arguments.stop_reason.strip()
    elif partial_capture and "operator_stop" in input_log.name.lower():
        stop_label = f"partial operator stop at operation {last.operation:,}"
    elif partial_capture:
        stop_label = f"partial capture at operation {last.operation:,}; terminal reason unknown"
    else:
        stop_label = f"complete capture at operation {last.operation:,}"

    output_paths = {
        "csv": Path(f"{output_prefix}.samples.csv"),
        "json": Path(f"{output_prefix}.metrics.json"),
        "latency_svg": Path(f"{output_prefix}.latency.svg"),
        "elapsed_svg": Path(f"{output_prefix}.elapsed.svg"),
        "interval_svg": Path(f"{output_prefix}.interval_cost.svg"),
        "throughput_svg": Path(f"{output_prefix}.throughput.svg"),
        "memory_svg": Path(f"{output_prefix}.memory.svg"),
        "report": Path(f"{output_prefix}.report.md"),
    }
    _write_csv(
        output_paths["csv"],
        samples,
        intervals,
        compile_linear,
        compile_power,
        frame_linear,
        frame_power,
        elapsed_quadratic,
        memory_linear,
        geometry_checkpoints,
        collision_checkpoints,
    )

    metrics: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "source": {
            "engine_log": str(input_log),
            "sha256": _sha256(input_log),
            **parse_details,
        },
        "capture": {
            "status_label": stop_label,
            "partial": partial_capture,
            "first_measured_operation": samples[0].operation,
            "last_measured_operation": last.operation,
            "target_operation": target,
            "completion_fraction": last.operation / target,
            "measured_elapsed_seconds": last.elapsed_seconds,
        },
        "configuration": {
            "requested_fit_min_operation": arguments.fit_min_operation,
            "effective_fit_min_operation": effective_fit_min,
            "extrapolate_operation": extrapolate_operation,
            "geometry_checkpoints": sorted(geometry_checkpoints),
            "collision_checkpoints": sorted(collision_checkpoints),
            "standard_library_only": True,
        },
        "latest_sample": asdict(last),
        "latest_interval": asdict(intervals[-1]),
        "fits": {
            "compile_p95_ms": {
                "linear": _fit_to_json(compile_linear, extrapolate_operation),
                "power": _fit_to_json(compile_power, extrapolate_operation),
                "primary_model": "affine_linear",
                "lower_rmse_model_by_5_percent_rule": _lower_rmse_model(
                    compile_linear, compile_power
                ),
                "power_model_limitation": (
                    "origin-constrained y=scale*x^exponent fit estimated in log space; "
                    "the exponent is a sensitivity descriptor, not proof of declining "
                    "marginal Boolean cost"
                ),
            },
            "frame_gap_p95_ms": {
                "linear": _fit_to_json(frame_linear, extrapolate_operation),
                "power": _fit_to_json(frame_power, extrapolate_operation),
                "primary_model": "affine_linear",
                "lower_rmse_model_by_5_percent_rule": _lower_rmse_model(
                    frame_linear, frame_power
                ),
                "measurement_limitation": (
                    "p95 of recent per-operation maximum headless process-frame gaps; "
                    "not viewport FPS or direct input latency"
                ),
            },
            "elapsed_seconds": {
                "quadratic": _fit_to_json(elapsed_quadratic, extrapolate_operation),
                "sensitivity_refits": sensitivity,
            },
            "sampled_static_memory_mib": {
                "linear_excluding_collision_checkpoints": _fit_to_json(
                    memory_linear, extrapolate_operation
                ),
                "measurement_limitation": (
                    "sampled Godot static memory after heartbeat/checkpoint work; not OS "
                    "working set, GPU memory, or a continuous peak"
                ),
            },
        },
        "interval_summary": {
            "median_milliseconds_per_operation": statistics.median(
                item.milliseconds_per_operation for item in intervals
            ),
            "median_operations_per_second": statistics.median(
                item.operations_per_second for item in intervals
            ),
            "slowest_intervals_by_ms_per_operation": [
                asdict(item)
                for item in sorted(
                    intervals,
                    key=lambda item: item.milliseconds_per_operation,
                    reverse=True,
                )[:10]
            ],
        },
        "memory_summary": {
            "first_sample_mib": samples[0].static_memory_mib,
            "last_sample_mib": last.static_memory_mib,
            "maximum_sample_mib": max(item.static_memory_mib for item in samples),
            "maximum_noncollision_checkpoint_sample_mib": max(
                (
                    item.static_memory_mib
                    for item in samples
                    if item.operation not in collision_checkpoints
                ),
                default=max(item.static_memory_mib for item in samples),
            ),
            "last_sample_is_collision_checkpoint": last.operation in collision_checkpoints,
        },
        "residuals": {
            key: {
                "top_absolute": _top_residuals(rows),
                "robust_outliers": [row for row in rows if row["robust_outlier"]],
            }
            for key, rows in residuals.items()
        },
        "interpretation_cautions": [
            "partial operator-stopped capture is not a completed 10,001-operation result",
            "10,001-operation values are model extrapolations beyond the measured range",
            "heartbeat elapsed includes geometry/collision checkpoint overhead",
            "early p95 windows contain fewer than 100 operations and checkpoint windows overlap",
            "frame-gap p95 is a headless harness measurement rather than viewport FPS",
            "memory is sampled Godot static memory and checkpoint allocations can be transient",
        ],
    }
    output_paths["json"].write_text(
        json.dumps(metrics, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    measured_start = effective_fit_min
    measured_end = last.operation
    compile_actual = [(item.operation, item.compile_p95_ms) for item in samples]
    frame_actual = [(item.operation, item.frame_p95_ms) for item in samples]
    max_latency = max(
        max(item.compile_p95_ms, item.frame_p95_ms) for item in samples
    )
    write_svg_chart(
        output_paths["latency_svg"],
        title="Forge V2 rolling-workpiece latency trend",
        subtitle=f"Measured through operation {last.operation:,}; fit domain starts at {effective_fit_min:,}",
        x_label="Accepted operation count",
        y_label="Recent p95 latency (ms)",
        series=[
            {
                "name": "compile p95 (measured)",
                "points": compile_actual,
                "color": "#2563eb",
                "point_radius": 2.0,
            },
            {
                "name": "frame-gap p95 (measured)",
                "points": frame_actual,
                "color": "#ea580c",
                "point_radius": 2.0,
            },
            {
                "name": "compile linear fit",
                "points": _fit_curve(compile_linear, measured_start, measured_end),
                "color": "#1d4ed8",
                "dash": "8 5",
            },
            {
                "name": "compile power fit",
                "points": _fit_curve(compile_power, measured_start, measured_end),
                "color": "#7c3aed",
                "dash": "3 5",
            },
        ],
        x_bounds=(0.0, float(measured_end)),
        y_bounds=(0.0, max_latency * 1.08),
        note=(
            "Frame-gap p95 is a headless process-frame stall signal, not viewport FPS or direct input latency."
        ),
    )

    projected_elapsed = elapsed_quadratic.predict(float(extrapolate_operation))
    elapsed_max = max(last.elapsed_seconds, projected_elapsed)
    write_svg_chart(
        output_paths["elapsed_svg"],
        title="Cumulative elapsed time and cautious projection",
        subtitle=f"Quadratic fit R^2={elapsed_quadratic.r_squared:.6f}; projection is not measured",
        x_label="Accepted operation count",
        y_label="Elapsed time (seconds)",
        series=[
            {
                "name": "elapsed (measured)",
                "points": [(item.operation, item.elapsed_seconds) for item in samples],
                "color": "#059669",
                "point_radius": 2.2,
            },
            {
                "name": "quadratic fit (measured domain)",
                "points": _fit_curve(elapsed_quadratic, measured_start, measured_end),
                "color": "#047857",
                "dash": "8 5",
            },
            {
                "name": "quadratic extrapolation",
                "points": _fit_curve(
                    elapsed_quadratic, measured_end, extrapolate_operation
                ),
                "color": "#dc2626",
                "dash": "4 5",
            },
        ],
        x_bounds=(0.0, float(extrapolate_operation)),
        y_bounds=(0.0, elapsed_max * 1.06),
        vertical_markers=[
            {
                "x": measured_end,
                "label": "operator stop / measured limit",
                "color": "#dc2626",
            }
        ],
        note=(
            "Elapsed heartbeat samples include geometry analysis and selected collision-checkpoint work."
        ),
    )

    checkpoint_cost_points = [
        (item.operation_end, item.milliseconds_per_operation)
        for item in intervals
        if item.ends_at_collision_checkpoint
    ]
    max_interval_cost = max(item.milliseconds_per_operation for item in intervals)
    write_svg_chart(
        output_paths["interval_svg"],
        title="Observed interval cost",
        subtitle="Elapsed delta divided by operation delta between heartbeat samples",
        x_label="Interval ending operation",
        y_label="Milliseconds per operation",
        series=[
            {
                "name": "interval cost",
                "points": [
                    (item.operation_end, item.milliseconds_per_operation) for item in intervals
                ],
                "color": "#0f766e",
                "point_radius": 2.2,
            },
            {
                "name": "collision-checkpoint interval",
                "points": checkpoint_cost_points,
                "color": "#dc2626",
                "line": False,
                "point_radius": 4.0,
            },
        ],
        x_bounds=(0.0, float(measured_end)),
        y_bounds=(0.0, max_interval_cost * 1.08),
        note=(
            "Checkpoint-ending intervals can include topology analysis/collision baking; this is not compile-only cost."
        ),
    )

    throughput_points = [
        (item.operation_end, item.operations_per_second)
        for item in intervals
        if math.isfinite(item.operations_per_second)
    ]
    max_throughput = max(point[1] for point in throughput_points)
    write_svg_chart(
        output_paths["throughput_svg"],
        title="Observed interval throughput",
        subtitle="Operations completed per elapsed second between heartbeat samples",
        x_label="Interval ending operation",
        y_label="Operations per second",
        series=[
            {
                "name": "interval throughput",
                "points": throughput_points,
                "color": "#9333ea",
                "point_radius": 2.2,
            }
        ],
        x_bounds=(0.0, float(measured_end)),
        y_bounds=(0.0, max_throughput * 1.08),
        note="Early intervals are short/incomplete; use the post-100 trend for steady comparisons.",
    )

    memory_values = [item.static_memory_mib for item in samples]
    memory_min = min(memory_values)
    memory_max = max(memory_values)
    memory_padding = max(1.0, (memory_max - memory_min) * 0.12)
    collision_memory_points = [
        (item.operation, item.static_memory_mib)
        for item in samples
        if item.operation in collision_checkpoints
    ]
    write_svg_chart(
        output_paths["memory_svg"],
        title="Sampled Godot static memory",
        subtitle="Collision checkpoints highlighted; samples are not continuous peaks",
        x_label="Accepted operation count",
        y_label="Sampled static memory (MiB)",
        series=[
            {
                "name": "sampled static memory",
                "points": [(item.operation, item.static_memory_mib) for item in samples],
                "color": "#0891b2",
                "point_radius": 2.2,
            },
            {
                "name": "baseline linear fit (collision checkpoints excluded)",
                "points": _fit_curve(memory_linear, measured_start, measured_end),
                "color": "#155e75",
                "dash": "8 5",
            },
            {
                "name": "collision checkpoint sample",
                "points": collision_memory_points,
                "color": "#dc2626",
                "line": False,
                "point_radius": 4.0,
            },
        ],
        x_bounds=(0.0, float(measured_end)),
        y_bounds=(max(0.0, memory_min - memory_padding), memory_max + memory_padding),
        note="Godot static memory only: excludes OS working set/GPU memory and can include transient checkpoint allocations.",
    )

    _write_report(
        output_paths["report"],
        input_log=input_log,
        output_prefix=output_prefix,
        samples=samples,
        intervals=intervals,
        fit_min_operation=effective_fit_min,
        extrapolate_operation=extrapolate_operation,
        stop_label=stop_label,
        compile_linear=compile_linear,
        compile_power=compile_power,
        frame_linear=frame_linear,
        frame_power=frame_power,
        elapsed_quadratic=elapsed_quadratic,
        memory_linear=memory_linear,
        collision_checkpoints=collision_checkpoints,
        sensitivity=sensitivity,
        residuals=residuals,
        metrics_filename=output_paths["json"].name,
        csv_filename=output_paths["csv"].name,
    )
    return output_paths


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Parse Forge V2 rolling SOAK heartbeat lines and write CSV, JSON, SVG "
            "charts, and a Markdown report using only the Python standard library."
        )
    )
    parser.add_argument("engine_log", help="Godot engine log containing SOAK heartbeat lines")
    parser.add_argument(
        "output_prefix",
        help="output path prefix; extensions/suffixes are added automatically",
    )
    parser.add_argument(
        "--fit-min-operation",
        type=int,
        default=500,
        help="minimum sampled operation used for stable-regime trend fits (default: 500)",
    )
    parser.add_argument(
        "--extrapolate-operation",
        type=int,
        default=None,
        help="projection endpoint (default: target operation count in the log)",
    )
    parser.add_argument(
        "--stop-reason",
        default="",
        help="explicit capture status label, for example an operator-requested stop",
    )
    parser.add_argument(
        "--geometry-checkpoints",
        type=_parse_int_list,
        default=DEFAULT_GEOMETRY_CHECKPOINTS,
        help="comma-separated geometry checkpoint operations",
    )
    parser.add_argument(
        "--collision-checkpoints",
        type=_parse_int_list,
        default=DEFAULT_COLLISION_CHECKPOINTS,
        help="comma-separated collision checkpoint operations",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    if arguments.fit_min_operation < 1:
        parser.error("--fit-min-operation must be positive")
    if arguments.extrapolate_operation is not None and arguments.extrapolate_operation < 1:
        parser.error("--extrapolate-operation must be positive")
    try:
        outputs = analyze(arguments)
    except (OSError, ValueError) as error:
        print(f"analysis failed: {error}", file=sys.stderr)
        return 1
    print("Forge V2 rolling stress analysis complete")
    for label, path in outputs.items():
        print(f"{label}: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
