#!/usr/bin/env python3
"""Tools-only proof for an unclipped Forge V2 regional publication atlas.

The exact ``Mesh64`` result of the unsplit young ``A + B`` Boolean is the
immutable authority.  The derived publication is allowed to change only its
triangulation, followed by small, link-condition edge collapses bounded to
20 micrometres.  The 64 mm grid assigns ownership; it never intersects,
clips, caps, or snaps visible geometry.

This prototype deliberately imports the pinned manifold3d 3.3.2 environment
and fixture through ``prototype_forge_v2_exact_regional_manifold``.  It emits
one compact JSON proof artifact and touches no production/runtime files.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import sys
import time
from dataclasses import dataclass
from typing import Any, Iterable, Mapping, Sequence

import prototype_forge_v2_exact_regional_manifold as exact


np = exact.np
manifold3d = exact.manifold3d

OUTPUT_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_regional_publication_atlas_prototype.json"
)

CHUNK_SIZE_METERS = 0.064
TRIANGLE_CROSS_SQUARED_FLOOR_M4 = 1.0e-16
MAX_PATCH_VERTEX_DISPLACEMENT_METERS = 2.0e-5
MAX_SAMPLED_SURFACE_DISTANCE_METERS = 2.0e-5
MAX_SYMMETRIC_DIFFERENCE_VOLUME_M3 = 5.0e-10
SAME_BOUNDS_TOLERANCE_METERS = 1.0e-12
TOPOLOGY_QUANTA_METERS = (1.0e-8, 1.0e-7)
MAX_SURFACE_SAMPLES = 4096
TARGET_PAGE_ATOMS = 96
TARGET_PAGE_TRIANGLES = 768
MAX_CLEANUP_COLLAPSES = 64


Record = tuple[int, int, Any]
PointKey = tuple[str, str, str]
EdgeKey = tuple[PointKey, PointKey]


@dataclass(frozen=True)
class Atom:
    source_id: int
    face_id: int
    records: tuple[Record, ...]
    digest: str
    owner: tuple[int, int, int]
    boundary_loop_count: int


@dataclass
class IndexedState:
    vertices: list[Any]
    triangles: list[tuple[int, int, int]]
    labels: list[tuple[int, int]]
    origins: list[tuple[tuple[float, float, float], ...]]


class GateFailure(RuntimeError):
    """A publication-atlas gate failed."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GateFailure(message)


def _sha256_json(value: Any) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=True,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("ascii")
    return hashlib.sha256(payload).hexdigest()


def _point_key(point: Sequence[float]) -> PointKey:
    return tuple(float(value).hex() for value in point)  # type: ignore[return-value]


def _numeric_point_key(point: Sequence[float]) -> tuple[float, float, float]:
    return tuple(float(value) for value in point)  # type: ignore[return-value]


def _edge_key(first: Sequence[float], second: Sequence[float]) -> EdgeKey:
    values = (_point_key(first), _point_key(second))
    return tuple(sorted(values))  # type: ignore[return-value]


def _triangle_cycle_key(record: Record) -> tuple[Any, ...]:
    source_id, face_id, points = record
    keys = [_point_key(point) for point in np.asarray(points, dtype=np.float64)]
    cycles = [tuple(keys[offset:] + keys[:offset]) for offset in range(3)]
    return (int(source_id), int(face_id), min(cycles))


def _record_sort_key(record: Record) -> tuple[Any, ...]:
    return _triangle_cycle_key(record)


def _copy_record(record: Record) -> Record:
    return (
        int(record[0]),
        int(record[1]),
        np.asarray(record[2], dtype=np.float64).copy(),
    )


def _sorted_records(records: Iterable[Record]) -> list[Record]:
    return sorted((_copy_record(record) for record in records), key=_record_sort_key)


def _records_digest(records: Sequence[Record]) -> str:
    return _sha256_json([_triangle_cycle_key(record) for record in _sorted_records(records)])


def _triangle_quality(points: Any) -> tuple[float, float, float]:
    double_quality = exact._triangle_cross_squared(points, np.float64)
    float_quality = exact._triangle_cross_squared(points, np.float32)
    return double_quality, float_quality, min(double_quality, float_quality)


def _quality_summary(records: Sequence[Record]) -> dict[str, Any]:
    double_values: list[float] = []
    float_values: list[float] = []
    bad_keys: list[tuple[Any, ...]] = []
    for record in records:
        double_quality, float_quality, weakest = _triangle_quality(record[2])
        double_values.append(double_quality)
        float_values.append(float_quality)
        if weakest <= TRIANGLE_CROSS_SQUARED_FLOOR_M4:
            bad_keys.append(_triangle_cycle_key(record))
    return {
        "triangle_count": len(records),
        "threshold_cross_squared_m4": TRIANGLE_CROSS_SQUARED_FLOOR_M4,
        "double_subthreshold_triangle_count": sum(
            value <= TRIANGLE_CROSS_SQUARED_FLOOR_M4 for value in double_values
        ),
        "float32_subthreshold_triangle_count": sum(
            value <= TRIANGLE_CROSS_SQUARED_FLOOR_M4 for value in float_values
        ),
        "minimum_double_cross_squared_m4": min(double_values, default=math.inf),
        "minimum_float32_cross_squared_m4": min(float_values, default=math.inf),
        "bad_triangle_key_digest": _sha256_json(sorted(bad_keys)),
    }


def _surface_area(records: Sequence[Record]) -> float:
    return exact._surface_area_for_records(records)


def _record_boundary(records: Sequence[Record]) -> tuple[tuple[Any, ...], ...]:
    uses: dict[EdgeKey, list[tuple[PointKey, PointKey]]] = {}
    for _source_id, _face_id, raw_points in records:
        points = np.asarray(raw_points, dtype=np.float64)
        keys = [_point_key(point) for point in points]
        for first, second in ((keys[0], keys[1]), (keys[1], keys[2]), (keys[2], keys[0])):
            edge = tuple(sorted((first, second)))  # type: ignore[assignment]
            uses.setdefault(edge, []).append((first, second))
    boundary: list[tuple[Any, ...]] = []
    for edge, directions in uses.items():
        if len(directions) == 1:
            boundary.append((edge, directions[0]))
    return tuple(sorted(boundary))


def _connected_face_atoms(records: Sequence[Record]) -> list[list[Record]]:
    """Split each provenance face into edge-connected surface atoms."""
    ordered = _sorted_records(records)
    parent = list(range(len(ordered)))

    def find(value: int) -> int:
        while parent[value] != value:
            parent[value] = parent[parent[value]]
            value = parent[value]
        return value

    def union(first: int, second: int) -> None:
        first_root = find(first)
        second_root = find(second)
        if first_root == second_root:
            return
        if first_root < second_root:
            parent[second_root] = first_root
        else:
            parent[first_root] = second_root

    face_edges: dict[tuple[int, int, EdgeKey], list[int]] = {}
    for index, (source_id, face_id, raw_points) in enumerate(ordered):
        points = np.asarray(raw_points, dtype=np.float64)
        for first, second in (
            (points[0], points[1]),
            (points[1], points[2]),
            (points[2], points[0]),
        ):
            face_edges.setdefault(
                (int(source_id), int(face_id), _edge_key(first, second)), []
            ).append(index)
    for indices in face_edges.values():
        for index in indices[1:]:
            union(indices[0], index)

    groups: dict[int, list[Record]] = {}
    for index, record in enumerate(ordered):
        groups.setdefault(find(index), []).append(record)
    return sorted(
        (_sorted_records(group) for group in groups.values()),
        key=lambda group: (
            int(group[0][0]),
            int(group[0][1]),
            _records_digest(group),
        ),
    )


def _loop_count(records: Sequence[Record]) -> int:
    try:
        loops, _normal = exact._face_boundary_loops(records)
        return len(loops)
    except Exception:
        return -1


def _zero_move_retriangulation(
    records: Sequence[Record],
) -> tuple[list[Record], dict[str, Any]]:
    """Retriangulate bad, connected provenance atoms without moving a point."""
    input_records = _sorted_records(records)
    input_point_keys = {
        _point_key(point)
        for _source, _face, points in input_records
        for point in np.asarray(points, dtype=np.float64)
    }
    input_area = _surface_area(input_records)
    atoms = _connected_face_atoms(input_records)
    output: list[Record] = []
    retriangulated = 0
    no_better_candidate = 0
    multiple_loop_skips = 0
    candidate_failures = 0
    max_atom_area_delta = 0.0

    for atom in atoms:
        input_minimum = min(_triangle_quality(record[2])[2] for record in atom)
        if input_minimum > TRIANGLE_CROSS_SQUARED_FLOOR_M4:
            output.extend(_sorted_records(atom))
            continue
        try:
            loops, normal = exact._face_boundary_loops(atom)
            if len(loops) != 1:
                multiple_loop_skips += 1
                output.extend(_sorted_records(atom))
                continue
            triangles = exact._quality_triangulate_polygon(loops[0], normal)
            source_id = int(atom[0][0])
            face_id = int(atom[0][1])
            candidate = _sorted_records(
                (source_id, face_id, np.asarray(triangle, dtype=np.float64))
                for triangle in triangles
            )
            candidate_area = _surface_area(candidate)
            input_atom_area = _surface_area(atom)
            area_delta = abs(candidate_area - input_atom_area)
            max_atom_area_delta = max(max_atom_area_delta, area_delta)
            _require(
                area_delta <= max(1.0e-15, input_atom_area * 1.0e-10),
                "zero-move retriangulation changed a provenance atom's area",
            )
            _require(
                _record_boundary(candidate) == _record_boundary(atom),
                "zero-move retriangulation changed a provenance atom boundary",
            )
            candidate_minimum = min(
                _triangle_quality(record[2])[2] for record in candidate
            )
            candidate_bad = sum(
                _triangle_quality(record[2])[2]
                <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
                for record in candidate
            )
            input_bad = sum(
                _triangle_quality(record[2])[2]
                <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
                for record in atom
            )
            if candidate_bad < input_bad or (
                candidate_bad == input_bad and candidate_minimum > input_minimum
            ):
                output.extend(candidate)
                retriangulated += 1
            else:
                output.extend(_sorted_records(atom))
                no_better_candidate += 1
        except GateFailure:
            raise
        except Exception:
            # Unsupported face-loop shapes remain exact and are handed to the
            # generic topology cleanup.  The final hard gates decide viability.
            candidate_failures += 1
            output.extend(_sorted_records(atom))

    output = _sorted_records(output)
    output_point_keys = {
        _point_key(point)
        for _source, _face, points in output
        for point in np.asarray(points, dtype=np.float64)
    }
    _require(
        output_point_keys <= input_point_keys,
        "zero-move retriangulation created a vertex",
    )
    output_area = _surface_area(output)
    _require(
        abs(output_area - input_area) <= max(1.0e-14, input_area * 1.0e-10),
        "global zero-move retriangulation changed surface area",
    )
    return output, {
        "method": "global_connected_provenance_face_loop_max_min_retriangulation",
        "scanned_atom_count": len(atoms),
        "retriangulated_atom_count": retriangulated,
        "multiple_boundary_loop_skip_count": multiple_loop_skips,
        "no_better_candidate_count": no_better_candidate,
        "unsupported_candidate_count": candidate_failures,
        "input": _quality_summary(input_records),
        "output": _quality_summary(output),
        "surface_area_absolute_delta_m2": abs(output_area - input_area),
        "maximum_atom_area_absolute_delta_m2": max_atom_area_delta,
        "vertex_coordinates_moved": False,
        "vertices_created": False,
        "authority_modified": False,
    }


def _records_to_indexed(records: Sequence[Record]) -> IndexedState:
    vertex_by_key: dict[PointKey, int] = {}
    vertices: list[Any] = []
    triangles: list[tuple[int, int, int]] = []
    labels: list[tuple[int, int]] = []
    for source_id, face_id, raw_points in _sorted_records(records):
        indices: list[int] = []
        for point in np.asarray(raw_points, dtype=np.float64):
            key = _point_key(point)
            index = vertex_by_key.get(key)
            if index is None:
                index = len(vertices)
                vertex_by_key[key] = index
                vertices.append(np.asarray(point, dtype=np.float64).copy())
            indices.append(index)
        _require(len(set(indices)) == 3, "indexed publication contains a collapsed triangle")
        triangles.append((indices[0], indices[1], indices[2]))
        labels.append((int(source_id), int(face_id)))
    origins = [
        (tuple(float(value) for value in vertex),)
        for vertex in vertices
    ]
    return IndexedState(vertices, triangles, labels, origins)


def _indexed_to_records(state: IndexedState) -> list[Record]:
    output: list[Record] = []
    for triangle, label in zip(state.triangles, state.labels):
        points = np.asarray(
            [state.vertices[int(index)] for index in triangle], dtype=np.float64
        )
        output.append((int(label[0]), int(label[1]), points))
    return _sorted_records(output)


def _indexed_adjacency(
    state: IndexedState,
) -> tuple[dict[tuple[int, int], list[int]], dict[int, set[int]]]:
    edge_triangles: dict[tuple[int, int], list[int]] = {}
    neighbors: dict[int, set[int]] = {}
    for triangle_index, triangle in enumerate(state.triangles):
        first, second, third = triangle
        for start, end in ((first, second), (second, third), (third, first)):
            edge = tuple(sorted((int(start), int(end))))
            edge_triangles.setdefault(edge, []).append(triangle_index)
            neighbors.setdefault(int(start), set()).add(int(end))
            neighbors.setdefault(int(end), set()).add(int(start))
    return edge_triangles, neighbors


def _state_bounds(state: IndexedState) -> tuple[float, ...]:
    used = sorted({index for triangle in state.triangles for index in triangle})
    values = np.asarray([state.vertices[index] for index in used], dtype=np.float64)
    return tuple(float(value) for value in np.concatenate((values.min(axis=0), values.max(axis=0))))


def _records_bounds(records: Sequence[Record]) -> tuple[float, ...]:
    points = np.concatenate(
        [np.asarray(record[2], dtype=np.float64) for record in records], axis=0
    )
    return tuple(float(value) for value in np.concatenate((points.min(axis=0), points.max(axis=0))))


def _bounds_delta(first: Sequence[float], second: Sequence[float]) -> float:
    if len(first) != len(second):
        return math.inf
    return max(abs(float(a) - float(b)) for a, b in zip(first, second))


def _state_quality(state: IndexedState) -> tuple[int, float]:
    bad_count = 0
    minimum = math.inf
    for triangle in state.triangles:
        points = np.asarray([state.vertices[index] for index in triangle])
        weakest = _triangle_quality(points)[2]
        minimum = min(minimum, weakest)
        bad_count += int(weakest <= TRIANGLE_CROSS_SQUARED_FLOOR_M4)
    return bad_count, minimum


def _active_origin_displacement(state: IndexedState) -> float:
    maximum = 0.0
    used = {index for triangle in state.triangles for index in triangle}
    for index in used:
        point = np.asarray(state.vertices[index], dtype=np.float64)
        for origin in state.origins[index]:
            maximum = max(
                maximum,
                float(np.linalg.norm(point - np.asarray(origin, dtype=np.float64))),
            )
    return maximum


def _copy_state(state: IndexedState) -> IndexedState:
    return IndexedState(
        [np.asarray(vertex, dtype=np.float64).copy() for vertex in state.vertices],
        list(state.triangles),
        list(state.labels),
        list(state.origins),
    )


def _topology_for_records(records: Sequence[Record], quantum: float) -> dict[str, Any]:
    edge_uses: dict[tuple[Any, Any], list[tuple[int, PointKey, PointKey]]] = {}
    vertex_keys: set[PointKey] = set()
    collapsed_triangles = 0
    for triangle_index, record in enumerate(_sorted_records(records)):
        raw_points = np.asarray(record[2], dtype=np.float64)
        keys = [
            tuple(str(value) for value in exact._canonical_point(point, quantum))
            for point in raw_points
        ]
        vertex_keys.update(keys)  # type: ignore[arg-type]
        if len(set(keys)) != 3:
            collapsed_triangles += 1
        for first, second in ((keys[0], keys[1]), (keys[1], keys[2]), (keys[2], keys[0])):
            edge = tuple(sorted((first, second)))
            edge_uses.setdefault(edge, []).append(
                (triangle_index, first, second)  # type: ignore[arg-type]
            )

    boundary_edges = sum(len(uses) == 1 for uses in edge_uses.values())
    nonmanifold_edges = sum(len(uses) != 2 for uses in edge_uses.values())
    directed_mismatches = 0
    adjacency: dict[int, set[int]] = {
        index: set() for index in range(len(records))
    }
    for uses in edge_uses.values():
        if len(uses) == 2:
            first, second = uses
            adjacency[first[0]].add(second[0])
            adjacency[second[0]].add(first[0])
            if not (first[1] == second[2] and first[2] == second[1]):
                directed_mismatches += 1

    remaining = set(adjacency)
    component_count = 0
    while remaining:
        component_count += 1
        pending = [min(remaining)]
        remaining.remove(pending[0])
        while pending:
            current = pending.pop()
            for neighbor in adjacency[current]:
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    pending.append(neighbor)

    chi = len(vertex_keys) - len(edge_uses) + len(records)
    genus: int | None = None
    if (
        component_count == 1
        and boundary_edges == 0
        and nonmanifold_edges == 0
        and directed_mismatches == 0
    ):
        genus_value = (2 - chi) / 2
        if abs(genus_value - round(genus_value)) <= 1.0e-9:
            genus = int(round(genus_value))
    return {
        "quantization_meters": quantum,
        "vertex_count": len(vertex_keys),
        "edge_count": len(edge_uses),
        "triangle_count": len(records),
        "collapsed_triangle_count": collapsed_triangles,
        "boundary_edge_count": boundary_edges,
        "nonmanifold_edge_count": nonmanifold_edges,
        "directed_mismatch_edge_count": directed_mismatches,
        "component_count": component_count,
        "euler_characteristic": chi,
        "genus": genus,
    }


def _topology_passes(topology: Mapping[str, Any]) -> bool:
    return (
        int(topology["collapsed_triangle_count"]) == 0
        and int(topology["boundary_edge_count"]) == 0
        and int(topology["nonmanifold_edge_count"]) == 0
        and int(topology["directed_mismatch_edge_count"]) == 0
        and int(topology["component_count"]) == 1
        and topology["genus"] is not None
    )


def _collapse_candidate(
    state: IndexedState,
    edge: tuple[int, int],
    authority_bounds: Sequence[float],
) -> tuple[IndexedState, dict[str, Any]] | None:
    first, second = edge
    edge_triangles, neighbors = _indexed_adjacency(state)
    incident = edge_triangles.get(tuple(sorted(edge)), [])
    if len(incident) != 2:
        return None
    opposites = {
        index
        for triangle_index in incident
        for index in state.triangles[triangle_index]
        if index not in edge
    }
    common_neighbors = (
        (neighbors.get(first, set()) - {second})
        & (neighbors.get(second, set()) - {first})
    )
    if len(opposites) != 2 or common_neighbors != opposites:
        return None

    first_point = np.asarray(state.vertices[first], dtype=np.float64)
    second_point = np.asarray(state.vertices[second], dtype=np.float64)
    edge_length = float(np.linalg.norm(second_point - first_point))
    if edge_length > 2.0 * MAX_PATCH_VERTEX_DISPLACEMENT_METERS + 1.0e-15:
        return None
    target = (first_point + second_point) * 0.5
    merged_origins = tuple(sorted(set(state.origins[first] + state.origins[second])))
    maximum_merged_displacement = max(
        float(np.linalg.norm(target - np.asarray(origin, dtype=np.float64)))
        for origin in merged_origins
    )
    if maximum_merged_displacement > MAX_PATCH_VERTEX_DISPLACEMENT_METERS + 1.0e-15:
        return None

    target_key = _point_key(target)
    active_vertices = {index for triangle in state.triangles for index in triangle}
    if any(
        index not in edge and _point_key(state.vertices[index]) == target_key
        for index in active_vertices
    ):
        return None

    candidate = _copy_state(state)
    candidate.vertices[first] = target.copy()
    candidate.origins[first] = merged_origins
    output_triangles: list[tuple[int, int, int]] = []
    output_labels: list[tuple[int, int]] = []
    removed_labels: list[tuple[int, int]] = []
    changed_triangle_count = 0
    removed_triangle_count = 0
    for triangle, label in zip(state.triangles, state.labels):
        mapped = tuple(first if index == second else index for index in triangle)
        if len(set(mapped)) != 3:
            if first in triangle and second in triangle:
                removed_triangle_count += 1
                removed_labels.append(label)
                continue
            return None
        if first in triangle or second in triangle:
            changed_triangle_count += 1
            old_points = np.asarray([state.vertices[index] for index in triangle])
            new_points = np.asarray(
                [target if index in edge else state.vertices[index] for index in triangle]
            )
            old_normal = np.cross(
                old_points[1] - old_points[0], old_points[2] - old_points[0]
            )
            new_normal = np.cross(
                new_points[1] - new_points[0], new_points[2] - new_points[0]
            )
            if float(np.dot(old_normal, new_normal)) <= 0.0:
                return None
            if _triangle_quality(new_points)[2] <= 1.0e-24:
                return None
        output_triangles.append(mapped)
        output_labels.append(label)
    if removed_triangle_count != 2:
        return None
    candidate.triangles = output_triangles
    candidate.labels = output_labels
    candidate.vertices[second] = target.copy()
    candidate.origins[second] = ()

    if _bounds_delta(_state_bounds(candidate), authority_bounds) > SAME_BOUNDS_TOLERANCE_METERS:
        return None
    if _active_origin_displacement(candidate) > MAX_PATCH_VERTEX_DISPLACEMENT_METERS + 1.0e-15:
        return None

    candidate_records = _indexed_to_records(candidate)
    for quantum in TOPOLOGY_QUANTA_METERS:
        if not _topology_passes(_topology_for_records(candidate_records, quantum)):
            return None
    return candidate, {
        "edge_length_m": edge_length,
        "maximum_merged_origin_displacement_m": maximum_merged_displacement,
        "changed_neighbor_triangle_count": changed_triangle_count,
        "removed_triangle_count": removed_triangle_count,
        "removed_paired_provenance_faces": [
            [int(source_id), int(face_id)]
            for source_id, face_id in sorted(set(removed_labels))
        ],
        "edge_digest": _sha256_json(
            sorted((_point_key(first_point), _point_key(second_point)))
        ),
    }


def _bounded_patch_cleanup(
    records: Sequence[Record],
    authority_bounds: Sequence[float],
) -> tuple[list[Record], dict[str, Any]]:
    """Collapse only legal short edges adjacent to residual bad triangles."""
    state = _records_to_indexed(records)
    input_quality = _quality_summary(_indexed_to_records(state))
    collapse_rows: list[dict[str, Any]] = []

    for collapse_index in range(MAX_CLEANUP_COLLAPSES):
        bad_before, minimum_before = _state_quality(state)
        if bad_before == 0:
            break
        candidate_edges: set[tuple[int, int]] = set()
        for triangle in state.triangles:
            points = np.asarray([state.vertices[index] for index in triangle])
            if _triangle_quality(points)[2] > TRIANGLE_CROSS_SQUARED_FLOOR_M4:
                continue
            for first, second in (
                (triangle[0], triangle[1]),
                (triangle[1], triangle[2]),
                (triangle[2], triangle[0]),
            ):
                candidate_edges.add(tuple(sorted((int(first), int(second)))))

        accepted: list[tuple[tuple[Any, ...], IndexedState, dict[str, Any]]] = []
        for edge in sorted(
            candidate_edges,
            key=lambda value: tuple(
                sorted((_point_key(state.vertices[value[0]]), _point_key(state.vertices[value[1]])))
            ),
        ):
            result = _collapse_candidate(state, edge, authority_bounds)
            if result is None:
                continue
            candidate_state, diagnostics = result
            bad_after, minimum_after = _state_quality(candidate_state)
            if bad_after >= bad_before:
                continue
            score = (
                bad_after,
                float(diagnostics["maximum_merged_origin_displacement_m"]),
                -minimum_after,
                str(diagnostics["edge_digest"]),
            )
            diagnostics.update(
                {
                    "collapse_index": collapse_index,
                    "bad_triangle_count_before": bad_before,
                    "bad_triangle_count_after": bad_after,
                    "minimum_quality_before_m4": minimum_before,
                    "minimum_quality_after_m4": minimum_after,
                }
            )
            accepted.append((score, candidate_state, diagnostics))
        if not accepted:
            break
        accepted.sort(key=lambda item: item[0])
        _score, state, row = accepted[0]
        collapse_rows.append(row)

    output = _indexed_to_records(state)
    output_quality = _quality_summary(output)
    unresolved = max(
        int(output_quality["double_subthreshold_triangle_count"]),
        int(output_quality["float32_subthreshold_triangle_count"]),
    )
    if unresolved:
        bad_examples: list[dict[str, Any]] = []
        for record in output:
            double_quality, float_quality, weakest = _triangle_quality(record[2])
            if weakest > TRIANGLE_CROSS_SQUARED_FLOOR_M4:
                continue
            points = np.asarray(record[2], dtype=np.float64)
            lengths = sorted(
                float(np.linalg.norm(points[end] - points[start]))
                for start, end in ((0, 1), (1, 2), (2, 0))
            )
            bad_examples.append(
                {
                    "source_id": int(record[0]),
                    "face_id": int(record[1]),
                    "double_cross_squared_m4": double_quality,
                    "float32_cross_squared_m4": float_quality,
                    "shortest_edge_m": lengths[0],
                    "longest_edge_m": lengths[-1],
                    "triangle_digest": _sha256_json(_triangle_cycle_key(record)),
                }
            )
            if len(bad_examples) >= 8:
                break
        raise GateFailure(
            "bounded topology cleanup left %d subthreshold triangles; residual=%s"
            % (unresolved, json.dumps(bad_examples, separators=(",", ":")))
        )

    return output, {
        "method": "deterministic_residual_patch_midpoint_edge_collapse",
        "topology_guard": "closed_two_triangle_edge_link_condition_plus_1e-8_and_1e-7_audits",
        "candidate_scope": "edges_of_residual_subthreshold_triangles_only",
        "collapse_count": len(collapse_rows),
        "removed_triangle_count": sum(
            int(row["removed_triangle_count"]) for row in collapse_rows
        ),
        "removed_paired_provenance_faces": sorted(
            {
                tuple(face)
                for row in collapse_rows
                for face in row["removed_paired_provenance_faces"]
            }
        ),
        "maximum_allowed_vertex_displacement_m": MAX_PATCH_VERTEX_DISPLACEMENT_METERS,
        "maximum_actual_cumulative_vertex_displacement_m": _active_origin_displacement(state),
        "input": input_quality,
        "output": output_quality,
        "collapses": collapse_rows,
        "authority_modified": False,
    }


def _make_publication_solid(records: Sequence[Record]) -> tuple[Any, dict[str, Any]]:
    ordered = _sorted_records(records)
    vertex_by_key: dict[PointKey, int] = {}
    vertices: list[Any] = []
    triangles: list[list[int]] = []
    face_ids: list[int] = []
    run_indices: list[int] = [0]
    run_ids: list[int] = []
    current_source: int | None = None
    for source_id, face_id, raw_points in ordered:
        if current_source != source_id:
            if current_source is not None:
                run_indices.append(len(triangles) * 3)
            current_source = int(source_id)
            run_ids.append(int(source_id))
        triangle: list[int] = []
        for point in np.asarray(raw_points, dtype=np.float64):
            key = _point_key(point)
            index = vertex_by_key.get(key)
            if index is None:
                index = len(vertices)
                vertex_by_key[key] = index
                vertices.append(np.asarray(point, dtype=np.float64).copy())
            triangle.append(index)
        _require(len(set(triangle)) == 3, "publication Mesh64 contains a collapsed triangle")
        triangles.append(triangle)
        face_ids.append(int(face_id))
    run_indices.append(len(triangles) * 3)
    mesh = manifold3d.Mesh64(
        np.ascontiguousarray(np.asarray(vertices, dtype=np.float64)),
        np.ascontiguousarray(np.asarray(triangles, dtype=np.uint64)),
        run_index=np.asarray(run_indices, dtype=np.uint64),
        run_original_id=np.asarray(run_ids, dtype=np.uint32),
        face_id=np.asarray(face_ids, dtype=np.uint64),
        tolerance=0.0,
    )
    solid = manifold3d.Manifold(mesh)
    merge_attempted = False
    merge_changed = False
    if not exact._is_ok(solid):
        merge_attempted = True
        merge_changed = bool(mesh.merge())
        solid = manifold3d.Manifold(mesh)
    _require(
        exact._is_ok(solid),
        f"combined owner pages are not a valid Mesh64 manifold: {exact._status_name(solid)}",
    )
    _require(not solid.is_empty(), "combined owner pages produced an empty solid")
    _require(len(solid.decompose()) == 1, "combined owner pages are not one component")
    _require(
        int(solid.num_tri()) == len(ordered),
        "Mesh64 construction changed the published triangle count",
    )
    return solid, {
        "input_triangle_count": len(ordered),
        "input_vertex_count": len(vertices),
        "mesh_merge_attempted": merge_attempted,
        "mesh_merge_changed": merge_changed,
        "status": exact._status_name(solid),
        "component_count": len(solid.decompose()),
        "component_genera": sorted(int(component.genus()) for component in solid.decompose()),
    }


def _atom_owner(records: Sequence[Record]) -> tuple[int, int, int]:
    weighted = np.zeros(3, dtype=np.float64)
    total_area = 0.0
    for record in records:
        points = np.asarray(record[2], dtype=np.float64)
        area = 0.5 * float(
            np.linalg.norm(np.cross(points[1] - points[0], points[2] - points[0]))
        )
        weighted += points.mean(axis=0) * area
        total_area += area
    if total_area <= 0.0:
        points = np.concatenate([np.asarray(record[2]) for record in records], axis=0)
        center = points.mean(axis=0)
    else:
        center = weighted / total_area
    return tuple(
        int(math.floor(float(value) / CHUNK_SIZE_METERS)) for value in center
    )  # type: ignore[return-value]


def _make_atoms(records: Sequence[Record]) -> list[Atom]:
    atoms: list[Atom] = []
    for group in _connected_face_atoms(records):
        digest = _records_digest(group)
        atoms.append(
            Atom(
                source_id=int(group[0][0]),
                face_id=int(group[0][1]),
                records=tuple(_sorted_records(group)),
                digest=digest,
                owner=_atom_owner(group),
                boundary_loop_count=_loop_count(group),
            )
        )
    return sorted(
        atoms,
        key=lambda atom: (
            atom.owner,
            atom.source_id,
            atom.face_id,
            atom.digest,
        ),
    )


def _atom_crosses_owner_plane(atom: Atom) -> bool:
    minimum = np.asarray(atom.owner, dtype=np.float64) * CHUNK_SIZE_METERS
    maximum = minimum + CHUNK_SIZE_METERS
    points = np.concatenate(
        [np.asarray(record[2], dtype=np.float64) for record in atom.records], axis=0
    )
    return bool(np.any(points < minimum) or np.any(points >= maximum))


def _mesh64_payload(
    records: Sequence[Record],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    triangle_atom_indices: Sequence[int] | None = None,
) -> dict[str, Any]:
    """Build deterministic, directly serializable Mesh64-compatible arrays."""
    _require(bool(records), "cannot serialize an empty publication payload")
    if triangle_atom_indices is not None:
        _require(
            len(triangle_atom_indices) == len(records),
            "triangle/atom relation length differs from triangle count",
        )
    vertex_by_key: dict[PointKey, int] = {}
    vertices: list[list[float]] = []
    triangles: list[list[int]] = []
    face_ids: list[int] = []
    material_indices: list[int] = []
    surface_indices: list[int] = []
    run_indices: list[int] = [0]
    run_original_ids: list[int] = []
    current_source: int | None = None
    for source_id, face_id, raw_points in records:
        source_id = int(source_id)
        face_id = int(face_id)
        if current_source != source_id:
            if current_source is not None:
                run_indices.append(len(triangles) * 3)
            run_original_ids.append(source_id)
            current_source = source_id
        indices: list[int] = []
        for point in np.asarray(raw_points, dtype=np.float64):
            key = _point_key(point)
            index = vertex_by_key.get(key)
            if index is None:
                index = len(vertices)
                vertex_by_key[key] = index
                vertices.append([float(value) for value in point])
            indices.append(index)
        _require(len(set(indices)) == 3, "serialized page contains a collapsed triangle")
        triangles.append(indices)
        face_ids.append(face_id)
        _require(
            (source_id, face_id) in property_lookup,
            f"missing material provenance for source face {(source_id, face_id)}",
        )
        material_index, surface_index = property_lookup[(source_id, face_id)]
        material_indices.append(int(material_index))
        surface_indices.append(int(surface_index))
    run_indices.append(len(triangles) * 3)
    payload: dict[str, Any] = {
        "vert_properties": vertices,
        "tri_verts": triangles,
        "run_index": run_indices,
        "run_original_id": run_original_ids,
        "face_id": face_ids,
        "material_index": material_indices,
        "surface_index": surface_indices,
    }
    if triangle_atom_indices is not None:
        payload["triangle_atom_index"] = [
            int(value) for value in triangle_atom_indices
        ]
    return payload


def _records_from_mesh64_payload(
    payload: Mapping[str, Any],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
) -> tuple[list[Record], list[int]]:
    """Strictly deserialize the exact page arrays that an external consumer sees."""
    vertices = np.asarray(payload.get("vert_properties", []), dtype=np.float64)
    triangles = np.asarray(payload.get("tri_verts", []), dtype=np.int64)
    run_indices = [int(value) for value in payload.get("run_index", [])]
    run_original_ids = [int(value) for value in payload.get("run_original_id", [])]
    face_ids = [int(value) for value in payload.get("face_id", [])]
    material_indices = [int(value) for value in payload.get("material_index", [])]
    surface_indices = [int(value) for value in payload.get("surface_index", [])]
    atom_indices = [int(value) for value in payload.get("triangle_atom_index", [])]
    _require(
        vertices.ndim == 2 and vertices.shape[1:] == (3,),
        "emitted page vert_properties must be Nx3",
    )
    _require(
        triangles.ndim == 2 and triangles.shape[1:] == (3,),
        "emitted page tri_verts must be Nx3",
    )
    _require(bool(np.isfinite(vertices).all()), "emitted page has a non-finite vertex")
    _require(len(vertices) > 0 and len(triangles) > 0, "emitted page mesh is empty")
    _require(
        int(triangles.min()) >= 0 and int(triangles.max()) < len(vertices),
        "emitted page has an out-of-range triangle index",
    )
    _require(
        len(face_ids)
        == len(material_indices)
        == len(surface_indices)
        == len(atom_indices)
        == len(triangles),
        "emitted page triangle provenance arrays have inconsistent lengths",
    )
    _require(
        len(run_indices) == len(run_original_ids) + 1,
        "emitted page run relation has inconsistent lengths",
    )
    _require(
        bool(run_indices)
        and run_indices[0] == 0
        and run_indices[-1] == len(triangles) * 3
        and all(value % 3 == 0 for value in run_indices)
        and all(first < second for first, second in zip(run_indices, run_indices[1:])),
        "emitted page run_index is malformed",
    )
    source_ids: list[int] = []
    for run_index, source_id in enumerate(run_original_ids):
        first_triangle = run_indices[run_index] // 3
        last_triangle = run_indices[run_index + 1] // 3
        source_ids.extend([source_id] * (last_triangle - first_triangle))
    _require(len(source_ids) == len(triangles), "emitted page run relation is incomplete")

    records: list[Record] = []
    for index, triangle in enumerate(triangles):
        source_face = (int(source_ids[index]), int(face_ids[index]))
        _require(
            source_face in property_lookup,
            f"emitted page contains unknown provenance {source_face}",
        )
        _require(
            property_lookup[source_face]
            == (int(material_indices[index]), int(surface_indices[index])),
            f"emitted page material provenance differs for {source_face}",
        )
        records.append(
            (
                source_face[0],
                source_face[1],
                vertices[triangle].copy(),
            )
        )
    return records, atom_indices


def _atom_payload_hash(
    records: Sequence[Record],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
) -> str:
    return _sha256_json(
        {
            "schema": "forge_v2_publication_atom_mesh64_v1",
            "mesh64": _mesh64_payload(_sorted_records(records), property_lookup),
        }
    )


def _page_payload_hash(page: Mapping[str, Any]) -> str:
    return _sha256_json(
        {key: value for key, value in page.items() if key != "page_sha256"}
    )


def _roundtrip_owner_pages(
    pages: Sequence[Mapping[str, Any]],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    expected_records: Sequence[Record],
    expected_atom_hashes: Sequence[str],
) -> tuple[list[dict[str, Any]], list[Record], dict[str, Any]]:
    """JSON-roundtrip pages, then reconstruct and audit their exact arrays."""
    serialized = json.dumps(
        list(pages),
        ensure_ascii=True,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    decoded = json.loads(serialized)
    _require(isinstance(decoded, list) and bool(decoded), "page roundtrip is empty")
    combined_records: list[Record] = []
    decoded_atom_hashes: list[str] = []
    page_hashes: list[str] = []
    for page in decoded:
        _require(isinstance(page, dict), "decoded publication page is not an object")
        expected_page_hash = str(page.get("page_sha256", ""))
        calculated_page_hash = _page_payload_hash(page)
        _require(
            calculated_page_hash == expected_page_hash,
            f"decoded page exact-array hash differs: {page.get('page_id')}",
        )
        page_hashes.append(calculated_page_hash)
        records, atom_indices = _records_from_mesh64_payload(
            page.get("mesh64", {}), property_lookup
        )
        atom_table = page.get("atoms", [])
        _require(isinstance(atom_table, list), "decoded page atom table is malformed")
        _require(
            len(atom_table) == int(page.get("atom_count", -1)),
            "decoded page atom count differs from its atom table",
        )
        _require(
            len(records) == int(page.get("triangle_count", -1)),
            "decoded page triangle count differs from its arrays",
        )
        _require(
            set(atom_indices) == set(range(len(atom_table))),
            "decoded page atom relation is incomplete or out of range",
        )
        for atom_index, atom_entry in enumerate(atom_table):
            atom_records = [
                record
                for record, relation in zip(records, atom_indices)
                if relation == atom_index
            ]
            _require(
                len(atom_records) == int(atom_entry.get("triangle_count", -1)),
                "decoded atom triangle count differs from its relation",
            )
            atom_labels = {(int(record[0]), int(record[1])) for record in atom_records}
            _require(
                atom_labels
                == {
                    (
                        int(atom_entry.get("source_original_id", -1)),
                        int(atom_entry.get("source_face_id", -1)),
                    )
                },
                "decoded atom table provenance differs from its triangles",
            )
            calculated_atom_hash = _atom_payload_hash(atom_records, property_lookup)
            _require(
                calculated_atom_hash == str(atom_entry.get("atom_sha256", "")),
                "decoded atom exact-array hash differs",
            )
            decoded_atom_hashes.append(calculated_atom_hash)
        combined_records.extend(records)

    expected_geometry_digest = _records_digest(expected_records)
    decoded_geometry_digest = _records_digest(combined_records)
    _require(
        decoded_geometry_digest == expected_geometry_digest,
        "deserialized page arrays changed, lost, or duplicated visible geometry",
    )
    _require(
        sorted(decoded_atom_hashes) == sorted(str(value) for value in expected_atom_hashes),
        "deserialized pages changed, split, lost, or duplicated a whole atom",
    )
    return decoded, combined_records, {
        "json_encoded_byte_count": len(serialized.encode("utf-8")),
        "page_exact_array_hashes_verified": True,
        "atom_exact_array_hashes_verified": True,
        "whole_atom_hash_multiset_matches": True,
        "combined_geometry_matches_pre_emission": True,
        "combined_deserialized_geometry_sha256": decoded_geometry_digest,
        "page_hashes": page_hashes,
        "atom_hashes": decoded_atom_hashes,
    }


def _make_owner_pages(
    records: Sequence[Record],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
) -> tuple[list[dict[str, Any]], list[Record], dict[str, Any]]:
    """Assign whole atoms, emit exact arrays, then consume their JSON roundtrip."""
    atoms = _make_atoms(records)
    maximum_atom_triangles = max((len(atom.records) for atom in atoms), default=0)
    effective_triangle_bound = max(TARGET_PAGE_TRIANGLES, maximum_atom_triangles)
    by_owner: dict[tuple[int, int, int], list[Atom]] = {}
    for atom in atoms:
        by_owner.setdefault(atom.owner, []).append(atom)

    pages: list[dict[str, Any]] = []
    assigned_atom_hashes: list[str] = []
    for owner in sorted(by_owner):
        shard_atoms: list[Atom] = []
        shard_triangles = 0
        shard_index = 0

        def flush() -> None:
            nonlocal shard_atoms, shard_triangles, shard_index
            if not shard_atoms:
                return
            page_id = "%d:%d:%d:%d" % (*owner, shard_index)
            records_here: list[Record] = []
            triangle_atom_indices: list[int] = []
            atom_table: list[dict[str, Any]] = []
            atom_hashes: list[str] = []
            for atom_index, atom in enumerate(shard_atoms):
                atom_records = _sorted_records(atom.records)
                atom_hash = _atom_payload_hash(atom_records, property_lookup)
                atom_hashes.append(atom_hash)
                atom_table.append(
                    {
                        "atom_index": atom_index,
                        "source_original_id": atom.source_id,
                        "source_face_id": atom.face_id,
                        "triangle_count": len(atom_records),
                        "atom_sha256": atom_hash,
                    }
                )
                records_here.extend(atom_records)
                triangle_atom_indices.extend([atom_index] * len(atom_records))
            page: dict[str, Any] = {
                "schema": "forge_v2_organic_publication_owner_page",
                "schema_version": 1,
                "page_id": page_id,
                "owner_chunk_coordinate": list(owner),
                "coordinate_units": "meters",
                "position_encoding": (
                    "JSON IEEE-754 binary64 values; identical arrays are independently float32-gated"
                ),
                "atom_count": len(shard_atoms),
                "triangle_count": len(records_here),
                "atoms": atom_table,
                "mesh64": _mesh64_payload(
                    records_here, property_lookup, triangle_atom_indices
                ),
            }
            page["page_sha256"] = _page_payload_hash(page)
            pages.append(page)
            assigned_atom_hashes.extend(atom_hashes)
            shard_atoms = []
            shard_triangles = 0
            shard_index += 1

        for atom in sorted(
            by_owner[owner], key=lambda value: (value.source_id, value.face_id, value.digest)
        ):
            would_overflow = bool(shard_atoms) and (
                len(shard_atoms) + 1 > TARGET_PAGE_ATOMS
                or shard_triangles + len(atom.records) > effective_triangle_bound
            )
            if would_overflow:
                flush()
            shard_atoms.append(atom)
            shard_triangles += len(atom.records)
        flush()

    pages.sort(key=lambda page: page["page_id"])
    source_digest = _records_digest(records)
    expected_atom_hashes = sorted(
        _atom_payload_hash(atom.records, property_lookup) for atom in atoms
    )
    _require(
        sorted(assigned_atom_hashes) == expected_atom_hashes,
        "owner-page assignment split, lost, or duplicated an atom",
    )
    _require(
        all(int(page["atom_count"]) <= TARGET_PAGE_ATOMS for page in pages),
        "owner page exceeded its atom bound",
    )
    _require(
        all(int(page["triangle_count"]) <= effective_triangle_bound for page in pages),
        "owner page exceeded its triangle bound",
    )
    decoded_pages, emitted_records, roundtrip = _roundtrip_owner_pages(
        pages, property_lookup, records, expected_atom_hashes
    )
    atom_hashes = list(roundtrip["atom_hashes"])
    page_hashes = [str(page["page_sha256"]) for page in pages]
    return decoded_pages, emitted_records, {
        "ownership_method": "area_centroid_half_open_64mm_cell_then_capacity_shard",
        "geometry_law": "whole connected provenance atoms assigned once; no page-plane intersection",
        "page_count": len(pages),
        "atom_count": len(atoms),
        "target_max_atoms_per_page": TARGET_PAGE_ATOMS,
        "effective_max_triangles_per_page": effective_triangle_bound,
        "maximum_atoms_in_page": max((int(page["atom_count"]) for page in pages), default=0),
        "maximum_triangles_in_page": max(
            (int(page["triangle_count"]) for page in pages), default=0
        ),
        "maximum_triangles_in_atom": maximum_atom_triangles,
        "atoms_crossing_owner_cell_plane_count": sum(
            _atom_crosses_owner_plane(atom) for atom in atoms
        ),
        "multiple_boundary_loop_atom_count": sum(
            atom.boundary_loop_count > 1 for atom in atoms
        ),
        "unresolved_boundary_loop_atom_count": sum(
            atom.boundary_loop_count < 0 for atom in atoms
        ),
        "geometric_clip_operation_count": 0,
        "paging_vertices_created": False,
        "paging_vertices_moved": False,
        "emitted_payload_kind": "json_roundtripped_mesh64_compatible_arrays",
        "payload_hash_canonicalization": (
            "SHA-256 of UTF-8 JSON with sorted object keys, compact separators, exact array order"
        ),
        "roundtrip": roundtrip,
        "combined_geometry_sha256": source_digest,
        "atom_hashes": atom_hashes,
        "atom_hash_manifest_sha256": _sha256_json(atom_hashes),
        "page_hashes": page_hashes,
        "page_hash_manifest_sha256": _sha256_json(page_hashes),
    }


def _surface_samples(records: Sequence[Record], maximum: int) -> Any:
    ordered = _sorted_records(records)
    triangles = np.asarray([record[2] for record in ordered], dtype=np.float64)
    points = np.concatenate(
        (
            triangles.reshape((-1, 3)),
            triangles.mean(axis=1),
            (triangles[:, 0] + triangles[:, 1]) * 0.5,
            (triangles[:, 1] + triangles[:, 2]) * 0.5,
            (triangles[:, 2] + triangles[:, 0]) * 0.5,
        ),
        axis=0,
    )
    if len(points) > maximum:
        indices = np.linspace(0, len(points) - 1, maximum, dtype=np.int64)
        points = points[indices]
    return points


def _directed_surface_distance(
    source: Sequence[Record], target: Sequence[Record]
) -> float:
    target_vertices = np.concatenate(
        [np.asarray(record[2], dtype=np.float64) for record in _sorted_records(target)],
        axis=0,
    )
    target_triangles = np.arange(len(target_vertices), dtype=np.uint64).reshape((-1, 3))
    maximum = 0.0
    for point in _surface_samples(source, MAX_SURFACE_SAMPLES):
        maximum = max(
            maximum,
            exact._point_mesh_distance(point, target_vertices, target_triangles),
        )
    return maximum


def _surface_and_volume_comparison(
    publication_solid: Any,
    authority_solid: Any,
    publication_records: Sequence[Record],
    authority_records: Sequence[Record],
) -> dict[str, Any]:
    publication_minus_authority = publication_solid - authority_solid
    authority_minus_publication = authority_solid - publication_solid
    _require(
        exact._is_ok(publication_minus_authority)
        and exact._is_ok(authority_minus_publication),
        "symmetric-difference Boolean failed",
    )
    symmetric_difference = float(
        publication_minus_authority.volume() + authority_minus_publication.volume()
    )
    forward = _directed_surface_distance(publication_records, authority_records)
    reverse = _directed_surface_distance(authority_records, publication_records)
    return {
        "sample_count_per_direction_maximum": MAX_SURFACE_SAMPLES,
        "sampled_publication_to_authority_m": forward,
        "sampled_authority_to_publication_m": reverse,
        "sampled_bidirectional_maximum_m": max(forward, reverse),
        "sampled_distance_limit_m": MAX_SAMPLED_SURFACE_DISTANCE_METERS,
        "symmetric_difference_volume_m3": symmetric_difference,
        "symmetric_difference_volume_limit_m3": MAX_SYMMETRIC_DIFFERENCE_VOLUME_M3,
        "volume_absolute_delta_m3": abs(
            float(publication_solid.volume()) - float(authority_solid.volume())
        ),
        "sampling_note": (
            "deterministic vertices, centroids, and edge midpoints against all target triangles"
        ),
    }


def _provenance_summary(
    records: Sequence[Record], source_face_counts: Mapping[int, int]
) -> dict[str, Any]:
    invalid_sources = [record[0] for record in records if record[0] not in source_face_counts]
    invalid_faces = [
        (record[0], record[1])
        for record in records
        if record[0] in source_face_counts
        and not 0 <= int(record[1]) < int(source_face_counts[record[0]])
    ]
    counts: dict[str, int] = {}
    for source_id, _face_id, _points in records:
        counts[str(source_id)] = counts.get(str(source_id), 0) + 1
    return {
        "triangle_counts_by_original_id": counts,
        "invalid_source_triangle_count": len(invalid_sources),
        "invalid_face_id_triangle_count": len(invalid_faces),
        "compiler_cap_triangle_count": len(invalid_sources),
        "passed": not invalid_sources and not invalid_faces,
    }


def _source_property_lookup(
    fixture: Mapping[str, Any],
    packet_sources: Mapping[str, int],
) -> dict[tuple[int, int], tuple[int, int]]:
    """Map exact Boolean face provenance back to fixture material surfaces."""
    lookup: dict[tuple[int, int], tuple[int, int]] = {}
    for packet_name, source_id in packet_sources.items():
        triangles = fixture["packets"][packet_name].get("triangles", [])
        for face_id, triangle in enumerate(triangles):
            _require(isinstance(triangle, dict), "fixture triangle provenance is missing")
            material_index = int(triangle.get("material_index", -1))
            surface_index = int(triangle.get("surface_index", -1))
            _require(
                material_index >= 0 and surface_index >= 0,
                f"fixture material provenance is invalid for {packet_name} face {face_id}",
            )
            lookup[(int(source_id), face_id)] = (material_index, surface_index)
    return lookup


def _build_publication(
    input_records: Sequence[Record],
    authority_bounds: Sequence[float],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
) -> tuple[list[Record], list[Record], list[dict[str, Any]], dict[str, Any]]:
    zero_move_records, retriangulation = _zero_move_retriangulation(input_records)
    for quantum in TOPOLOGY_QUANTA_METERS:
        topology = _topology_for_records(zero_move_records, quantum)
        _require(
            _topology_passes(topology),
            f"zero-move global retriangulation broke topology at {quantum:g} m",
        )
    cleaned_records, cleanup = _bounded_patch_cleanup(
        zero_move_records, authority_bounds
    )
    pages, emitted_records, atlas = _make_owner_pages(
        cleaned_records, property_lookup
    )
    return cleaned_records, emitted_records, pages, {
        "zero_move_retriangulation": retriangulation,
        "bounded_patch_cleanup": cleanup,
        "atlas": atlas,
    }


def _run() -> dict[str, Any]:
    started = time.perf_counter_ns()
    fixture, fixture_sha256 = exact._load_fixture()
    fixture_transport = exact._validate_fixture_hashes(fixture)
    first_original_id = int(manifold3d.Manifold.reserve_ids(2))
    stroke_a = exact._make_packet_solid(
        "stroke_a", fixture["packets"]["stroke_a"], first_original_id
    )
    stroke_b = exact._make_packet_solid(
        "stroke_b", fixture["packets"]["stroke_b"], first_original_id + 1
    )
    organic_ids = {stroke_a.original_id, stroke_b.original_id}
    source_face_counts = {
        stroke_a.original_id: stroke_a.triangle_count,
        stroke_b.original_id: stroke_b.triangle_count,
    }
    property_lookup = _source_property_lookup(
        fixture,
        {
            "stroke_a": stroke_a.original_id,
            "stroke_b": stroke_b.original_id,
        },
    )

    # This single unsplit Boolean is the immutable exact Mesh64 authority.
    authority = stroke_a.manifold + stroke_b.manifold
    _require(exact._is_ok(authority), "unsplit young A+B Boolean failed")
    _require(not authority.is_empty(), "unsplit young A+B Boolean is empty")
    _require(len(authority.decompose()) == 1, "unsplit young A+B Boolean is disconnected")
    authority_digest_before = exact._mesh_digest(authority)
    authority_vertices, authority_triangles, source_ids, face_ids = exact._triangle_records(
        authority
    )
    authority_vertices_snapshot = authority_vertices.copy()
    authority_triangles_snapshot = authority_triangles.copy()
    source_ids_snapshot = list(source_ids)
    face_ids_snapshot = list(face_ids)
    authority_records = _sorted_records(
        (
            int(source_ids[index]),
            int(face_ids[index]),
            authority_vertices[triangle].copy(),
        )
        for index, triangle in enumerate(authority_triangles)
    )
    authority_bounds = _records_bounds(authority_records)
    authority_provenance = _provenance_summary(authority_records, source_face_counts)
    _require(authority_provenance["passed"], "unsplit Boolean contains compiler-cap provenance")
    authority_topologies = {
        str(quantum): _topology_for_records(authority_records, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    _require(
        all(_topology_passes(value) for value in authority_topologies.values()),
        "untouched unsplit authority is not closed/oriented at both weld quanta",
    )

    cleaned_records, publication_records, pages, stages = _build_publication(
        authority_records, authority_bounds, property_lookup
    )
    publication_solid, mesh_build = _make_publication_solid(publication_records)
    publication_quality = _quality_summary(publication_records)
    publication_provenance = _provenance_summary(publication_records, source_face_counts)
    publication_topologies = {
        str(quantum): _topology_for_records(publication_records, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    publication_bounds = _records_bounds(publication_records)
    bounds_delta = _bounds_delta(publication_bounds, authority_bounds)
    authority_genera = sorted(int(component.genus()) for component in authority.decompose())
    publication_genera = sorted(
        int(component.genus()) for component in publication_solid.decompose()
    )
    comparison = _surface_and_volume_comparison(
        publication_solid,
        authority,
        publication_records,
        authority_records,
    )

    # Replay from reversed triangle order to prove hashes do not depend on input
    # traversal or dictionary insertion order.
    (
        replay_cleaned_records,
        replay_records,
        replay_pages,
        replay_stages,
    ) = _build_publication(
        list(reversed(authority_records)), authority_bounds, property_lookup
    )
    replay_hashes = replay_stages["atlas"]
    deterministic = {
        "replay_input_order": "reversed_authority_triangle_order",
        "combined_geometry_hash_matches": (
            stages["atlas"]["combined_geometry_sha256"]
            == replay_hashes["combined_geometry_sha256"]
        ),
        "atom_hashes_match": stages["atlas"]["atom_hashes"] == replay_hashes["atom_hashes"],
        "page_hashes_match": stages["atlas"]["page_hashes"] == replay_hashes["page_hashes"],
        "page_payloads_match": pages == replay_pages,
        "pre_emission_cleaned_geometry_matches": (
            _records_digest(cleaned_records) == _records_digest(replay_cleaned_records)
        ),
        "replay_geometry_digest": _records_digest(replay_records),
    }
    deterministic["passed"] = all(
        bool(value)
        for key, value in deterministic.items()
        if key.endswith("_match") or key.endswith("_matches")
    )

    authority_digest_after = exact._mesh_digest(authority)
    authority_untouched = (
        authority_digest_before == authority_digest_after
        and np.array_equal(authority_vertices, authority_vertices_snapshot)
        and np.array_equal(authority_triangles, authority_triangles_snapshot)
        and source_ids == source_ids_snapshot
        and face_ids == face_ids_snapshot
    )
    topology_same = (
        len(authority.decompose()) == len(publication_solid.decompose()) == 1
        and authority_genera == publication_genera
        and all(
            publication_topologies[str(quantum)]["genus"]
            == authority_topologies[str(quantum)]["genus"]
            for quantum in TOPOLOGY_QUANTA_METERS
        )
    )
    hard_gates = {
        "authority_exact_mesh64_untouched": authority_untouched,
        "publication_double_cross_squared_strictly_above_1e_16": (
            int(publication_quality["double_subthreshold_triangle_count"]) == 0
        ),
        "publication_float32_cross_squared_strictly_above_1e_16": (
            int(publication_quality["float32_subthreshold_triangle_count"]) == 0
        ),
        "watertight_oriented_one_component_at_1e_8": _topology_passes(
            publication_topologies[str(1.0e-8)]
        ),
        "watertight_oriented_one_component_at_1e_7": _topology_passes(
            publication_topologies[str(1.0e-7)]
        ),
        "zero_compiler_caps": (
            bool(publication_provenance["passed"])
            and int(publication_provenance["compiler_cap_triangle_count"]) == 0
            and set(int(value) for value in publication_provenance["triangle_counts_by_original_id"])
            <= organic_ids
        ),
        "same_bounds": bounds_delta <= SAME_BOUNDS_TOLERANCE_METERS,
        "same_topology": topology_same,
        "sampled_bidirectional_surface_distance_within_20um": (
            float(comparison["sampled_bidirectional_maximum_m"])
            <= MAX_SAMPLED_SURFACE_DISTANCE_METERS
        ),
        "symmetric_difference_within_5e_10m3": (
            float(comparison["symmetric_difference_volume_m3"])
            <= MAX_SYMMETRIC_DIFFERENCE_VOLUME_M3
        ),
        "patch_vertex_displacement_within_20um": (
            float(
                stages["bounded_patch_cleanup"]
                ["maximum_actual_cumulative_vertex_displacement_m"]
            )
            <= MAX_PATCH_VERTEX_DISPLACEMENT_METERS
        ),
        "atoms_are_indivisible_and_paging_does_not_clip": (
            int(stages["atlas"]["geometric_clip_operation_count"]) == 0
            and not bool(stages["atlas"]["paging_vertices_created"])
            and not bool(stages["atlas"]["paging_vertices_moved"])
            and bool(
                stages["atlas"]["roundtrip"]
                ["combined_geometry_matches_pre_emission"]
            )
            and bool(
                stages["atlas"]["roundtrip"]
                ["whole_atom_hash_multiset_matches"]
            )
        ),
        "emitted_exact_page_arrays_roundtrip_and_hash": (
            bool(stages["atlas"]["roundtrip"]["page_exact_array_hashes_verified"])
            and bool(stages["atlas"]["roundtrip"]["atom_exact_array_hashes_verified"])
        ),
        "deterministic_page_and_atom_hashes": bool(deterministic["passed"]),
    }
    passed = all(hard_gates.values())
    if not passed:
        failed = [name for name, value in hard_gates.items() if not value]
        raise GateFailure("hard publication gates failed: " + ", ".join(failed))

    return {
        "schema": "forge_v2_regional_publication_atlas_prototype_result",
        "schema_version": 1,
        "outcome": "pass",
        "proof_passed": True,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_geometry_gate",
        "production_files_touched": False,
        "production_ready": False,
        "engine": {
            "name": "manifold3d",
            "version": exact.MANIFOLD_VERSION,
            "module_path": str(Path(manifold3d.__file__).resolve()),
            "isolated_target": str(exact.ISOLATED_SITE),
        },
        "fixture": {
            "path": str(exact.FIXTURE_PATH),
            "file_sha256": fixture_sha256,
            "canonical_sha256_matches": bool(fixture_transport["top_level"]["matches"]),
        },
        "authority": {
            "construction": "single_unsplit_stroke_a_plus_stroke_b_boolean",
            "mesh64_sha256_before": authority_digest_before,
            "mesh64_sha256_after": authority_digest_after,
            "untouched": authority_untouched,
            "summary": exact._solid_summary(authority),
            "quality": _quality_summary(authority_records),
            "provenance": authority_provenance,
            "topology_by_weld_quantum": authority_topologies,
        },
        "publication": {
            "construction": (
                "global_zero_move_face_retriangulation_then_bounded_residual_patch_cleanup"
            ),
            "gated_input": (
                "concatenated_records_deserialized_from_organic_publication_pages"
            ),
            "quality": publication_quality,
            "provenance": publication_provenance,
            "bounds": list(publication_bounds),
            "bounds_max_delta_m": bounds_delta,
            "component_genera": publication_genera,
            "topology_by_weld_quantum": publication_topologies,
            "mesh64_build": mesh_build,
            "comparison_to_untouched_authority": comparison,
        },
        "stages": stages,
        "organic_publication_pages": pages,
        "determinism": deterministic,
        "hard_gates": hard_gates,
        "limitations": [
            "fixture-specific tools proof; no production, GDScript, timing, persistence, collision, or render cutover",
            "surface-distance gate is deterministic sampling, as requested, rather than an analytic Hausdorff proof",
        ],
        "elapsed_ms": (time.perf_counter_ns() - started) / 1.0e6,
    }


def _failure_result(error: BaseException) -> dict[str, Any]:
    return {
        "schema": "forge_v2_regional_publication_atlas_prototype_result",
        "schema_version": 1,
        "outcome": "fail",
        "proof_passed": False,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_geometry_gate",
        "production_files_touched": False,
        "production_ready": False,
        "failure_type": type(error).__name__,
        "failure_reason": str(error),
        "engine": {
            "name": "manifold3d",
            "version": exact.MANIFOLD_VERSION,
            "module_path": str(Path(manifold3d.__file__).resolve()),
            "isolated_target": str(exact.ISOLATED_SITE),
        },
    }


def main() -> int:
    try:
        result = _run()
        exit_code = 0
    except Exception as error:
        result = _failure_result(error)
        exit_code = 1
    exact._atomic_write_text(
        OUTPUT_JSON,
        json.dumps(
            result,
            sort_keys=True,
            ensure_ascii=True,
            allow_nan=False,
            separators=(",", ":"),
        )
        + "\n",
    )
    if exit_code == 0:
        print(
            "REGIONAL PUBLICATION ATLAS PASS pages=%d atoms=%d triangles=%d collapses=%d"
            % (
                len(result["organic_publication_pages"]),
                result["stages"]["atlas"]["atom_count"],
                result["publication"]["quality"]["triangle_count"],
                result["stages"]["bounded_patch_cleanup"]["collapse_count"],
            )
        )
    else:
        print(
            "REGIONAL PUBLICATION ATLAS FAIL: %s: %s"
            % (result["failure_type"], result["failure_reason"]),
            file=sys.stderr,
        )
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
