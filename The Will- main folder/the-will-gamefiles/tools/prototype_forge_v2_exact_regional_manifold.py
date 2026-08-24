#!/usr/bin/env python3
"""Tools-only proof for exact organic Forge V2 regional Booleans.

The 64 mm grid in this prototype is spatial jurisdiction only.  Geometry is
always the exact triangulated Forge sweep exported by Godot; no vertex is
snapped to the grid and no occupied-cell surface is generated.

This program deliberately imports manifold3d 3.3.2 from the isolated test
target in ``godot_runs``.  It never installs a package and never touches Forge
runtime state or user:// data.
"""

from __future__ import annotations

import csv
import hashlib
import importlib.metadata
import io
import json
import math
import os
from pathlib import Path
import statistics
import sys
import time
import traceback
from dataclasses import dataclass
from typing import Any, Iterable, Mapping, Sequence


WORKSPACE = Path(r"C:\WORKSPACE")
PROJECT = WORKSPACE / "The Will- main folder" / "the-will-gamefiles"
FIXTURE_PATH = WORKSPACE / "godot_runs" / "forge_v2_exact_regional_fixture_v1.json"
ISOLATED_SITE = WORKSPACE / "godot_runs" / "forge_v2_regional_manifold_py"
OUTPUT_STEM = WORKSPACE / "godot_runs" / "forge_v2_exact_regional_manifold_prototype"
OUTPUT_JSON = OUTPUT_STEM.with_suffix(".json")
OUTPUT_CSV = OUTPUT_STEM.with_suffix(".csv")
OUTPUT_REPORT = OUTPUT_STEM.with_suffix(".md")

REQUIRED_MANIFOLD_VERSION = "3.3.2"
CHUNK_SIZE_METERS = 0.064
HALO_RINGS = 2
WARMUP_PAIRS = 5
MEASURED_PAIRS = 20
PLANE_EPSILON = 1.0e-10
CANONICAL_QUANTUM = 1.0e-9
SEAM_QUANTUM = 1.0e-8
GODOT_STRICT_WELD_QUANTUM = 1.0e-7
GODOT_DEGENERATE_CROSS_SQUARED = 1.0e-16
BOUNDS_TOLERANCE = 1.0e-5
SURFACE_DISTANCE_TOLERANCE = 2.0e-5
SEAM_AREA_TOLERANCE = 1.0e-10
MAX_SURFACE_SAMPLES = 1536


def _import_isolated_dependencies() -> tuple[Any, Any, str]:
    """Import numpy/manifold3d exclusively from the pinned isolated target."""
    if not ISOLATED_SITE.is_dir():
        raise RuntimeError(f"isolated dependency target is missing: {ISOLATED_SITE}")
    sys.path.insert(0, str(ISOLATED_SITE))
    import numpy as np  # type: ignore[import-not-found]
    import manifold3d as manifold  # type: ignore[import-not-found]

    module_path = Path(manifold.__file__).resolve()
    isolated_root = ISOLATED_SITE.resolve()
    if isolated_root not in module_path.parents:
        raise RuntimeError(
            "manifold3d was not imported from the isolated target: "
            f"{module_path}"
        )
    versions = [
        distribution.version
        for distribution in importlib.metadata.distributions(path=[str(ISOLATED_SITE)])
        if distribution.metadata.get("Name", "").lower() == "manifold3d"
    ]
    if versions != [REQUIRED_MANIFOLD_VERSION]:
        raise RuntimeError(
            f"expected isolated manifold3d {REQUIRED_MANIFOLD_VERSION}, got {versions}"
        )
    return np, manifold, versions[0]


np, manifold3d, MANIFOLD_VERSION = _import_isolated_dependencies()


class ProofFailure(RuntimeError):
    """A hard proof gate failed without mutating the published state."""


@dataclass(frozen=True)
class PacketSolid:
    name: str
    original_id: int
    manifold: Any
    triangle_count: int
    signed_volume_before_import: float
    input_winding_reversed_for_manifold: bool
    mesh_merge_attempted: bool
    mesh_merge_changed: bool


@dataclass(frozen=True)
class Fragment:
    coordinate: tuple[int, int, int]
    manifold: Any
    digest: str


@dataclass(frozen=True)
class WorkpieceState:
    fragments: Mapping[tuple[int, int, int], Fragment]
    revision: int


class FragmentOverlay(Mapping[tuple[int, int, int], Fragment]):
    """Persistent local transaction overlay over an immutable base mapping."""

    def __init__(
        self,
        base: Mapping[tuple[int, int, int], Fragment],
        removed: set[tuple[int, int, int]],
        replacements: Mapping[tuple[int, int, int], Fragment],
    ) -> None:
        self._base = base
        self._removed = frozenset(removed)
        self._replacements = dict(replacements)
        removed_base_count = sum(1 for coordinate in self._removed if coordinate in base)
        added_count = sum(
            1
            for coordinate in self._replacements
            if coordinate not in base or coordinate in self._removed
        )
        self._length = len(base) - removed_base_count + added_count

    def __getitem__(self, coordinate: tuple[int, int, int]) -> Fragment:
        if coordinate in self._replacements:
            return self._replacements[coordinate]
        if coordinate in self._removed:
            raise KeyError(coordinate)
        return self._base[coordinate]

    def __iter__(self):
        for coordinate in self._base:
            if coordinate not in self._removed and coordinate not in self._replacements:
                yield coordinate
        yield from self._replacements

    def __len__(self) -> int:
        return self._length

    def __contains__(self, coordinate: object) -> bool:
        if coordinate in self._replacements:
            return True
        if coordinate in self._removed:
            return False
        return coordinate in self._base


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ProofFailure(message)


def _status_name(solid: Any) -> str:
    status = solid.status()
    return getattr(status, "name", str(status))


def _is_ok(solid: Any) -> bool:
    return _status_name(solid) == "NoError"


def _atomic_write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temporary.open("w", encoding="utf-8", newline="") as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _canonical_number(value: float, quantum: float = CANONICAL_QUANTUM) -> int:
    return int(round(float(value) / quantum))


def _canonical_point(point: Sequence[float], quantum: float = CANONICAL_QUANTUM) -> tuple[int, int, int]:
    return tuple(_canonical_number(float(component), quantum) for component in point)  # type: ignore[return-value]


def _load_fixture() -> tuple[dict[str, Any], str]:
    _require(FIXTURE_PATH.is_file(), f"fixture is missing: {FIXTURE_PATH}")
    raw = FIXTURE_PATH.read_bytes()
    fixture = json.loads(raw.decode("utf-8"))
    _require(isinstance(fixture, dict), "fixture root must be an object")
    _require(fixture.get("schema") == "forge_v2_exact_regional_fixture", "unexpected fixture schema")
    _require(int(fixture.get("schema_version", -1)) == 1, "unexpected fixture schema version")
    _require(fixture.get("coordinate_units") == "meters", "fixture must use meters")
    fixture_chunk_size = float(fixture.get("chunk_size_meters", CHUNK_SIZE_METERS))
    _require(
        abs(fixture_chunk_size - CHUNK_SIZE_METERS) <= 1.0e-12,
        f"fixture chunk size {fixture_chunk_size} is not {CHUNK_SIZE_METERS}",
    )
    packets = fixture.get("packets")
    _require(isinstance(packets, dict), "fixture packets must be an object")
    for packet_name in ("stroke_a", "stroke_b", "mature_extension"):
        _require(packet_name in packets, f"fixture packet is missing: {packet_name}")
    return fixture, _sha256_bytes(raw)


def _packet_triangles(packet: Mapping[str, Any]) -> Any:
    raw_triangles = packet.get("triangles", [])
    values: list[list[int]] = []
    for triangle in raw_triangles:
        indices = triangle.get("indices") if isinstance(triangle, dict) else triangle
        _require(isinstance(indices, list) and len(indices) == 3, "triangle indices must contain three values")
        values.append([int(indices[0]), int(indices[1]), int(indices[2])])
    return np.asarray(values, dtype=np.uint64)


def _signed_mesh_volume(vertices: Any, triangles: Any) -> float:
    if len(triangles) == 0:
        return 0.0
    a = vertices[triangles[:, 0]]
    b = vertices[triangles[:, 1]]
    c = vertices[triangles[:, 2]]
    return float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)


def _make_packet_solid(packet_name: str, packet: Mapping[str, Any], original_id: int) -> PacketSolid:
    _require(packet.get("coordinate_units", "meters") == "meters", f"{packet_name} is not in meters")
    vertices = np.asarray(packet.get("vertices", []), dtype=np.float64)
    triangles = _packet_triangles(packet)
    _require(vertices.ndim == 2 and vertices.shape[1:] == (3,), f"{packet_name} vertices must be Nx3")
    _require(triangles.ndim == 2 and triangles.shape[1:] == (3,), f"{packet_name} triangles must be Nx3")
    _require(len(vertices) >= 4 and len(triangles) >= 4, f"{packet_name} mesh is empty")
    _require(bool(np.isfinite(vertices).all()), f"{packet_name} contains a non-finite vertex")
    _require(int(triangles.max()) < len(vertices), f"{packet_name} has an out-of-range triangle index")

    tri_points = vertices[triangles]
    double_areas = np.linalg.norm(
        np.cross(tri_points[:, 1] - tri_points[:, 0], tri_points[:, 2] - tri_points[:, 0]),
        axis=1,
    )
    _require(bool(np.all(double_areas > 1.0e-16)), f"{packet_name} contains degenerate triangles")

    signed_volume = _signed_mesh_volume(vertices, triangles)
    _require(abs(signed_volume) > 1.0e-15, f"{packet_name} has zero signed volume")
    reversed_for_manifold = signed_volume < 0.0
    if reversed_for_manifold:
        # Godot's current Forge sweep uses the opposite signed-volume convention.
        # Reverse every face exactly once before asking Manifold to do set algebra.
        triangles = triangles[:, [0, 2, 1]].copy()

    run_index = np.asarray([0, len(triangles) * 3], dtype=np.uint64)
    run_original_id = np.asarray([original_id], dtype=np.uint32)
    face_id = np.arange(len(triangles), dtype=np.uint64)
    mesh = manifold3d.Mesh64(
        np.ascontiguousarray(vertices),
        np.ascontiguousarray(triangles),
        run_index=run_index,
        run_original_id=run_original_id,
        face_id=face_id,
        tolerance=0.0,
    )
    solid = manifold3d.Manifold(mesh)
    merge_attempted = False
    merge_changed = False
    if not _is_ok(solid):
        # SurfaceTool may export coincident property vertices.  Mesh64.merge only
        # supplies topology relations; it does not voxelize or move the surface.
        merge_attempted = True
        merge_changed = bool(mesh.merge())
        solid = manifold3d.Manifold(mesh)
    _require(_is_ok(solid), f"{packet_name} is not an oriented manifold: {_status_name(solid)}")
    _require(not solid.is_empty(), f"{packet_name} imported as an empty manifold")
    _require(len(solid.decompose()) == 1, f"{packet_name} must be one connected component")
    _require(solid.volume() > 0.0, f"{packet_name} has non-positive Manifold volume")
    return PacketSolid(
        name=packet_name,
        original_id=original_id,
        manifold=solid,
        triangle_count=len(triangles),
        signed_volume_before_import=signed_volume,
        input_winding_reversed_for_manifold=reversed_for_manifold,
        mesh_merge_attempted=merge_attempted,
        mesh_merge_changed=merge_changed,
    )


def _triangle_records(solid: Any) -> tuple[Any, Any, list[int], list[int]]:
    mesh = solid.to_mesh64()
    vertices = np.asarray(mesh.vert_properties, dtype=np.float64)[:, :3]
    triangles = np.asarray(mesh.tri_verts, dtype=np.uint64)
    run_index = [int(value) for value in mesh.run_index]
    run_ids = [int(value) for value in mesh.run_original_id]
    face_ids = [int(value) for value in mesh.face_id]
    _require(len(face_ids) == len(triangles), "Manifold faceID count does not match triangle count")
    _require(len(run_index) == len(run_ids) + 1, "Manifold run relation is malformed")
    original_ids: list[int] = []
    run_cursor = 0
    for triangle_index in range(len(triangles)):
        flat_index = triangle_index * 3
        while run_cursor + 1 < len(run_ids) and flat_index >= run_index[run_cursor + 1]:
            run_cursor += 1
        original_ids.append(run_ids[run_cursor])
    return vertices, triangles, original_ids, face_ids


def _mesh_digest(solid: Any) -> str:
    vertices, triangles, original_ids, face_ids = _triangle_records(solid)
    records: list[tuple[Any, ...]] = []
    for index, triangle in enumerate(triangles):
        points = [_canonical_point(vertices[int(vertex)]) for vertex in triangle]
        # Preserve winding but make the start vertex irrelevant.
        cycles = [tuple(points[offset:] + points[:offset]) for offset in range(3)]
        records.append((min(cycles), int(original_ids[index]), int(face_ids[index])))
    records.sort()
    payload = json.dumps(records, ensure_ascii=True, separators=(",", ":")).encode("ascii")
    return _sha256_bytes(payload)


def _chunk_span(minimum: float, maximum: float) -> range:
    low = math.floor((minimum + PLANE_EPSILON) / CHUNK_SIZE_METERS)
    high = math.floor((maximum - PLANE_EPSILON) / CHUNK_SIZE_METERS)
    if high < low:
        high = low
    return range(low, high + 1)


def _split_piece_on_axis(
    solid: Any,
    partial_coordinate: tuple[int | None, int | None, int | None],
    axis: int,
) -> list[tuple[Any, tuple[int | None, int | None, int | None]]]:
    bounds = solid.bounding_box()
    indices = list(_chunk_span(float(bounds[axis]), float(bounds[axis + 3])))
    if len(indices) == 1:
        coordinate = list(partial_coordinate)
        coordinate[axis] = indices[0]
        return [(solid, tuple(coordinate))]  # type: ignore[list-item]

    normal = [0.0, 0.0, 0.0]
    normal[axis] = 1.0
    remainder = solid
    output: list[tuple[Any, tuple[int | None, int | None, int | None]]] = []
    for chunk_index in indices[:-1]:
        plane = float(chunk_index + 1) * CHUNK_SIZE_METERS
        positive, negative = remainder.split_by_plane(normal, plane)
        _require(_is_ok(positive) and _is_ok(negative), "paired split_by_plane failed")
        if not negative.is_empty():
            coordinate = list(partial_coordinate)
            coordinate[axis] = chunk_index
            output.append((negative, tuple(coordinate)))  # type: ignore[arg-type]
        remainder = positive
    if not remainder.is_empty():
        coordinate = list(partial_coordinate)
        coordinate[axis] = indices[-1]
        output.append((remainder, tuple(coordinate)))  # type: ignore[arg-type]
    return output


def _split_to_chunks(solid: Any) -> dict[tuple[int, int, int], Fragment]:
    pieces: list[tuple[Any, tuple[int | None, int | None, int | None]]] = [
        (solid, (None, None, None))
    ]
    for axis in range(3):
        next_pieces: list[tuple[Any, tuple[int | None, int | None, int | None]]] = []
        for piece, coordinate in pieces:
            next_pieces.extend(_split_piece_on_axis(piece, coordinate, axis))
        pieces = next_pieces

    fragments: dict[tuple[int, int, int], Fragment] = {}
    for piece, partial in pieces:
        _require(all(value is not None for value in partial), "chunk coordinate was not resolved")
        coordinate = (int(partial[0]), int(partial[1]), int(partial[2]))
        _require(coordinate not in fragments, f"duplicate chunk fragment {coordinate}")
        fragments[coordinate] = Fragment(coordinate, piece, _mesh_digest(piece))
    _require(bool(fragments), "chunk partition produced no fragments")
    return fragments


def _batch_union(solids: Iterable[Any]) -> Any:
    values = [solid for solid in solids if not solid.is_empty()]
    if not values:
        return manifold3d.Manifold()
    if len(values) == 1:
        return values[0]
    result = manifold3d.Manifold.batch_boolean(values, manifold3d.OpType.Add)
    _require(_is_ok(result), f"batch union failed: {_status_name(result)}")
    return result


def _assemble_region_from_fragments(
    fragments: Mapping[tuple[int, int, int], Fragment],
    organic_ids: set[int],
) -> tuple[Any, dict[str, Any]]:
    """Remove paired internal caps, concatenate exact faces, and topology-weld.

    Storage fragments are closed.  A Boolean region must instead be one closed
    solid with only its *perimeter* jurisdiction caps.  Paired internal cap runs
    are removed before Mesh64 construction.  ``Mesh64.merge()`` creates merge
    relations for coincident seam/property vertices; coordinates are copied
    exactly and are never averaged, snapped, or voxelized.
    """
    _require(bool(fragments), "cannot assemble an empty fragment map")
    selected_coordinates = set(fragments)
    records: list[tuple[int, int, Any]] = []
    organic_triangle_count = 0
    retained_perimeter_cap_count = 0
    removed_internal_cap_count = 0
    for coordinate in sorted(fragments):
        vertices, triangles, source_ids, face_ids = _triangle_records(
            fragments[coordinate].manifold
        )
        for triangle_index, triangle in enumerate(triangles):
            source_id = int(source_ids[triangle_index])
            points = vertices[triangle].copy()
            if source_id in organic_ids:
                organic_triangle_count += 1
                records.append((source_id, int(face_ids[triangle_index]), points))
                continue
            cap_face = _triangle_cap_face(coordinate, points)
            _require(
                cap_face is not None,
                f"compiler cap in {coordinate} is not on a jurisdiction boundary",
            )
            axis, side = cap_face
            neighbor = list(coordinate)
            neighbor[axis] += side
            if tuple(neighbor) in selected_coordinates:
                removed_internal_cap_count += 1
                continue
            retained_perimeter_cap_count += 1
            records.append((source_id, int(face_ids[triangle_index]), points))

    _require(bool(records), "region assembly retained no triangles")
    records, conforming_diagnostics = _make_triangle_soup_conforming(records)
    records.sort(key=lambda item: (item[0], item[1]))
    assembled_vertices: list[list[float]] = []
    assembled_triangles: list[list[int]] = []
    assembled_face_ids: list[int] = []
    run_indices: list[int] = [0]
    run_original_ids: list[int] = []
    current_source: int | None = None
    for source_id, face_id, points in records:
        if current_source != source_id:
            if current_source is not None:
                run_indices.append(len(assembled_triangles) * 3)
            run_original_ids.append(source_id)
            current_source = source_id
        offset = len(assembled_vertices)
        assembled_vertices.extend(
            [[float(value) for value in point] for point in points]
        )
        assembled_triangles.append([offset, offset + 1, offset + 2])
        assembled_face_ids.append(face_id)
    run_indices.append(len(assembled_triangles) * 3)

    mesh = manifold3d.Mesh64(
        np.asarray(assembled_vertices, dtype=np.float64),
        np.asarray(assembled_triangles, dtype=np.uint64),
        run_index=np.asarray(run_indices, dtype=np.uint64),
        run_original_id=np.asarray(run_original_ids, dtype=np.uint32),
        face_id=np.asarray(assembled_face_ids, dtype=np.uint64),
        tolerance=0.0,
    )
    pre_merge_status = _status_name(manifold3d.Manifold(mesh))
    merge_changed = bool(mesh.merge())
    merge_relation_count = len(mesh.merge_from_vert)
    solid = manifold3d.Manifold(mesh)
    _require(_is_ok(solid), f"welded regional assembly failed: {_status_name(solid)}")
    _require(not solid.is_empty(), "welded regional assembly is empty")
    _require(
        len(solid.decompose()) == 1,
        "welded regional assembly did not produce one connected solid",
    )
    diagnostics = {
        "input_fragment_count": len(fragments),
        "organic_triangle_count": organic_triangle_count,
        "retained_perimeter_cap_triangle_count": retained_perimeter_cap_count,
        "removed_internal_cap_triangle_count": removed_internal_cap_count,
        "concatenated_triangle_count": len(assembled_triangles),
        "concatenated_property_vertex_count": len(assembled_vertices),
        "pre_merge_status": pre_merge_status,
        "merge_changed": merge_changed,
        "merge_relation_count": merge_relation_count,
        "post_merge_status": _status_name(solid),
        "post_merge_component_count": len(solid.decompose()),
        "post_merge_triangle_count": int(solid.num_tri()),
        "coordinates_moved_or_snapped": False,
        "conforming_seam_refinement": conforming_diagnostics,
    }
    return solid, diagnostics


def _record_edge_counts(
    records: Sequence[tuple[Any, ...]],
) -> tuple[dict[tuple[Any, Any], int], dict[Any, Any]]:
    counts: dict[tuple[Any, Any], int] = {}
    representatives: dict[Any, Any] = {}
    for record in records:
        points = record[-1]
        keys = []
        for point in points:
            key = _canonical_point(point, 1.0e-12)
            representatives.setdefault(key, np.asarray(point, dtype=np.float64).copy())
            keys.append(key)
        for start, end in ((keys[0], keys[1]), (keys[1], keys[2]), (keys[2], keys[0])):
            edge = tuple(sorted((start, end)))
            counts[edge] = counts.get(edge, 0) + 1
    return counts, representatives


def _point_parameter_on_segment(point: Any, start: Any, end: Any) -> float | None:
    direction = end - start
    length_squared = float(np.dot(direction, direction))
    if length_squared <= 1.0e-30:
        return None
    amount = float(np.dot(point - start, direction) / length_squared)
    if amount <= 1.0e-10 or amount >= 1.0 - 1.0e-10:
        return None
    closest = start + direction * amount
    scale = max(1.0, math.sqrt(length_squared))
    if float(np.linalg.norm(point - closest)) > 1.0e-11 * scale:
        return None
    return amount


def _make_triangle_soup_conforming(
    records: Sequence[tuple[Any, ...]],
) -> tuple[list[tuple[Any, ...]], dict[str, Any]]:
    """Resolve exact seam T-junctions without changing the represented surface."""
    edge_counts, representatives = _record_edge_counts(records)
    unmatched_edges = {edge for edge, count in edge_counts.items() if count == 1}
    candidate_keys = sorted({point for edge in unmatched_edges for point in edge})
    candidate_points = [(key, representatives[key]) for key in candidate_keys]
    output: list[tuple[Any, ...]] = []
    refined_triangle_count = 0
    inserted_boundary_vertex_uses = 0
    for record in records:
        metadata = record[:-3]
        source_id = int(record[-3])
        face_id = int(record[-2])
        raw_points = record[-1]
        points = np.asarray(raw_points, dtype=np.float64)
        boundary: list[Any] = []
        added_on_triangle = 0
        for edge_index in range(3):
            start = points[edge_index]
            end = points[(edge_index + 1) % 3]
            start_key = _canonical_point(start, 1.0e-12)
            end_key = _canonical_point(end, 1.0e-12)
            boundary.append(start)
            edge_key = tuple(sorted((start_key, end_key)))
            if edge_key not in unmatched_edges:
                continue
            interior: list[tuple[float, Any]] = []
            for candidate_key, candidate_point in candidate_points:
                if candidate_key == start_key or candidate_key == end_key:
                    continue
                amount = _point_parameter_on_segment(candidate_point, start, end)
                if amount is not None:
                    interior.append((amount, candidate_point))
            interior.sort(key=lambda item: item[0])
            for _amount, candidate_point in interior:
                boundary.append(candidate_point)
                added_on_triangle += 1
        if added_on_triangle == 0:
            output.append((*metadata, source_id, face_id, points.copy()))
            continue
        refined_triangle_count += 1
        inserted_boundary_vertex_uses += added_on_triangle
        center = points.mean(axis=0)
        for boundary_index, start in enumerate(boundary):
            end = boundary[(boundary_index + 1) % len(boundary)]
            triangle = np.asarray([start, end, center], dtype=np.float64)
            double_area = float(
                np.linalg.norm(np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0]))
            )
            _require(double_area > 1.0e-18, "conforming seam refinement made a degenerate triangle")
            output.append((*metadata, source_id, face_id, triangle))

    post_counts, _post_representatives = _record_edge_counts(output)
    post_boundary = sum(1 for count in post_counts.values() if count == 1)
    post_nonmanifold = sum(1 for count in post_counts.values() if count != 2)
    return output, {
        "pre_refinement_unmatched_edge_count": len(unmatched_edges),
        "refined_triangle_count": refined_triangle_count,
        "inserted_boundary_vertex_uses": inserted_boundary_vertex_uses,
        "post_refinement_boundary_edge_count": post_boundary,
        "post_refinement_nonmanifold_edge_count": post_nonmanifold,
        "surface_geometry_changed": False,
    }


def _triangle_cross_squared(points: Any, dtype: Any = np.float64) -> float:
    values = np.asarray(points, dtype=dtype)
    cross = np.cross(values[1] - values[0], values[2] - values[0])
    return float(np.dot(cross, cross))


def _triangle_quality(points: Any) -> float:
    """Return the weaker of the double and Godot-float triangle qualities."""
    return min(
        _triangle_cross_squared(points, np.float64),
        _triangle_cross_squared(points, np.float32),
    )


def _surface_area_for_records(records: Sequence[tuple[Any, ...]]) -> float:
    area = 0.0
    for record in records:
        points = np.asarray(record[-1], dtype=np.float64)
        area += 0.5 * float(
            np.linalg.norm(np.cross(points[1] - points[0], points[2] - points[0]))
        )
    return area


def _face_boundary_loops(records: Sequence[tuple[Any, ...]]) -> tuple[list[list[Any]], Any]:
    """Recover directed polygon loops from one conforming source-face patch."""
    edge_uses: dict[
        tuple[tuple[float, float, float], tuple[float, float, float]],
        list[tuple[tuple[float, float, float], tuple[float, float, float]]],
    ] = {}
    representatives: dict[tuple[float, float, float], Any] = {}
    normal_sum = np.zeros(3, dtype=np.float64)
    for record in records:
        points = np.asarray(record[-1], dtype=np.float64)
        normal_sum += np.cross(points[1] - points[0], points[2] - points[0])
        keys = [tuple(float(value) for value in point) for point in points]
        for key, point in zip(keys, points):
            representatives.setdefault(key, point.copy())
        for start, end in ((keys[0], keys[1]), (keys[1], keys[2]), (keys[2], keys[0])):
            edge = tuple(sorted((start, end)))
            edge_uses.setdefault(edge, []).append((start, end))

    _require(
        float(np.linalg.norm(normal_sum)) > 1.0e-20,
        "source-face patch has no stable normal",
    )
    _require(
        all(len(uses) <= 2 for uses in edge_uses.values()),
        "source-face patch contains a nonmanifold edge",
    )
    boundary_edges = {edge for edge, uses in edge_uses.items() if len(uses) == 1}
    _require(bool(boundary_edges), "source-face patch has no boundary")
    adjacency: dict[tuple[float, float, float], set[tuple[float, float, float]]] = {}
    for start, end in boundary_edges:
        adjacency.setdefault(start, set()).add(end)
        adjacency.setdefault(end, set()).add(start)
    _require(
        all(len(neighbors) == 2 for neighbors in adjacency.values()),
        "source-face patch boundary is not a collection of closed loops",
    )

    loops: list[list[Any]] = []
    remaining = set(boundary_edges)
    while remaining:
        first = min(remaining)
        start, current = first
        previous = start
        keys = [start, current]
        remaining.remove(first)
        while current != start:
            candidates = sorted(
                neighbor
                for neighbor in adjacency[current]
                if neighbor != previous
            )
            _require(bool(candidates), "source-face boundary traversal stopped early")
            following = candidates[0]
            edge = tuple(sorted((current, following)))
            if following != start:
                _require(edge in remaining, "source-face boundary contains overlapping loops")
                remaining.remove(edge)
                keys.append(following)
            else:
                remaining.discard(edge)
            previous, current = current, following

        points = [representatives[key].copy() for key in keys]
        loop_normal = np.zeros(3, dtype=np.float64)
        for index, point in enumerate(points):
            loop_normal += np.cross(point, points[(index + 1) % len(points)])
        if float(np.dot(loop_normal, normal_sum)) < 0.0:
            points.reverse()
        loops.append(points)
    return loops, normal_sum


def _project_polygon(points: Sequence[Any], normal: Any) -> tuple[Any, int]:
    dropped_axis = int(np.argmax(np.abs(np.asarray(normal, dtype=np.float64))))
    kept_axes = [axis for axis in range(3) if axis != dropped_axis]
    return (
        np.asarray(
            [[float(point[kept_axes[0]]), float(point[kept_axes[1]])] for point in points],
            dtype=np.float64,
        ),
        dropped_axis,
    )


def _cross_2d(first: Any, second: Any, third: Any) -> float:
    return float(
        (second[0] - first[0]) * (third[1] - first[1])
        - (second[1] - first[1]) * (third[0] - first[0])
    )


def _point_in_triangle_2d(
    point: Any,
    first: Any,
    second: Any,
    third: Any,
    orientation: float,
    epsilon: float,
) -> bool:
    values = (
        orientation * _cross_2d(first, second, point),
        orientation * _cross_2d(second, third, point),
        orientation * _cross_2d(third, first, point),
    )
    return min(values) >= -epsilon


def _quality_triangulate_polygon(points: Sequence[Any], normal: Any) -> list[Any]:
    """Retriangulate a planar loop while preserving every boundary vertex.

    Convex loops use a max-min dynamic program. A deterministic best-ear path
    handles a non-convex loop. Neither path creates or moves a vertex.
    """
    _require(len(points) >= 3, "source-face polygon has fewer than three vertices")
    values = [np.asarray(point, dtype=np.float64).copy() for point in points]
    projected, _dropped_axis = _project_polygon(values, normal)
    signed_double_area = sum(
        float(
            projected[index, 0] * projected[(index + 1) % len(values), 1]
            - projected[(index + 1) % len(values), 0] * projected[index, 1]
        )
        for index in range(len(values))
    )
    _require(abs(signed_double_area) > 1.0e-24, "source-face polygon projection is degenerate")
    orientation = 1.0 if signed_double_area > 0.0 else -1.0
    span = max(
        float(np.ptp(projected[:, 0])),
        float(np.ptp(projected[:, 1])),
        1.0e-12,
    )
    convex_epsilon = span * span * 1.0e-13
    convex = all(
        orientation
        * _cross_2d(
            projected[(index - 1) % len(values)],
            projected[index],
            projected[(index + 1) % len(values)],
        )
        >= -convex_epsilon
        for index in range(len(values))
    )

    index_triangles: list[tuple[int, int, int]] = []
    if convex:
        count = len(values)
        scores = [[-1.0 for _column in range(count)] for _row in range(count)]
        choices = [[-1 for _column in range(count)] for _row in range(count)]
        for index in range(count):
            scores[index][index] = math.inf
            if index + 1 < count:
                scores[index][index + 1] = math.inf
        for width in range(2, count):
            for first in range(count - width):
                last = first + width
                best_score = -1.0
                best_middle = -1
                for middle in range(first + 1, last):
                    triangle = np.asarray(
                        [values[first], values[middle], values[last]],
                        dtype=np.float64,
                    )
                    candidate = min(
                        scores[first][middle],
                        scores[middle][last],
                        _triangle_quality(triangle),
                    )
                    if candidate > best_score:
                        best_score = candidate
                        best_middle = middle
                _require(best_middle >= 0, "convex polygon triangulation found no diagonal")
                scores[first][last] = best_score
                choices[first][last] = best_middle

        pending = [(0, count - 1)]
        while pending:
            first, last = pending.pop()
            if last <= first + 1:
                continue
            middle = choices[first][last]
            _require(middle > first and middle < last, "convex triangulation reconstruction failed")
            index_triangles.append((first, middle, last))
            pending.append((middle, last))
            pending.append((first, middle))
    else:
        # A greedy ear choice can strand a small final triangle. Affected
        # clipped source-face loops are small, so search every legal ear path
        # and maximize the weakest final triangle. This is used only for a face
        # group that already contains a Godot-subthreshold triangle.
        memo: dict[tuple[int, ...], tuple[float, tuple[tuple[int, int, int], ...]]] = {}

        def solve_ears(
            remaining: tuple[int, ...],
        ) -> tuple[float, tuple[tuple[int, int, int], ...]]:
            cached = memo.get(remaining)
            if cached is not None:
                return cached
            if len(remaining) == 3:
                triangle = (remaining[0], remaining[1], remaining[2])
                turn = orientation * _cross_2d(
                    projected[triangle[0]],
                    projected[triangle[1]],
                    projected[triangle[2]],
                )
                if turn <= convex_epsilon:
                    result = (-1.0, ())
                else:
                    result = (
                        _triangle_quality(
                            np.asarray([values[index] for index in triangle])
                        ),
                        (triangle,),
                    )
                memo[remaining] = result
                return result

            best_score = -1.0
            best_triangles: tuple[tuple[int, int, int], ...] = ()
            for offset, middle in enumerate(remaining):
                first = remaining[(offset - 1) % len(remaining)]
                last = remaining[(offset + 1) % len(remaining)]
                turn = orientation * _cross_2d(
                    projected[first], projected[middle], projected[last]
                )
                if turn <= convex_epsilon:
                    continue
                contains_other = any(
                    _point_in_triangle_2d(
                        projected[candidate],
                        projected[first],
                        projected[middle],
                        projected[last],
                        orientation,
                        convex_epsilon,
                    )
                    for candidate in remaining
                    if candidate not in (first, middle, last)
                )
                if contains_other:
                    continue
                next_remaining = remaining[:offset] + remaining[offset + 1 :]
                following_score, following_triangles = solve_ears(next_remaining)
                if following_score < 0.0:
                    continue
                triangle = (first, middle, last)
                score = min(
                    _triangle_quality(
                        np.asarray([values[index] for index in triangle])
                    ),
                    following_score,
                )
                candidate_triangles = (triangle,) + following_triangles
                if score > best_score or (
                    score == best_score
                    and candidate_triangles < best_triangles
                ):
                    best_score = score
                    best_triangles = candidate_triangles
            result = (best_score, best_triangles)
            memo[remaining] = result
            return result

        _best_score, best_triangles = solve_ears(tuple(range(len(values))))
        _require(bool(best_triangles), "non-convex source-face polygon has no valid triangulation")
        index_triangles.extend(best_triangles)

    triangles: list[Any] = []
    reference_normal = np.asarray(normal, dtype=np.float64)
    for first, middle, last in index_triangles:
        triangle = np.asarray(
            [values[first], values[middle], values[last]], dtype=np.float64
        )
        triangle_normal = np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])
        if float(np.dot(triangle_normal, reference_normal)) < 0.0:
            triangle = triangle[[0, 2, 1]].copy()
        triangles.append(triangle)
    return triangles


def _quality_retriangulate_publication_records(
    records: Sequence[tuple[Any, ...]],
) -> tuple[list[tuple[Any, ...]], dict[str, Any]]:
    """Normalize only derived publication connectivity; authority is untouched."""
    groups: dict[tuple[Any, ...], list[tuple[Any, ...]]] = {}
    for record in records:
        # Coordinate, original ID, and source face are immutable provenance.
        key = tuple(record[:-1])
        groups.setdefault(key, []).append(record)

    input_area = _surface_area_for_records(records)
    before_double = [_triangle_cross_squared(record[-1], np.float64) for record in records]
    before_float = [_triangle_cross_squared(record[-1], np.float32) for record in records]
    output: list[tuple[Any, ...]] = []
    retriangulated_groups = 0
    largest_group_area_delta = 0.0
    multiple_loop_groups = 0
    for key in sorted(groups):
        group = groups[key]
        group_input_area = _surface_area_for_records(group)
        input_minimum_quality = min(
            _triangle_quality(record[-1]) for record in group
        )
        if input_minimum_quality > GODOT_DEGENERATE_CROSS_SQUARED:
            output.extend(group)
            continue
        loops, normal = _face_boundary_loops(group)
        multiple_loop_groups += int(len(loops) > 1)
        group_triangles: list[Any] = []
        for loop in loops:
            group_triangles.extend(_quality_triangulate_polygon(loop, normal))
        group_output_records = [(*key, triangle) for triangle in group_triangles]
        group_output_area = _surface_area_for_records(group_output_records)
        area_delta = abs(group_output_area - group_input_area)
        largest_group_area_delta = max(largest_group_area_delta, area_delta)
        area_tolerance = max(1.0e-15, group_input_area * 1.0e-10)
        _require(
            area_delta <= area_tolerance,
            f"source-face retriangulation changed area for {key}: {area_delta}",
        )
        output_minimum_quality = min(
            _triangle_quality(triangle) for triangle in group_triangles
        )
        if output_minimum_quality > input_minimum_quality:
            retriangulated_groups += 1
            output.extend(group_output_records)
        else:
            # No-movement cleanup is monotonic. Retain the authoritative
            # conforming tessellation when a legal retriangulation cannot make
            # its weakest face strictly better.
            output.extend(group)

    output_area = _surface_area_for_records(output)
    after_double = [_triangle_cross_squared(record[-1], np.float64) for record in output]
    after_float = [_triangle_cross_squared(record[-1], np.float32) for record in output]
    before_bad_keys = {
        tuple(record[:-1])
        for record, double_quality, float_quality in zip(
            records, before_double, before_float
        )
        if min(double_quality, float_quality) <= GODOT_DEGENERATE_CROSS_SQUARED
    }
    after_bad_keys = {
        tuple(record[:-1])
        for record, double_quality, float_quality in zip(
            output, after_double, after_float
        )
        if min(double_quality, float_quality) <= GODOT_DEGENERATE_CROSS_SQUARED
    }
    _require(
        {tuple(record[:-1]) for record in records}
        == {tuple(record[:-1]) for record in output},
        "publication retriangulation lost a provenance face group",
    )
    return output, {
        "method": "no_movement_per_chunk_source_face_boundary_retriangulation",
        "threshold_cross_squared_m4": GODOT_DEGENERATE_CROSS_SQUARED,
        "input_triangle_count": len(records),
        "output_triangle_count": len(output),
        "face_group_count": len(groups),
        "retriangulated_face_group_count": retriangulated_groups,
        "multiple_loop_face_group_count": multiple_loop_groups,
        "input_double_subthreshold_triangle_count": sum(
            quality <= GODOT_DEGENERATE_CROSS_SQUARED for quality in before_double
        ),
        "input_float32_subthreshold_triangle_count": sum(
            quality <= GODOT_DEGENERATE_CROSS_SQUARED for quality in before_float
        ),
        "output_double_subthreshold_triangle_count": sum(
            quality <= GODOT_DEGENERATE_CROSS_SQUARED for quality in after_double
        ),
        "output_float32_subthreshold_triangle_count": sum(
            quality <= GODOT_DEGENERATE_CROSS_SQUARED for quality in after_float
        ),
        "input_minimum_double_cross_squared_m4": min(before_double, default=math.inf),
        "input_minimum_float32_cross_squared_m4": min(before_float, default=math.inf),
        "output_minimum_double_cross_squared_m4": min(after_double, default=math.inf),
        "output_minimum_float32_cross_squared_m4": min(after_float, default=math.inf),
        "input_bad_face_group_count": len(before_bad_keys),
        "output_bad_face_group_count": len(after_bad_keys),
        "surface_area_before_m2": input_area,
        "surface_area_after_m2": output_area,
        "surface_area_absolute_delta_m2": abs(output_area - input_area),
        "largest_face_group_area_delta_m2": largest_group_area_delta,
        "vertex_coordinates_moved": False,
        "vertices_created": False,
        "provenance_face_groups_preserved": True,
    }


def _packet_degeneracy_analysis(
    packets: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    double_values: list[float] = []
    float_values: list[float] = []
    examples: list[dict[str, Any]] = []
    for packet_index, packet in enumerate(packets):
        vertices = np.asarray(packet.get("vertices", []), dtype=np.float64)
        coordinate = [int(value) for value in packet.get("chunk_coordinate", [])]
        for triangle_index, triangle in enumerate(packet.get("triangles", [])):
            points = vertices[[int(index) for index in triangle["indices"]]]
            double_quality = _triangle_cross_squared(points, np.float64)
            float_quality = _triangle_cross_squared(points, np.float32)
            double_values.append(double_quality)
            float_values.append(float_quality)
            if min(double_quality, float_quality) > GODOT_DEGENERATE_CROSS_SQUARED:
                continue
            edge_lengths = [
                float(np.linalg.norm(points[(index + 1) % 3] - points[index]))
                for index in range(3)
            ]
            longest_edge = max(edge_lengths)
            double_area = math.sqrt(max(0.0, double_quality))
            minimum_altitude = double_area / longest_edge if longest_edge > 0.0 else 0.0
            required_double_area = math.sqrt(GODOT_DEGENERATE_CROSS_SQUARED)
            minimum_single_vertex_displacement = (
                max(0.0, required_double_area - double_area) / longest_edge
                if longest_edge > 0.0
                else math.inf
            )
            float_points = np.asarray(points, dtype=np.float32)
            float_unique_vertices = len(
                {
                    tuple(float(component) for component in point)
                    for point in float_points
                }
            )
            if len(examples) < 100:
                examples.append(
                    {
                        "packet_index": packet_index,
                        "chunk_coordinate": coordinate,
                        "triangle_index": triangle_index,
                        "source_original_id": int(triangle["source_original_id"]),
                        "source_face_id": int(triangle["source_face_id"]),
                        "double_cross_squared_m4": double_quality,
                        "float32_cross_squared_m4": float_quality,
                        "shortest_edge_m": min(edge_lengths),
                        "longest_edge_m": longest_edge,
                        "minimum_altitude_m": minimum_altitude,
                        "float32_vertex_collapse": float_unique_vertices < 3,
                        "minimum_single_vertex_displacement_lower_bound_m": (
                            minimum_single_vertex_displacement
                        ),
                        "origin_classification": (
                            "boolean_or_chunk_split_clipped_organic_source_face"
                        ),
                    }
                )
    return {
        "threshold_cross_squared_m4": GODOT_DEGENERATE_CROSS_SQUARED,
        "triangle_count": len(double_values),
        "double_subthreshold_triangle_count": sum(
            value <= GODOT_DEGENERATE_CROSS_SQUARED for value in double_values
        ),
        "float32_subthreshold_triangle_count": sum(
            value <= GODOT_DEGENERATE_CROSS_SQUARED for value in float_values
        ),
        "minimum_double_cross_squared_m4": min(double_values, default=math.inf),
        "minimum_float32_cross_squared_m4": min(float_values, default=math.inf),
        "maximum_minimum_single_vertex_displacement_lower_bound_m": max(
            (
                float(example["minimum_single_vertex_displacement_lower_bound_m"])
                for example in examples
            ),
            default=0.0,
        ),
        "subthreshold_examples": examples,
        "passed": not examples,
    }


def _strict_weld_normalize(
    solid: Any,
    quantum: float = GODOT_STRICT_WELD_QUANTUM,
) -> tuple[Any, dict[str, Any]]:
    """Apply the established Godot strict-weld topology relation to a solid.

    Original property coordinates are copied verbatim. Triangles whose three
    vertices collapse under the strict-weld key are removed, and Mesh64 merge
    relations identify coincident topology vertices. This removes numerical
    Boolean slivers without grid-snapping the organic surface.
    """
    vertices, triangles, source_ids, face_ids = _triangle_records(solid)
    records: list[tuple[int, int, Any]] = []
    collapsed_triangle_count = 0
    for triangle_index, triangle in enumerate(triangles):
        points = vertices[triangle].copy()
        keys = [_canonical_point(point, quantum) for point in points]
        if len(set(keys)) < 3:
            collapsed_triangle_count += 1
            continue
        records.append(
            (
                int(source_ids[triangle_index]),
                int(face_ids[triangle_index]),
                points,
            )
        )
    records.sort(key=lambda item: (item[0], item[1]))
    property_vertices: list[list[float]] = []
    output_triangles: list[list[int]] = []
    output_face_ids: list[int] = []
    run_indices = [0]
    run_ids: list[int] = []
    current_source: int | None = None
    for source_id, face_id, points in records:
        if source_id != current_source:
            if current_source is not None:
                run_indices.append(len(output_triangles) * 3)
            run_ids.append(source_id)
            current_source = source_id
        offset = len(property_vertices)
        property_vertices.extend(
            [[float(value) for value in point] for point in points]
        )
        output_triangles.append([offset, offset + 1, offset + 2])
        output_face_ids.append(face_id)
    run_indices.append(len(output_triangles) * 3)

    representatives: dict[tuple[int, int, int], int] = {}
    merge_from: list[int] = []
    merge_to: list[int] = []
    for vertex_index, point in enumerate(property_vertices):
        key = _canonical_point(point, quantum)
        if key in representatives:
            merge_from.append(vertex_index)
            merge_to.append(representatives[key])
        else:
            representatives[key] = vertex_index
    mesh = manifold3d.Mesh64(
        np.asarray(property_vertices, dtype=np.float64),
        np.asarray(output_triangles, dtype=np.uint64),
        merge_from_vert=np.asarray(merge_from, dtype=np.uint64),
        merge_to_vert=np.asarray(merge_to, dtype=np.uint64),
        run_index=np.asarray(run_indices, dtype=np.uint64),
        run_original_id=np.asarray(run_ids, dtype=np.uint32),
        face_id=np.asarray(output_face_ids, dtype=np.uint64),
        tolerance=0.0,
    )
    normalized = manifold3d.Manifold(mesh)
    _require(
        _is_ok(normalized) and len(normalized.decompose()) == 1,
        f"strict-weld normalization failed: {_status_name(normalized)}",
    )
    comparison = _compare_solids(normalized, solid)
    _assert_comparison(comparison, "strict-weld normalized solid")
    return normalized, {
        "quantum_meters": quantum,
        "input_triangle_count": len(triangles),
        "collapsed_triangle_count": collapsed_triangle_count,
        "output_triangle_count": int(normalized.num_tri()),
        "merge_relation_count": len(merge_from),
        "input_property_coordinates_rewritten": False,
        "topology_merge_relations_only": True,
        "comparison_to_pre_normalized_solid": comparison,
    }


def _coordinate_sort_key(coordinate: tuple[int, int, int]) -> tuple[int, int, int]:
    return coordinate


def _coordinates_for_bounds(bounds: Sequence[float], halo: int = 0) -> set[tuple[int, int, int]]:
    spans = [
        range(span.start - halo, span.stop + halo)
        for span in (
            _chunk_span(float(bounds[0]), float(bounds[3])),
            _chunk_span(float(bounds[1]), float(bounds[4])),
            _chunk_span(float(bounds[2]), float(bounds[5])),
        )
    ]
    return {
        (x, y, z)
        for x in spans[0]
        for y in spans[1]
        for z in spans[2]
    }


def _source_id_for_triangle(run_ids: Sequence[int], run_index: Sequence[int], triangle_index: int) -> int:
    flat_index = triangle_index * 3
    for run in range(len(run_ids)):
        if run_index[run] <= flat_index < run_index[run + 1]:
            return int(run_ids[run])
    raise ProofFailure(f"triangle {triangle_index} is outside all provenance runs")


def _publication_packets(
    state: WorkpieceState,
    organic_ids: set[int],
    *,
    quality_normalize: bool = True,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    labelled_records: list[tuple[tuple[int, int, int], int, int, Any]] = []
    input_triangle_count = 0
    source_organic_triangle_count = 0
    compiler_cap_triangle_count = 0
    for coordinate in sorted(state.fragments, key=_coordinate_sort_key):
        fragment = state.fragments[coordinate]
        vertices, triangles, source_ids, face_ids = _triangle_records(fragment.manifold)
        input_triangle_count += len(triangles)
        for triangle_index, triangle in enumerate(triangles):
            source_id = int(source_ids[triangle_index])
            if source_id not in organic_ids:
                compiler_cap_triangle_count += 1
                continue
            source_organic_triangle_count += 1
            labelled_records.append(
                (
                    coordinate,
                    source_id,
                    int(face_ids[triangle_index]),
                    vertices[triangle].copy(),
                )
            )

    conforming_records, conforming_diagnostics = _make_triangle_soup_conforming(
        labelled_records
    )
    if quality_normalize:
        publication_records, float_publication_diagnostics = (
            _quality_retriangulate_publication_records(conforming_records)
        )
    else:
        publication_records = conforming_records
        float_publication_diagnostics = {
            "method": "skipped_in_local_prototype_transaction",
            "outside_prototype_transaction_timing": True,
            "vertex_coordinates_moved": False,
            "provenance_face_groups_preserved": True,
        }
    records_by_coordinate: dict[
        tuple[int, int, int], list[tuple[int, int, Any]]
    ] = {}
    for coordinate, source_id, face_id, points in publication_records:
        records_by_coordinate.setdefault(coordinate, []).append(
            (int(source_id), int(face_id), points)
        )

    packets: list[dict[str, Any]] = []
    for coordinate in sorted(records_by_coordinate):
        vertex_map: dict[tuple[float, float, float], int] = {}
        packet_vertices: list[list[float]] = []
        packet_triangles: list[dict[str, Any]] = []
        for source_id, face_id, points in records_by_coordinate[coordinate]:
            remapped: list[int] = []
            for point in points:
                key = (float(point[0]), float(point[1]), float(point[2]))
                if key not in vertex_map:
                    vertex_map[key] = len(packet_vertices)
                    packet_vertices.append(list(key))
                remapped.append(vertex_map[key])
            packet_triangles.append(
                {
                    "indices": remapped,
                    "source_original_id": source_id,
                    "source_face_id": face_id,
                }
            )
        packet = {
            "chunk_coordinate": list(coordinate),
            "coordinate_units": "meters",
            "geometry_law": "exact_organic_surface_grid_is_spatial_ownership_only",
            "vertices": packet_vertices,
            "triangles": packet_triangles,
            "compiler_cap_triangles_published": 0,
        }
        canonical = json.dumps(
            packet, sort_keys=True, separators=(",", ":"), ensure_ascii=True
        )
        packet["canonical_sha256"] = _sha256_bytes(canonical.encode("ascii"))
        packets.append(packet)

    counters: dict[str, Any] = {
        "fragment_count": len(state.fragments),
        "organic_source_triangles": source_organic_triangle_count,
        "organic_triangles": len(publication_records),
        "compiler_cap_triangles": compiler_cap_triangle_count,
        "input_triangles": input_triangle_count,
        "published_cap_triangles": 0,
        "conforming_added_triangles": (
            len(conforming_records) - source_organic_triangle_count
        ),
        "conforming_seam_refinement": conforming_diagnostics,
        "derived_float_publication_normalization": float_publication_diagnostics,
    }
    _require(counters["published_cap_triangles"] == 0, "compiler cap was included in publication")
    return packets, counters


def _packet_global_topology(
    packets: Sequence[Mapping[str, Any]],
    quantum: float = SEAM_QUANTUM,
) -> dict[str, Any]:
    """Analyze organic publication after welding exact chunk-boundary vertices."""
    edge_counts: dict[tuple[Any, Any], int] = {}
    directed_counts: dict[tuple[Any, Any], int] = {}
    triangle_count = 0
    for packet in packets:
        vertices = packet.get("vertices", [])
        for triangle in packet.get("triangles", []):
            indices = triangle["indices"]
            points = [_canonical_point(vertices[int(index)], quantum) for index in indices]
            triangle_count += 1
            for start, end in ((points[0], points[1]), (points[1], points[2]), (points[2], points[0])):
                undirected = tuple(sorted((start, end)))
                edge_counts[undirected] = edge_counts.get(undirected, 0) + 1
                directed_counts[(start, end)] = directed_counts.get((start, end), 0) + 1
    boundary_edges = sum(1 for value in edge_counts.values() if value == 1)
    nonmanifold_edges = sum(1 for value in edge_counts.values() if value != 2)
    directed_mismatches = 0
    for first, second in edge_counts:
        if edge_counts[(first, second)] == 2:
            forward = directed_counts.get((first, second), 0)
            backward = directed_counts.get((second, first), 0)
            if forward != 1 or backward != 1:
                directed_mismatches += 1
    return {
        "quantization_meters": quantum,
        "triangle_count": triangle_count,
        "unique_edge_count": len(edge_counts),
        "boundary_edge_count": boundary_edges,
        "nonmanifold_edge_count": nonmanifold_edges,
        "directed_mismatch_edge_count": directed_mismatches,
    }


def _packet_plane_seam_analysis(
    packets: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    face_edges: dict[
        tuple[tuple[int, int, int], int, int], set[tuple[Any, Any]]
    ] = {}
    for packet in packets:
        coordinate = tuple(int(value) for value in packet["chunk_coordinate"])
        vertices = packet["vertices"]
        local_counts: dict[tuple[Any, Any], int] = {}
        raw_by_key: dict[Any, Sequence[float]] = {}
        for triangle in packet["triangles"]:
            points = [vertices[int(index)] for index in triangle["indices"]]
            keys = [_canonical_point(point, 1.0e-7) for point in points]
            for key, point in zip(keys, points):
                raw_by_key.setdefault(key, point)
            for start, end in ((keys[0], keys[1]), (keys[1], keys[2]), (keys[2], keys[0])):
                edge = tuple(sorted((start, end)))
                local_counts[edge] = local_counts.get(edge, 0) + 1
        for edge, count in local_counts.items():
            if count != 1:
                continue
            raw_start = raw_by_key[edge[0]]
            raw_end = raw_by_key[edge[1]]
            matched_face = False
            for axis in range(3):
                for side in (-1, 1):
                    plane = (
                        coordinate[axis]
                        if side < 0
                        else coordinate[axis] + 1
                    ) * CHUNK_SIZE_METERS
                    if (
                        abs(float(raw_start[axis]) - plane) <= 1.0e-7
                        and abs(float(raw_end[axis]) - plane) <= 1.0e-7
                    ):
                        face_edges.setdefault((coordinate, axis, side), set()).add(edge)
                        matched_face = True
            _require(matched_face, f"published boundary edge is not on a chunk plane: {edge}")

    checked: set[tuple[tuple[int, int, int], int, int]] = set()
    mismatch_examples: list[str] = []
    unpaired_examples: list[str] = []
    pair_count = 0
    for key, edges in face_edges.items():
        if key in checked:
            continue
        coordinate, axis, side = key
        neighbor = list(coordinate)
        neighbor[axis] += side
        other_key = (tuple(neighbor), axis, -side)
        other_edges = face_edges.get(other_key)
        checked.add(key)
        if other_edges is None:
            unpaired_examples.append(str(key))
            continue
        checked.add(other_key)
        pair_count += 1
        if edges != other_edges:
            mismatch_examples.append(f"{key}<->{other_key}")
    return {
        "quantization_meters": 1.0e-7,
        "face_count": len(face_edges),
        "paired_face_count": pair_count,
        "unpaired_face_count": len(unpaired_examples),
        "mismatched_face_count": len(mismatch_examples),
        "unpaired_examples": unpaired_examples[:20],
        "mismatch_examples": mismatch_examples[:20],
        "passed": not unpaired_examples and not mismatch_examples,
    }


def _triangle_cap_face(
    coordinate: tuple[int, int, int],
    points: Any,
) -> tuple[int, int] | None:
    """Return (axis, side), where side is -1 (chunk min) or +1 (max)."""
    for axis in range(3):
        low = coordinate[axis] * CHUNK_SIZE_METERS
        high = (coordinate[axis] + 1) * CHUNK_SIZE_METERS
        values = points[:, axis]
        if bool(np.all(np.abs(values - low) <= PLANE_EPSILON * 20.0)):
            return axis, -1
        if bool(np.all(np.abs(values - high) <= PLANE_EPSILON * 20.0)):
            return axis, 1
    return None


def _cap_groups(
    fragments: Mapping[tuple[int, int, int], Fragment],
    organic_ids: set[int],
) -> dict[tuple[tuple[int, int, int], int, int], dict[str, Any]]:
    groups: dict[tuple[tuple[int, int, int], int, int], dict[str, Any]] = {}
    for coordinate, fragment in fragments.items():
        vertices, triangles, source_ids, _face_ids = _triangle_records(fragment.manifold)
        for triangle_index, triangle in enumerate(triangles):
            if source_ids[triangle_index] in organic_ids:
                continue
            points = vertices[triangle]
            face = _triangle_cap_face(coordinate, points)
            _require(face is not None, f"compiler-cap triangle is not on a chunk boundary in {coordinate}")
            axis, side = face
            key = (coordinate, axis, side)
            group = groups.setdefault(key, {"triangles": [], "area": 0.0, "normal_sum": 0.0})
            projected = [
                tuple(
                    _canonical_number(float(point[component]), SEAM_QUANTUM)
                    for component in range(3)
                    if component != axis
                )
                for point in points
            ]
            group["triangles"].append(projected)
            normal = np.cross(points[1] - points[0], points[2] - points[0])
            double_area = float(np.linalg.norm(normal))
            group["area"] += 0.5 * double_area
            if double_area > 0.0:
                group["normal_sum"] += float(normal[axis] / double_area) * 0.5 * double_area
    return groups


def _cap_outline_signature(group: Mapping[str, Any]) -> tuple[Any, ...]:
    edge_counts: dict[tuple[Any, Any], int] = {}
    for points in group["triangles"]:
        for start, end in ((points[0], points[1]), (points[1], points[2]), (points[2], points[0])):
            edge = tuple(sorted((start, end)))
            edge_counts[edge] = edge_counts.get(edge, 0) + 1
    boundary_edges = {edge for edge, count in edge_counts.items() if count % 2 == 1}
    adjacency: dict[Any, set[Any]] = {}
    for start, end in boundary_edges:
        adjacency.setdefault(start, set()).add(end)
        adjacency.setdefault(end, set()).add(start)
    _require(
        all(len(neighbors) == 2 for neighbors in adjacency.values()),
        "compiler-cap outline is not a collection of closed loops",
    )

    remaining = set(boundary_edges)
    loops: list[tuple[Any, ...]] = []
    while remaining:
        first_edge = min(remaining)
        start, current = first_edge
        previous = start
        points = [start, current]
        remaining.remove(first_edge)
        while current != start:
            candidates = sorted(neighbor for neighbor in adjacency[current] if neighbor != previous)
            _require(bool(candidates), "compiler-cap loop traversal stopped early")
            following = candidates[0]
            edge = tuple(sorted((current, following)))
            if following != start:
                _require(edge in remaining, "compiler-cap outline contains an overlapping loop")
                remaining.remove(edge)
                points.append(following)
            else:
                remaining.discard(edge)
            previous, current = current, following

        # Paired recursive splits may introduce a different number of vertices on
        # the same straight outline segment. Collapse split-only intermediate
        # points within one 10 nm comparison quantum, preserving larger organic
        # bends and staying ten times tighter than the 1e-7 m seam gate.
        changed = True
        while changed and len(points) >= 3:
            changed = False
            simplified: list[Any] = []
            point_count = len(points)
            for index, point in enumerate(points):
                before = points[(index - 1) % point_count]
                after = points[(index + 1) % point_count]
                first = (point[0] - before[0], point[1] - before[1])
                second = (after[0] - point[0], after[1] - point[1])
                cross = first[0] * second[1] - first[1] * second[0]
                dot = first[0] * second[0] + first[1] * second[1]
                chord = (after[0] - before[0], after[1] - before[1])
                chord_length = math.hypot(chord[0], chord[1])
                # One quantization unit is the declared seam-comparison
                # uncertainty.  This removes a split-only point no farther than
                # that from the same straight segment; larger organic bends stay.
                collinear_within_quantum = (
                    chord_length > 0.0 and abs(cross) / chord_length <= 1.0
                )
                if collinear_within_quantum and dot >= 0:
                    changed = True
                    continue
                simplified.append(point)
            _require(len(simplified) >= 3, "compiler-cap loop collapsed below three points")
            points = simplified

        rotations = [tuple(points[offset:] + points[:offset]) for offset in range(len(points))]
        reversed_points = list(reversed(points))
        rotations.extend(
            tuple(reversed_points[offset:] + reversed_points[:offset])
            for offset in range(len(reversed_points))
        )
        loops.append(min(rotations))
    return tuple(sorted(loops))


def _paired_cap_analysis(
    fragments: Mapping[tuple[int, int, int], Fragment],
    organic_ids: set[int],
) -> dict[str, Any]:
    groups = _cap_groups(fragments, organic_ids)
    checked: set[tuple[tuple[int, int, int], int, int]] = set()
    pairs = 0
    unpaired: list[str] = []
    outline_mismatches: list[str] = []
    orientation_mismatches: list[str] = []
    maximum_area_delta = 0.0
    for key, group in groups.items():
        if key in checked:
            continue
        coordinate, axis, side = key
        neighbor = list(coordinate)
        neighbor[axis] += side
        other_key = (tuple(neighbor), axis, -side)
        other = groups.get(other_key)
        checked.add(key)
        if other is None:
            unpaired.append(str(key))
            continue
        checked.add(other_key)
        pairs += 1
        if _cap_outline_signature(group) != _cap_outline_signature(other):
            outline_mismatches.append(f"{key}<->{other_key}")
        area_delta = abs(float(group["area"]) - float(other["area"]))
        maximum_area_delta = max(maximum_area_delta, area_delta)
        if float(group["normal_sum"]) * float(other["normal_sum"]) >= 0.0:
            orientation_mismatches.append(f"{key}<->{other_key}")
    return {
        "cap_group_count": len(groups),
        "paired_cap_count": pairs,
        "unpaired_cap_count": len(unpaired),
        "unpaired_caps": unpaired[:20],
        "outline_mismatch_count": len(outline_mismatches),
        "outline_mismatches": outline_mismatches[:20],
        "orientation_mismatch_count": len(orientation_mismatches),
        "orientation_mismatches": orientation_mismatches[:20],
        "maximum_area_delta_m2": maximum_area_delta,
    }


def _perimeter_cap_signature(
    fragments: Mapping[tuple[int, int, int], Fragment],
    selected_coordinates: set[tuple[int, int, int]],
    organic_ids: set[int],
) -> dict[str, Any]:
    relevant_coordinates = {
        coordinate for coordinate in selected_coordinates if coordinate in fragments
    }
    for coordinate in tuple(relevant_coordinates):
        for axis in range(3):
            for side in (-1, 1):
                neighbor = list(coordinate)
                neighbor[axis] += side
                neighbor_coordinate = tuple(neighbor)
                if neighbor_coordinate in fragments:
                    relevant_coordinates.add(neighbor_coordinate)
    relevant_fragments = {
        coordinate: fragments[coordinate] for coordinate in relevant_coordinates
    }
    groups = _cap_groups(relevant_fragments, organic_ids)
    signature: dict[str, Any] = {}
    for (coordinate, axis, side), group in groups.items():
        if coordinate not in selected_coordinates:
            continue
        neighbor = list(coordinate)
        neighbor[axis] += side
        neighbor_coordinate = tuple(neighbor)
        if neighbor_coordinate in selected_coordinates or neighbor_coordinate not in fragments:
            continue
        key = f"{coordinate}:{axis}:{side}"
        signature[key] = {
            "outline": _cap_outline_signature(group),
            "area_q": _canonical_number(float(group["area"]), SEAM_AREA_TOLERANCE),
        }
    return signature


def _solid_summary(solid: Any) -> dict[str, Any]:
    components = solid.decompose() if not solid.is_empty() else []
    return {
        "status": _status_name(solid),
        "empty": bool(solid.is_empty()),
        "component_count": len(components),
        "component_genera": sorted(int(component.genus()) for component in components),
        "volume_m3": float(solid.volume()),
        "surface_area_m2": float(solid.surface_area()),
        "bounds": [float(value) for value in solid.bounding_box()] if not solid.is_empty() else [],
        "vertex_count": int(solid.num_vert()),
        "triangle_count": int(solid.num_tri()),
    }


def _bounds_delta(first: Sequence[float], second: Sequence[float]) -> float:
    if len(first) != len(second):
        return math.inf
    return max((abs(float(a) - float(b)) for a, b in zip(first, second)), default=0.0)


def _surface_samples(solid: Any, maximum: int = MAX_SURFACE_SAMPLES) -> Any:
    vertices, triangles, _source_ids, _face_ids = _triangle_records(solid)
    points: list[Any] = [vertices]
    tri_points = vertices[triangles]
    points.append(tri_points.mean(axis=1))
    points.append((tri_points[:, 0] + tri_points[:, 1]) * 0.5)
    points.append((tri_points[:, 1] + tri_points[:, 2]) * 0.5)
    points.append((tri_points[:, 2] + tri_points[:, 0]) * 0.5)
    samples = np.concatenate(points, axis=0)
    if len(samples) > maximum:
        indices = np.linspace(0, len(samples) - 1, maximum, dtype=np.int64)
        samples = samples[indices]
    return samples


def _point_segment_distance_squared(point: Any, starts: Any, ends: Any) -> Any:
    directions = ends - starts
    denominator = np.einsum("ij,ij->i", directions, directions)
    denominator = np.maximum(denominator, 1.0e-30)
    amount = np.einsum("ij,ij->i", point - starts, directions) / denominator
    amount = np.clip(amount, 0.0, 1.0)
    closest = starts + directions * amount[:, None]
    delta = closest - point
    return np.einsum("ij,ij->i", delta, delta)


def _point_mesh_distance(point: Any, vertices: Any, triangles: Any) -> float:
    tri = vertices[triangles]
    a = tri[:, 0]
    b = tri[:, 1]
    c = tri[:, 2]
    ab = b - a
    ac = c - a
    normals = np.cross(ab, ac)
    normal_squared = np.einsum("ij,ij->i", normals, normals)
    safe_normal_squared = np.maximum(normal_squared, 1.0e-30)
    plane_amount = np.einsum("ij,ij->i", a - point, normals) / safe_normal_squared
    projected = point + normals * plane_amount[:, None]
    v2 = projected - a
    dot00 = np.einsum("ij,ij->i", ab, ab)
    dot01 = np.einsum("ij,ij->i", ab, ac)
    dot11 = np.einsum("ij,ij->i", ac, ac)
    dot20 = np.einsum("ij,ij->i", v2, ab)
    dot21 = np.einsum("ij,ij->i", v2, ac)
    denominator = dot00 * dot11 - dot01 * dot01
    safe_denominator = np.where(np.abs(denominator) > 1.0e-30, denominator, 1.0)
    bary_b = (dot11 * dot20 - dot01 * dot21) / safe_denominator
    bary_c = (dot00 * dot21 - dot01 * dot20) / safe_denominator
    inside = (
        (np.abs(denominator) > 1.0e-30)
        & (bary_b >= -1.0e-12)
        & (bary_c >= -1.0e-12)
        & (bary_b + bary_c <= 1.0 + 1.0e-12)
    )
    plane_delta = projected - point
    plane_distance = np.einsum("ij,ij->i", plane_delta, plane_delta)
    edge_distance = np.minimum(
        _point_segment_distance_squared(point, a, b),
        np.minimum(
            _point_segment_distance_squared(point, b, c),
            _point_segment_distance_squared(point, c, a),
        ),
    )
    distances = np.where(inside, plane_distance, edge_distance)
    return math.sqrt(max(0.0, float(distances.min())))


def _directed_sampled_surface_distance(source: Any, target: Any) -> float:
    samples = _surface_samples(source)
    target_vertices, target_triangles, _source_ids, _face_ids = _triangle_records(target)
    maximum = 0.0
    for point in samples:
        maximum = max(maximum, _point_mesh_distance(point, target_vertices, target_triangles))
    return maximum


def _compare_solids(actual: Any, oracle: Any) -> dict[str, Any]:
    actual_summary = _solid_summary(actual)
    oracle_summary = _solid_summary(oracle)
    first_difference = actual - oracle
    second_difference = oracle - actual
    _require(_is_ok(first_difference) and _is_ok(second_difference), "symmetric difference failed")
    symmetric_difference_volume = float(first_difference.volume() + second_difference.volume())
    forward_distance = _directed_sampled_surface_distance(actual, oracle)
    reverse_distance = _directed_sampled_surface_distance(oracle, actual)
    max_distance = max(forward_distance, reverse_distance)
    volume_delta = abs(actual_summary["volume_m3"] - oracle_summary["volume_m3"])
    volume_tolerance = max(5.0e-10, float(oracle_summary["volume_m3"]) * 1.0e-4)
    return {
        "actual": actual_summary,
        "oracle": oracle_summary,
        "status_matches": actual_summary["status"] == oracle_summary["status"],
        "component_count_matches": actual_summary["component_count"] == oracle_summary["component_count"],
        "genus_matches": actual_summary["component_genera"] == oracle_summary["component_genera"],
        "bounds_max_delta_m": _bounds_delta(actual_summary["bounds"], oracle_summary["bounds"]),
        "volume_absolute_delta_m3": volume_delta,
        "volume_tolerance_m3": volume_tolerance,
        "symmetric_difference_volume_m3": symmetric_difference_volume,
        "sampled_surface_forward_m": forward_distance,
        "sampled_surface_reverse_m": reverse_distance,
        "sampled_surface_max_m": max_distance,
        "surface_sampling_note": (
            "deterministic vertices/centroids/edge-midpoints to exact target triangles; "
            "diagnostic sampled bound, not an analytic Hausdorff proof"
        ),
    }


def _assert_comparison(comparison: Mapping[str, Any], label: str) -> None:
    _require(bool(comparison["status_matches"]), f"{label}: status differs from oracle")
    _require(bool(comparison["component_count_matches"]), f"{label}: component count differs")
    _require(bool(comparison["genus_matches"]), f"{label}: genus differs")
    _require(float(comparison["bounds_max_delta_m"]) <= BOUNDS_TOLERANCE, f"{label}: bounds differ")
    _require(
        float(comparison["volume_absolute_delta_m3"]) <= float(comparison["volume_tolerance_m3"]),
        f"{label}: volume differs",
    )
    _require(
        float(comparison["symmetric_difference_volume_m3"]) <= float(comparison["volume_tolerance_m3"]),
        f"{label}: symmetric difference is too large",
    )
    _require(
        float(comparison["sampled_surface_max_m"]) <= SURFACE_DISTANCE_TOLERANCE,
        f"{label}: sampled surface differs",
    )


def _fragment_map_geometry_equivalence(
    first: Mapping[tuple[int, int, int], Fragment],
    second: Mapping[tuple[int, int, int], Fragment],
) -> dict[str, Any]:
    first_coordinates = set(first)
    second_coordinates = set(second)
    coordinate_match = first_coordinates == second_coordinates
    mismatches: list[dict[str, Any]] = []
    maximum_symmetric_difference = 0.0
    for coordinate in sorted(first_coordinates & second_coordinates):
        comparison = _compare_solids(
            first[coordinate].manifold,
            second[coordinate].manifold,
        )
        passed = all(_comparison_gate_summary(comparison).values())
        maximum_symmetric_difference = max(
            maximum_symmetric_difference,
            float(comparison["symmetric_difference_volume_m3"]),
        )
        if not passed:
            mismatches.append(
                {
                    "coordinate": list(coordinate),
                    "comparison": comparison,
                }
            )
    return {
        "coordinate_sets_equal": coordinate_match,
        "coordinate_count": len(first_coordinates & second_coordinates),
        "mismatch_count": len(mismatches),
        "mismatch_examples": mismatches[:4],
        "maximum_fragment_symmetric_difference_m3": maximum_symmetric_difference,
        "passed": coordinate_match and not mismatches,
    }


def _cap_geometry_signature(
    fragments: Mapping[tuple[int, int, int], Fragment],
    organic_ids: set[int],
) -> dict[str, Any]:
    signature: dict[str, Any] = {}
    for (coordinate, axis, side), group in _cap_groups(fragments, organic_ids).items():
        key = f"{coordinate}:{axis}:{side}"
        normal_sign = 1 if float(group["normal_sum"]) > 0.0 else -1
        signature[key] = {
            "outline": _cap_outline_signature(group),
            "area_q": _canonical_number(float(group["area"]), SEAM_AREA_TOLERANCE),
            "normal_sign": normal_sign,
        }
    return signature


def _packet_digest_map(
    packets: Sequence[Mapping[str, Any]],
) -> dict[tuple[int, int, int], str]:
    return {
        tuple(int(value) for value in packet["chunk_coordinate"]): str(
            packet["canonical_sha256"]
        )
        for packet in packets
    }


def _semantic_mesh_digest(solid: Any, organic_ids: set[int]) -> str:
    vertices, triangles, source_ids, face_ids = _triangle_records(solid)
    records: list[tuple[Any, ...]] = []
    for triangle_index, triangle in enumerate(triangles):
        points = [_canonical_point(vertices[int(vertex)]) for vertex in triangle]
        cycles = [tuple(points[offset:] + points[:offset]) for offset in range(3)]
        source: int | str = source_ids[triangle_index]
        face: int | str = face_ids[triangle_index]
        if source not in organic_ids:
            source = "COMPILER_CAP"
            face = "COMPILER_CAP"
        records.append((min(cycles), source, face))
    records.sort(key=lambda item: repr(item))
    return _sha256_bytes(
        json.dumps(records, ensure_ascii=True, separators=(",", ":")).encode("ascii")
    )


def _publication_digest(state: WorkpieceState, organic_ids: set[int]) -> str:
    packets, _counters = _publication_packets(state, organic_ids)
    compact = [
        (tuple(packet["chunk_coordinate"]), packet["canonical_sha256"])
        for packet in packets
    ]
    return _sha256_bytes(
        json.dumps(compact, ensure_ascii=True, separators=(",", ":")).encode("ascii")
    )


def _selected_fragment_signature(
    state: WorkpieceState,
    selected_space: set[tuple[int, int, int]],
    organic_ids: set[int],
) -> list[tuple[tuple[int, int, int], str]]:
    return [
        (coordinate, _semantic_mesh_digest(fragment.manifold, organic_ids))
        for coordinate, fragment in sorted(state.fragments.items())
        if coordinate in selected_space
    ]


def _remote_identity_snapshot(
    state: WorkpieceState,
    selected_space: set[tuple[int, int, int]],
) -> dict[tuple[int, int, int], tuple[int, str]]:
    return {
        coordinate: (id(fragment), fragment.digest)
        for coordinate, fragment in state.fragments.items()
        if coordinate not in selected_space
    }


def _verify_remote_identity(
    before: Mapping[tuple[int, int, int], tuple[int, str]],
    after: WorkpieceState,
) -> dict[str, Any]:
    missing: list[str] = []
    object_changes: list[str] = []
    digest_changes: list[str] = []
    for coordinate, (object_id, digest) in before.items():
        fragment = after.fragments.get(coordinate)
        if fragment is None:
            missing.append(str(coordinate))
            continue
        if id(fragment) != object_id:
            object_changes.append(str(coordinate))
        if fragment.digest != digest:
            digest_changes.append(str(coordinate))
    return {
        "remote_fragment_count": len(before),
        "missing_count": len(missing),
        "object_identity_change_count": len(object_changes),
        "digest_change_count": len(digest_changes),
        "missing": missing[:20],
        "object_identity_changes": object_changes[:20],
        "digest_changes": digest_changes[:20],
        "passed": not missing and not object_changes and not digest_changes,
    }


def _exhaustive_remote_identity_audit(
    before: WorkpieceState,
    after: WorkpieceState,
    selected_space: set[tuple[int, int, int]],
) -> dict[str, Any]:
    started = time.perf_counter_ns()
    snapshot = _remote_identity_snapshot(before, selected_space)
    result = _verify_remote_identity(snapshot, after)
    result["outside_prototype_transaction_timing"] = True
    result["audit_ms"] = (time.perf_counter_ns() - started) / 1.0e6
    return result


def _organic_provenance_analysis(
    solid: Any,
    source_triangle_counts: Mapping[int, int],
) -> dict[str, Any]:
    _vertices, _triangles, source_ids, face_ids = _triangle_records(solid)
    invalid_sources: list[int] = []
    invalid_faces: list[tuple[int, int]] = []
    counts: dict[str, int] = {}
    for source_id, face_id in zip(source_ids, face_ids):
        counts[str(source_id)] = counts.get(str(source_id), 0) + 1
        if source_id not in source_triangle_counts:
            invalid_sources.append(source_id)
        elif face_id < 0 or face_id >= int(source_triangle_counts[source_id]):
            invalid_faces.append((source_id, face_id))
    return {
        "triangle_counts_by_original_id": counts,
        "invalid_source_triangle_count": len(invalid_sources),
        "invalid_face_id_triangle_count": len(invalid_faces),
        "invalid_source_ids": sorted(set(invalid_sources)),
        "invalid_face_examples": [list(value) for value in invalid_faces[:20]],
        "passed": not invalid_sources and not invalid_faces,
    }


def _percentile(values: Sequence[float], percentile: float) -> float:
    _require(bool(values), "cannot calculate percentile of an empty sequence")
    ordered = sorted(float(value) for value in values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * percentile
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] * (1.0 - fraction) + ordered[upper] * fraction


def _edit_counter_template() -> dict[str, int]:
    return {
        "candidate_coordinate_count": 0,
        "selected_populated_fragment_count": 0,
        "pre_edit_populated_fragment_count": 0,
        "changed_fragment_count": 0,
        "post_edit_populated_fragment_count": 0,
        "assembled_triangle_count": 0,
        "boolean_output_triangle_count": 0,
        "organic_output_triangle_count": 0,
        "compiler_cap_output_triangle_count": 0,
        "remote_fragment_count": 0,
        "remote_rebuild_count": 0,
        "expansion_count": 0,
    }


def _regional_add(
    base_state: WorkpieceState,
    operand: Any,
    organic_ids: set[int],
    *,
    inject_failure_before_publish: bool = False,
    include_global_checks: bool = False,
) -> tuple[WorkpieceState, dict[str, Any]]:
    """Stage, validate, then atomically publish one exact regional union."""
    phase_ms: dict[str, float] = {}
    counters = _edit_counter_template()
    total_start = time.perf_counter_ns()

    phase_start = time.perf_counter_ns()
    selected_space = _coordinates_for_bounds(operand.bounding_box(), HALO_RINGS)
    selected_existing = {
        coordinate for coordinate in selected_space if coordinate in base_state.fragments
    }
    _require(bool(selected_existing), "operand halo does not select an existing fragment")
    before_perimeter = _perimeter_cap_signature(base_state.fragments, selected_space, organic_ids)
    phase_ms["region_selection_ms"] = (time.perf_counter_ns() - phase_start) / 1.0e6
    counters["candidate_coordinate_count"] = len(selected_space)
    counters["selected_populated_fragment_count"] = len(selected_existing)
    counters["pre_edit_populated_fragment_count"] = len(base_state.fragments)
    counters["remote_fragment_count"] = len(base_state.fragments) - len(selected_existing)

    phase_start = time.perf_counter_ns()
    assembled, assembly_diagnostics = _assemble_region_from_fragments(
        {
            coordinate: base_state.fragments[coordinate]
            for coordinate in selected_existing
        },
        organic_ids,
    )
    _require(not assembled.is_empty() and _is_ok(assembled), "regional assembly failed")
    phase_ms["assembly_ms"] = (time.perf_counter_ns() - phase_start) / 1.0e6
    counters["assembled_triangle_count"] = int(assembled.num_tri())

    phase_start = time.perf_counter_ns()
    region_result = assembled + operand
    _require(_is_ok(region_result), f"regional Boolean failed: {_status_name(region_result)}")
    _require(not region_result.is_empty(), "regional Boolean unexpectedly produced an empty solid")
    phase_ms["boolean_ms"] = (time.perf_counter_ns() - phase_start) / 1.0e6
    counters["boolean_output_triangle_count"] = int(region_result.num_tri())

    phase_start = time.perf_counter_ns()
    changed_fragments = _split_to_chunks(region_result)
    changed_coordinates = set(changed_fragments)
    _require(
        changed_coordinates <= selected_space,
        "regional result escaped the fixed two-ring jurisdiction; expansion would be required",
    )
    phase_ms["splitting_ms"] = (time.perf_counter_ns() - phase_start) / 1.0e6
    counters["changed_fragment_count"] = len(changed_fragments)

    phase_start = time.perf_counter_ns()
    proposed_fragments = FragmentOverlay(
        base_state.fragments,
        selected_existing,
        changed_fragments,
    )
    staged_state = WorkpieceState(proposed_fragments, base_state.revision + 1)
    after_perimeter = _perimeter_cap_signature(staged_state.fragments, selected_space, organic_ids)
    _require(
        before_perimeter == after_perimeter,
        "regional perimeter seam changed; fixed halo must reject and expand rather than publish",
    )
    counters["post_edit_populated_fragment_count"] = len(staged_state.fragments)
    counters["remote_rebuild_count"] = 0

    local_packets, local_publication_counters = _publication_packets(
        WorkpieceState(changed_fragments, staged_state.revision),
        organic_ids,
        quality_normalize=False,
    )
    local_topology = _packet_global_topology(local_packets)
    # A region's organic skin is intentionally open at its perimeter.  Full-state
    # watertightness is checked outside the timed locality path.
    counters["organic_output_triangle_count"] = int(local_publication_counters["organic_triangles"])
    counters["compiler_cap_output_triangle_count"] = int(local_publication_counters["compiler_cap_triangles"])
    local_validation = {
        "status": _status_name(region_result),
        "perimeter_signature_unchanged": True,
        "transaction_mapping": "persistent_local_overlay",
        "exhaustive_remote_identity_audit_timed": False,
        "published_cap_triangles": int(local_publication_counters["published_cap_triangles"]),
        "regional_organic_topology_diagnostic": local_topology,
    }
    if include_global_checks:
        packets, publication_counters = _publication_packets(staged_state, organic_ids)
        topology = _packet_global_topology(packets)
        godot_strict_topology = _packet_global_topology(
            packets, GODOT_STRICT_WELD_QUANTUM
        )
        plane_seams = _packet_plane_seam_analysis(packets)
        _require(
            topology["boundary_edge_count"] == 0
            and topology["nonmanifold_edge_count"] == 0
            and topology["directed_mismatch_edge_count"] == 0,
            "emitted organic fragment packets are not a closed oriented manifold",
        )
        _require(
            godot_strict_topology["boundary_edge_count"] == 0
            and godot_strict_topology["nonmanifold_edge_count"] == 0
            and godot_strict_topology["directed_mismatch_edge_count"] == 0,
            "emitted packets fail Godot's established 1e-7 m strict-weld topology",
        )
        _require(bool(plane_seams["passed"]), "emitted organic chunk-plane seams differ")
        welded_publication, welded_diagnostics = _assemble_region_from_fragments(
            staged_state.fragments, organic_ids
        )
        _require(_is_ok(welded_publication), "organic publication topology weld failed")
        local_validation["global_organic_pre_weld_edge_diagnostic"] = topology
        local_validation["global_emitted_packet_godot_strict_topology"] = (
            godot_strict_topology
        )
        local_validation["global_emitted_packet_plane_seams"] = plane_seams
        local_validation["global_organic_welded_assembly"] = welded_diagnostics
        local_validation["global_publication_counters"] = publication_counters
    phase_ms["validation_ms"] = (time.perf_counter_ns() - phase_start) / 1.0e6

    phase_start = time.perf_counter_ns()
    if inject_failure_before_publish:
        # Deliberate transaction abort: staged objects must never replace the
        # caller's state or increment its revision.
        raise ProofFailure("injected_pre_publish_failure")
    published_state = staged_state
    phase_ms["transaction_publish_ms"] = (time.perf_counter_ns() - phase_start) / 1.0e6
    phase_ms["prototype_transaction_ms"] = (time.perf_counter_ns() - total_start) / 1.0e6
    return published_state, {
        "phase_ms": phase_ms,
        "counters": counters,
        "assembly": assembly_diagnostics,
        "selected_coordinates": [list(value) for value in sorted(selected_existing)],
        "candidate_coordinates": [list(value) for value in sorted(selected_space)],
        "validation": local_validation,
    }


def _atomic_failure_probe(
    state: WorkpieceState,
    operand: Any,
    organic_ids: set[int],
) -> dict[str, Any]:
    original_revision = state.revision
    original_identity = {
        coordinate: (id(fragment), fragment.digest)
        for coordinate, fragment in state.fragments.items()
    }
    caught = ""
    try:
        _regional_add(
            state,
            operand,
            organic_ids,
            inject_failure_before_publish=True,
            include_global_checks=False,
        )
    except ProofFailure as error:
        caught = str(error)
    unchanged = state.revision == original_revision
    for coordinate, (object_id, digest) in original_identity.items():
        fragment = state.fragments.get(coordinate)
        unchanged = unchanged and fragment is not None
        if fragment is not None:
            unchanged = unchanged and id(fragment) == object_id and fragment.digest == digest
    passed = caught == "injected_pre_publish_failure" and unchanged
    _require(passed, "atomic failure probe mutated published state")
    return {
        "injected_failure_caught": caught == "injected_pre_publish_failure",
        "revision_unchanged": state.revision == original_revision,
        "fragment_objects_and_digests_unchanged": unchanged,
        "published_revision": state.revision,
        "passed": passed,
    }


def _timing_row(
    state_label: str,
    pair_index: int,
    order_in_pair: int,
    is_warmup: bool,
    metrics: Mapping[str, Any],
) -> dict[str, Any]:
    row: dict[str, Any] = {
        "state": state_label,
        "pair_index": pair_index,
        "order_in_pair": order_in_pair,
        "warmup": int(is_warmup),
    }
    row.update(metrics["phase_ms"])
    row.update(metrics["counters"])
    return row


def _run_paired_timings(
    young: WorkpieceState,
    mature: WorkpieceState,
    operand: Any,
    organic_ids: set[int],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    selected_space = _coordinates_for_bounds(operand.bounding_box(), HALO_RINGS)
    young_signature = _selected_fragment_signature(young, selected_space, organic_ids)
    mature_signature = _selected_fragment_signature(mature, selected_space, organic_ids)
    _require(young_signature == mature_signature, "young/mature selected pre-edit fragments are not identical")

    rows: list[dict[str, Any]] = []
    total_pairs = WARMUP_PAIRS + MEASURED_PAIRS
    for all_pair_index in range(total_pairs):
        is_warmup = all_pair_index < WARMUP_PAIRS
        pair_index = all_pair_index if is_warmup else all_pair_index - WARMUP_PAIRS
        order = (("young", young), ("mature", mature))
        if all_pair_index % 2 == 1:
            order = tuple(reversed(order))
        # Persistent mappings are immutable; a revision wrapper is sufficient and
        # does not copy or scan the mature fragment map.
        clones = {
            "young": WorkpieceState(young.fragments, young.revision),
            "mature": WorkpieceState(mature.fragments, mature.revision),
        }
        for order_index, (label, _source) in enumerate(order):
            _published, metrics = _regional_add(
                clones[label], operand, organic_ids, include_global_checks=False
            )
            rows.append(_timing_row(label, pair_index, order_index, is_warmup, metrics))

    measured = [row for row in rows if not row["warmup"]]
    young_total = [float(row["prototype_transaction_ms"]) for row in measured if row["state"] == "young"]
    mature_total = [float(row["prototype_transaction_ms"]) for row in measured if row["state"] == "mature"]
    _require(len(young_total) == MEASURED_PAIRS, "young timing sample count is wrong")
    _require(len(mature_total) == MEASURED_PAIRS, "mature timing sample count is wrong")

    young_by_pair = {int(row["pair_index"]): float(row["prototype_transaction_ms"]) for row in measured if row["state"] == "young"}
    mature_by_pair = {int(row["pair_index"]): float(row["prototype_transaction_ms"]) for row in measured if row["state"] == "mature"}
    paired_deltas = [mature_by_pair[index] - young_by_pair[index] for index in range(MEASURED_PAIRS)]
    young_p50 = _percentile(young_total, 0.50)
    young_p95 = _percentile(young_total, 0.95)
    mature_p50 = _percentile(mature_total, 0.50)
    mature_p95 = _percentile(mature_total, 0.95)
    ratio_p50 = mature_p50 / young_p50 if young_p50 > 0.0 else math.inf
    ratio_p95 = mature_p95 / young_p95 if young_p95 > 0.0 else math.inf
    paired_p95 = _percentile(paired_deltas, 0.95)
    paired_limit = max(2.0, young_p95 * 0.25)
    summary = {
        "warmup_pairs": WARMUP_PAIRS,
        "measured_pairs": MEASURED_PAIRS,
        "alternating_order": True,
        "metric_name": "prototype_transaction_ms",
        "scope": (
            "Python selection, exact regional assembly/Boolean/split, local validation, "
            "and persistent overlay publication"
        ),
        "explicitly_excluded": [
            "Godot render mesh construction",
            "Godot collision construction",
            "render/collision resource swap",
            "persistence",
            "exhaustive remote identity audit",
            "artifact serialization",
        ],
        "interactive_ready_latency_claimed": False,
        "selected_pre_edit_fragment_signature_equal": True,
        "selected_pre_edit_fragment_signature": [
            {"coordinate": list(coordinate), "digest": digest}
            for coordinate, digest in young_signature
        ],
        "young": {
            "p50_prototype_transaction_ms": young_p50,
            "p95_prototype_transaction_ms": young_p95,
            "mean_prototype_transaction_ms": statistics.fmean(young_total),
        },
        "mature": {
            "p50_prototype_transaction_ms": mature_p50,
            "p95_prototype_transaction_ms": mature_p95,
            "mean_prototype_transaction_ms": statistics.fmean(mature_total),
        },
        "mature_to_young_p50_ratio": ratio_p50,
        "mature_to_young_p95_ratio": ratio_p95,
        "paired_delta_p95_ms": paired_p95,
        "paired_delta_limit_ms": paired_limit,
        "p50_ratio_gate_passed": ratio_p50 <= 1.10,
        "p95_ratio_gate_passed": ratio_p95 <= 1.25,
        "paired_delta_gate_passed": paired_p95 <= paired_limit,
    }
    summary["passed"] = bool(
        summary["p50_ratio_gate_passed"]
        and summary["p95_ratio_gate_passed"]
        and summary["paired_delta_gate_passed"]
    )
    return rows, summary


def _canonical_input_hash(lines: Sequence[str]) -> str:
    return _sha256_bytes("\n".join(str(line) for line in lines).encode("utf-8"))


def _validate_fixture_hashes(fixture: Mapping[str, Any]) -> dict[str, Any]:
    packet_results: dict[str, Any] = {}
    for packet_name, packet in fixture["packets"].items():
        calculated = _canonical_input_hash(packet.get("canonical_sha256_inputs", []))
        expected = str(packet.get("canonical_sha256", ""))
        packet_results[packet_name] = {
            "expected": expected,
            "calculated": calculated,
            "matches": calculated == expected,
        }
        _require(calculated == expected, f"fixture packet canonical hash failed: {packet_name}")
    top_calculated = _canonical_input_hash(fixture.get("canonical_sha256_inputs", []))
    top_expected = str(fixture.get("canonical_sha256", ""))
    _require(top_calculated == top_expected, "fixture top-level canonical hash failed")
    return {
        "top_level": {
            "expected": top_expected,
            "calculated": top_calculated,
            "matches": True,
        },
        "packets": packet_results,
    }


def _consumed_geometry_hash(
    packet_name: str,
    packet: Mapping[str, Any],
) -> dict[str, Any]:
    """Canonicalize the numeric arrays this program actually consumes."""
    vertices = np.asarray(packet.get("vertices", []), dtype=np.float64)
    triangles = _packet_triangles(packet)
    lines = [
        "schema=forge_v2_consumed_geometry_v1",
        f"packet_name={packet_name}",
        "coordinate_units=meters",
        f"vertex_count={len(vertices)}",
        f"triangle_count={len(triangles)}",
    ]
    for index, vertex in enumerate(vertices):
        lines.append(
            "v[%d]=%s,%s,%s"
            % (
                index,
                float(vertex[0]).hex(),
                float(vertex[1]).hex(),
                float(vertex[2]).hex(),
            )
        )
    for index, triangle in enumerate(triangles):
        lines.append(
            "t[%d]=%d,%d,%d"
            % (index, int(triangle[0]), int(triangle[1]), int(triangle[2]))
        )
    return {
        "schema": "forge_v2_consumed_geometry_v1",
        "canonicalization": "UTF-8 LF lines; float64.hex vertices; uint64 triangle indices",
        "vertex_count": len(vertices),
        "triangle_count": len(triangles),
        "sha256": _canonical_input_hash(lines),
        "regenerated_from_consumed_vertices_and_triangles": True,
    }


def _consumed_fixture_hashes(fixture: Mapping[str, Any]) -> dict[str, Any]:
    packet_hashes = {
        packet_name: _consumed_geometry_hash(packet_name, fixture["packets"][packet_name])
        for packet_name in ("stroke_a", "stroke_b", "mature_extension")
    }
    top_lines = [
        f"{packet_name}={packet_hashes[packet_name]['sha256']}"
        for packet_name in ("stroke_a", "stroke_b", "mature_extension")
    ]
    return {
        "schema": "forge_v2_consumed_fixture_geometry_v1",
        "packets": packet_hashes,
        "sha256": _canonical_input_hash(top_lines),
        "regenerated_from_consumed_vertices_and_triangles": True,
    }


def _comparison_gate_summary(comparison: Mapping[str, Any]) -> dict[str, bool]:
    return {
        "status": bool(comparison["status_matches"]),
        "components": bool(comparison["component_count_matches"]),
        "genus": bool(comparison["genus_matches"]),
        "bounds": float(comparison["bounds_max_delta_m"]) <= BOUNDS_TOLERANCE,
        "volume": float(comparison["volume_absolute_delta_m3"]) <= float(comparison["volume_tolerance_m3"]),
        "symmetric_difference": float(comparison["symmetric_difference_volume_m3"]) <= float(comparison["volume_tolerance_m3"]),
        "sampled_surface": float(comparison["sampled_surface_max_m"]) <= SURFACE_DISTANCE_TOLERANCE,
    }


def _run_proof() -> tuple[dict[str, Any], list[dict[str, Any]]]:
    proof_started = time.perf_counter_ns()
    fixture, fixture_file_sha256 = _load_fixture()
    declared_fixture_hashes = _validate_fixture_hashes(fixture)
    consumed_geometry_hashes = _consumed_fixture_hashes(fixture)
    packets = fixture["packets"]

    first_original_id = int(manifold3d.Manifold.reserve_ids(3))
    packet_names = ("stroke_a", "stroke_b", "mature_extension")
    packet_solids: dict[str, PacketSolid] = {}
    for offset, packet_name in enumerate(packet_names):
        packet_solids[packet_name] = _make_packet_solid(
            packet_name, packets[packet_name], first_original_id + offset
        )
    stroke_a = packet_solids["stroke_a"]
    stroke_b = packet_solids["stroke_b"]
    extension = packet_solids["mature_extension"]
    organic_ids = {value.original_id for value in packet_solids.values()}
    partition_start = time.perf_counter_ns()
    young_fragments = _split_to_chunks(stroke_a.manifold)
    young_partition_ms = (time.perf_counter_ns() - partition_start) / 1.0e6
    young_state = WorkpieceState(young_fragments, 0)
    young_caps = _paired_cap_analysis(young_state.fragments, organic_ids)
    _require(young_caps["unpaired_cap_count"] == 0, "initial A partition has an unpaired cap")
    _require(young_caps["outline_mismatch_count"] == 0, "initial A partition has a cap-loop mismatch")
    _require(young_caps["orientation_mismatch_count"] == 0, "initial A partition cap winding is not opposite")
    _require(
        float(young_caps["maximum_area_delta_m2"]) <= SEAM_AREA_TOLERANCE,
        "initial A partition cap areas differ",
    )

    reconstructed_a, a_assembly_diagnostics = _assemble_region_from_fragments(
        young_state.fragments,
        organic_ids,
    )
    a_reconstruction_comparison = _compare_solids(reconstructed_a, stroke_a.manifold)
    _assert_comparison(a_reconstruction_comparison, "partitioned A reconstruction")

    monolithic_oracle = stroke_a.manifold + stroke_b.manifold
    _require(_is_ok(monolithic_oracle), "monolithic A+B oracle Boolean failed")
    _require(len(monolithic_oracle.decompose()) == 1, "monolithic A+B oracle is disconnected")
    _require(
        monolithic_oracle.volume() > stroke_a.manifold.volume(),
        "stroke B added no exterior volume to stroke A",
    )
    monolithic_provenance = _organic_provenance_analysis(
        monolithic_oracle,
        {
            stroke_a.original_id: stroke_a.triangle_count,
            stroke_b.original_id: stroke_b.triangle_count,
        },
    )
    _require(bool(monolithic_provenance["passed"]), "monolithic oracle lost A/B provenance")

    selected_space = _coordinates_for_bounds(stroke_b.manifold.bounding_box(), HALO_RINGS)
    selected_existing = set(young_state.fragments) & selected_space
    remote_coordinates = set(young_state.fragments) - selected_space
    _require(bool(remote_coordinates), "fixture has no remote A fragment outside B's two-ring halo")
    _require(bool(selected_existing), "fixture B does not select A")

    atomic_failure = _atomic_failure_probe(young_state, stroke_b.manifold, organic_ids)
    edited_young, edit_metrics = _regional_add(
        young_state,
        stroke_b.manifold,
        organic_ids,
        include_global_checks=True,
    )
    _require(edited_young.revision == 1, "successful regional edit did not increment revision exactly once")
    _require(int(edit_metrics["counters"]["remote_rebuild_count"]) == 0, "remote fragment was rebuilt")
    young_remote_identity = _exhaustive_remote_identity_audit(
        young_state, edited_young, selected_space
    )
    _require(bool(young_remote_identity["passed"]), "young remote identity audit failed")

    edited_caps = _paired_cap_analysis(edited_young.fragments, organic_ids)
    _require(edited_caps["unpaired_cap_count"] == 0, "edited partition has an unpaired cap")
    _require(edited_caps["outline_mismatch_count"] == 0, "edited partition has a cap-loop mismatch")
    _require(edited_caps["orientation_mismatch_count"] == 0, "edited partition cap winding is not opposite")
    _require(
        float(edited_caps["maximum_area_delta_m2"]) <= SEAM_AREA_TOLERANCE,
        "edited partition cap areas differ",
    )

    publication_packets, publication_counters = _publication_packets(edited_young, organic_ids)
    publication_topology = _packet_global_topology(publication_packets)
    publication_godot_strict_topology = _packet_global_topology(
        publication_packets, GODOT_STRICT_WELD_QUANTUM
    )
    publication_plane_seams = _packet_plane_seam_analysis(publication_packets)
    publication_degeneracy = _packet_degeneracy_analysis(publication_packets)
    _require(publication_counters["published_cap_triangles"] == 0, "publication contains a compiler cap")
    _require(
        publication_topology["boundary_edge_count"] == 0
        and publication_topology["nonmanifold_edge_count"] == 0
        and publication_topology["directed_mismatch_edge_count"] == 0,
        "actual emitted organic fragment packets are not watertight and oriented",
    )
    _require(
        publication_godot_strict_topology["boundary_edge_count"] == 0
        and publication_godot_strict_topology["nonmanifold_edge_count"] == 0
        and publication_godot_strict_topology["directed_mismatch_edge_count"] == 0,
        "actual emitted packets fail Godot's 1e-7 m strict-weld topology",
    )
    _require(bool(publication_plane_seams["passed"]), "actual emitted packet plane seams differ")

    regional_total, regional_assembly_diagnostics = _assemble_region_from_fragments(
        edited_young.fragments,
        organic_ids,
    )
    regional_comparison = _compare_solids(regional_total, monolithic_oracle)
    _assert_comparison(regional_comparison, "regional A+B reconstruction")
    regional_provenance = _organic_provenance_analysis(
        regional_total,
        {
            stroke_a.original_id: stroke_a.triangle_count,
            stroke_b.original_id: stroke_b.triangle_count,
        },
    )
    _require(bool(regional_provenance["passed"]), "regional reconstruction published cap provenance")

    deterministic_digests: list[str] = []
    for _replay in range(3):
        replay_state, _replay_metrics = _regional_add(
            young_state,
            stroke_b.manifold,
            organic_ids,
            include_global_checks=False,
        )
        deterministic_digests.append(_publication_digest(replay_state, organic_ids))
    _require(len(set(deterministic_digests)) == 1, "three clean regional replays were not deterministic")

    mature_build_start = time.perf_counter_ns()
    raw_mature_solid = stroke_a.manifold + extension.manifold
    _require(_is_ok(raw_mature_solid), "A+mature extension Boolean failed")
    _require(len(raw_mature_solid.decompose()) == 1, "mature extension is not connected to A")
    _require(
        raw_mature_solid.volume() > stroke_a.manifold.volume(),
        "mature extension added no volume",
    )
    mature_solid, mature_strict_weld_normalization = _strict_weld_normalize(
        raw_mature_solid,
        GODOT_STRICT_WELD_QUANTUM,
    )
    mature_boolean_ms = (time.perf_counter_ns() - mature_build_start) / 1.0e6
    mature_partition_start = time.perf_counter_ns()
    independently_partitioned_mature_fragments = _split_to_chunks(mature_solid)
    mature_partition_ms = (time.perf_counter_ns() - mature_partition_start) / 1.0e6

    # The age-sensitivity lane must have literally identical local inputs. Keep
    # the exact young Fragment objects in B's jurisdiction and graft only the
    # independently compiled mature remote region beyond it.
    young_local_coordinates = {
        coordinate for coordinate in selected_space if coordinate in young_state.fragments
    }
    independent_mature_local_coordinates = {
        coordinate
        for coordinate in selected_space
        if coordinate in independently_partitioned_mature_fragments
    }
    _require(
        young_local_coordinates == independent_mature_local_coordinates,
        "mature extension introduced material inside B's selected jurisdiction",
    )
    hybrid_mature_fragments = {
        coordinate: fragment
        for coordinate, fragment in independently_partitioned_mature_fragments.items()
        if coordinate not in selected_space
    }
    for coordinate in young_local_coordinates:
        hybrid_mature_fragments[coordinate] = young_state.fragments[coordinate]
    mature_state = WorkpieceState(hybrid_mature_fragments, 0)
    _require(
        len(mature_state.fragments) > len(young_state.fragments),
        "mature fixture did not add remote populated chunks",
    )
    identical_local_object_count = sum(
        1
        for coordinate in young_local_coordinates
        if mature_state.fragments[coordinate] is young_state.fragments[coordinate]
    )
    _require(
        identical_local_object_count == len(young_local_coordinates),
        "hybrid mature state did not retain exact young local Fragment objects",
    )
    mature_selected_signature = _selected_fragment_signature(mature_state, selected_space, organic_ids)
    young_selected_signature = _selected_fragment_signature(young_state, selected_space, organic_ids)
    _require(
        mature_selected_signature == young_selected_signature,
        "mature extension changed B's selected pre-edit fragments",
    )
    mature_caps = _paired_cap_analysis(mature_state.fragments, organic_ids)
    _require(mature_caps["unpaired_cap_count"] == 0, "mature partition has an unpaired cap")
    _require(mature_caps["outline_mismatch_count"] == 0, "mature partition has a cap-loop mismatch")
    _require(mature_caps["orientation_mismatch_count"] == 0, "mature partition cap winding is not opposite")
    _require(
        float(mature_caps["maximum_area_delta_m2"]) <= SEAM_AREA_TOLERANCE,
        "mature partition cap areas differ",
    )

    reconstructed_hybrid_mature, hybrid_mature_assembly = _assemble_region_from_fragments(
        mature_state.fragments, organic_ids
    )
    hybrid_mature_comparison = _compare_solids(reconstructed_hybrid_mature, mature_solid)
    _assert_comparison(
        hybrid_mature_comparison,
        "hybrid mature reconstruction against monolithic A+extension",
    )

    edited_mature, mature_edit_metrics = _regional_add(
        mature_state,
        stroke_b.manifold,
        organic_ids,
        include_global_checks=True,
    )
    mature_remote_identity = _exhaustive_remote_identity_audit(
        mature_state, edited_mature, selected_space
    )
    _require(bool(mature_remote_identity["passed"]), "mature remote identity audit failed")

    young_post_local = {
        coordinate: edited_young.fragments[coordinate]
        for coordinate in selected_space
        if coordinate in edited_young.fragments
    }
    mature_post_local = {
        coordinate: edited_mature.fragments[coordinate]
        for coordinate in selected_space
        if coordinate in edited_mature.fragments
    }
    post_storage_equivalence = _fragment_map_geometry_equivalence(
        young_post_local,
        mature_post_local,
    )
    _require(
        bool(post_storage_equivalence["passed"]),
        "young/mature post-edit selected storage geometry differs",
    )
    young_post_cap_signature = _cap_geometry_signature(young_post_local, organic_ids)
    mature_post_cap_signature = _cap_geometry_signature(mature_post_local, organic_ids)
    post_cap_seams_equal = young_post_cap_signature == mature_post_cap_signature
    _require(post_cap_seams_equal, "young/mature post-edit selected cap seams differ")

    young_post_packets, young_post_publication_counters = _publication_packets(
        WorkpieceState(young_post_local, edited_young.revision), organic_ids
    )
    mature_post_packets, mature_post_publication_counters = _publication_packets(
        WorkpieceState(mature_post_local, edited_mature.revision), organic_ids
    )
    young_post_packet_digests = _packet_digest_map(young_post_packets)
    mature_post_packet_digests = _packet_digest_map(mature_post_packets)
    exact_post_packet_match = young_post_packet_digests == mature_post_packet_digests
    post_cap_triangle_counts_equal = (
        young_post_publication_counters["compiler_cap_triangles"]
        == mature_post_publication_counters["compiler_cap_triangles"]
    )
    _require(
        post_cap_triangle_counts_equal,
        "young/mature identical local edits produced different compiler-cap counts",
    )
    # Exact packet hashes are expected for identical local objects. If a future
    # kernel emits an equivalent triangulation, only the independently proven
    # per-fragment solid equality plus identical jurisdiction-cap seams may admit
    # it; triangle counts alone never establish equivalence.
    post_publication_geometry_equivalent = exact_post_packet_match or (
        bool(post_storage_equivalence["passed"]) and post_cap_seams_equal
    )
    _require(
        post_publication_geometry_equivalent,
        "young/mature post-edit selected publication geometry differs",
    )
    post_equivalence_mode = (
        "exact_emitted_packet_hashes"
        if exact_post_packet_match
        else "canonical_per_fragment_solid_plus_jurisdiction_cap_seams"
    )

    setup_reasonable = (
        young_partition_ms + mature_boolean_ms + mature_partition_ms <= 30_000.0
        and len(mature_state.fragments) <= 2048
    )
    _require(setup_reasonable, "paired timing setup cost was unreasonable; timings were not run")
    timing_rows, timing_summary = _run_paired_timings(
        young_state, mature_state, stroke_b.manifold, organic_ids
    )

    input_details = {}
    for packet_name, packet_solid in packet_solids.items():
        input_details[packet_name] = {
            "original_id": packet_solid.original_id,
            "vertex_count": len(packets[packet_name]["vertices"]),
            "triangle_count": packet_solid.triangle_count,
            "signed_volume_before_import_m3": packet_solid.signed_volume_before_import,
            "manifold_volume_m3": float(packet_solid.manifold.volume()),
            "input_winding_reversed_for_manifold": packet_solid.input_winding_reversed_for_manifold,
            "mesh_merge_attempted": packet_solid.mesh_merge_attempted,
            "mesh_merge_changed": packet_solid.mesh_merge_changed,
            "status": _status_name(packet_solid.manifold),
            "component_count": len(packet_solid.manifold.decompose()),
        }

    geometry_gates = {
        "initial_caps_paired": young_caps["unpaired_cap_count"] == 0,
        "initial_cap_loops_match": young_caps["outline_mismatch_count"] == 0,
        "initial_caps_opposite_winding": young_caps["orientation_mismatch_count"] == 0,
        "partition_reconstructs_a": all(_comparison_gate_summary(a_reconstruction_comparison).values()),
        "regional_matches_monolithic": all(_comparison_gate_summary(regional_comparison).values()),
        "compiler_caps_not_published": publication_counters["published_cap_triangles"] == 0,
        "emitted_organic_packets_boundary_edges_zero": (
            publication_topology["boundary_edge_count"] == 0
        ),
        "emitted_organic_packets_nonmanifold_edges_zero": (
            publication_topology["nonmanifold_edge_count"] == 0
        ),
        "emitted_organic_packets_directed_mismatch_zero": (
            publication_topology["directed_mismatch_edge_count"] == 0
        ),
        "emitted_packets_godot_1e_7_strict_topology": (
            publication_godot_strict_topology["boundary_edge_count"] == 0
            and publication_godot_strict_topology["nonmanifold_edge_count"] == 0
            and publication_godot_strict_topology["directed_mismatch_edge_count"] == 0
        ),
        "emitted_packet_plane_seams_match": bool(publication_plane_seams["passed"]),
        "emitted_packets_no_double_subthreshold_faces": (
            publication_degeneracy["double_subthreshold_triangle_count"] == 0
        ),
        "emitted_packets_no_float32_subthreshold_faces": (
            publication_degeneracy["float32_subthreshold_triangle_count"] == 0
        ),
        "derived_float_publication_moves_no_vertices": not bool(
            publication_counters["derived_float_publication_normalization"][
                "vertex_coordinates_moved"
            ]
        ),
        "derived_float_publication_preserves_provenance_face_groups": bool(
            publication_counters["derived_float_publication_normalization"][
                "provenance_face_groups_preserved"
            ]
        ),
        "edited_caps_paired": edited_caps["unpaired_cap_count"] == 0,
        "edited_cap_loops_match": edited_caps["outline_mismatch_count"] == 0,
        "edited_caps_opposite_winding": edited_caps["orientation_mismatch_count"] == 0,
        "provenance_valid": bool(regional_provenance["passed"]),
        "young_remote_identity_preserved_outside_timing": bool(young_remote_identity["passed"]),
        "mature_remote_identity_preserved_outside_timing": bool(mature_remote_identity["passed"]),
        "atomic_failure_publishes_nothing": bool(atomic_failure["passed"]),
        "three_replays_deterministic": len(set(deterministic_digests)) == 1,
        "consumed_geometry_hashes_regenerated": bool(
            consumed_geometry_hashes["regenerated_from_consumed_vertices_and_triangles"]
        ),
        "hybrid_mature_matches_monolithic": all(
            _comparison_gate_summary(hybrid_mature_comparison).values()
        ),
        "young_mature_pre_edit_local_objects_identical": (
            identical_local_object_count == len(young_local_coordinates)
        ),
        "young_mature_post_edit_selected_storage_equivalent": bool(
            post_storage_equivalence["passed"]
        ),
        "young_mature_post_edit_cap_seams_equal": post_cap_seams_equal,
        "young_mature_post_edit_cap_triangle_counts_equal": post_cap_triangle_counts_equal,
        "young_mature_post_edit_publication_geometry_equivalent": (
            post_publication_geometry_equivalent
        ),
    }
    geometry_passed = all(geometry_gates.values())
    timing_passed = bool(timing_summary["passed"])
    proof_passed = geometry_passed and timing_passed
    if not geometry_passed:
        failure_reason = "one or more exact regional geometry gates failed"
    elif not timing_passed:
        failure_reason = "paired locality timing gate failed"
    else:
        failure_reason = ""

    result = {
        "schema": "forge_v2_exact_regional_manifold_prototype_result",
        "schema_version": 1,
        "generated_at_unix_seconds": time.time(),
        "production_files_touched": False,
        "production_ready": False,
        "production_readiness_reason": (
            "additive exact-regional prototype passed; Forge semantic and runtime integration gates remain"
        ),
        "prototype_gate_passed": proof_passed,
        "proof_passed": proof_passed,
        "outcome": "pass" if proof_passed else "fail",
        "failure_reason": failure_reason,
        "engine": {
            "name": "manifold3d",
            "version": MANIFOLD_VERSION,
            "module_path": str(Path(manifold3d.__file__).resolve()),
            "isolated_target": str(ISOLATED_SITE),
            "system_install_performed": False,
        },
        "fixture": {
            "path": str(FIXTURE_PATH),
            "file_sha256": fixture_file_sha256,
            "fixture_id": fixture.get("fixture_id"),
            "declared_canonical_hashes_transport_check": declared_fixture_hashes,
            "consumed_geometry_hashes": consumed_geometry_hashes,
        },
        "spatial_jurisdiction": {
            "chunk_size_meters": CHUNK_SIZE_METERS,
            "halo_rings": HALO_RINGS,
            "geometry_quantized_to_chunks": False,
            "vertices_moved_or_snapped": False,
            "fragmentation_method": "paired_recursive_Manifold.split_by_plane",
            "region_boolean_count": 1,
            "publication_law": "organic source runs only; compiler cap runs omitted",
            "transaction_mapping": "persistent local overlay",
        },
        "inputs": input_details,
        "setup": {
            "young_fragment_count": len(young_state.fragments),
            "mature_fragment_count": len(mature_state.fragments),
            "mature_independent_fragment_count": len(independently_partitioned_mature_fragments),
            "mature_exact_young_local_object_count": identical_local_object_count,
            "mature_remote_fragment_count": (
                len(mature_state.fragments) - identical_local_object_count
            ),
            "young_partition_ms": young_partition_ms,
            "mature_monolithic_build_ms": mature_boolean_ms,
            "mature_partition_ms": mature_partition_ms,
            "setup_reasonable_for_paired_timing": setup_reasonable,
        },
        "partition_a": {
            "caps": young_caps,
            "assembly": a_assembly_diagnostics,
            "reconstruction_comparison": a_reconstruction_comparison,
        },
        "monolithic_oracle": {
            "summary": _solid_summary(monolithic_oracle),
            "provenance": monolithic_provenance,
        },
        "regional_edit": edit_metrics,
        "remote_identity_audits_outside_timing": {
            "young": young_remote_identity,
            "mature": mature_remote_identity,
        },
        "regional_reconstruction": {
            "assembly": regional_assembly_diagnostics,
            "comparison": regional_comparison,
            "provenance": regional_provenance,
        },
        "seams": {
            "edited_caps": edited_caps,
            "mature_caps": mature_caps,
        },
        "hybrid_mature": {
            "construction": "exact young local Fragment objects plus independently compiled mature remote fragments",
            "assembly": hybrid_mature_assembly,
            "strict_weld_normalization": mature_strict_weld_normalization,
            "comparison_to_monolithic_a_plus_extension": hybrid_mature_comparison,
            "post_edit_metrics": mature_edit_metrics,
        },
        "young_mature_post_edit_equivalence": {
            "selected_storage": post_storage_equivalence,
            "cap_seams_equal": post_cap_seams_equal,
            "compiler_cap_triangle_counts_equal": post_cap_triangle_counts_equal,
            "young_compiler_cap_triangle_count": young_post_publication_counters["compiler_cap_triangles"],
            "mature_compiler_cap_triangle_count": mature_post_publication_counters["compiler_cap_triangles"],
            "exact_packet_hashes_equal": exact_post_packet_match,
            "equivalence_mode": post_equivalence_mode,
            "publication_geometry_equivalent": post_publication_geometry_equivalent,
        },
        "atomic_failure": atomic_failure,
        "determinism": {
            "replay_count": 3,
            "publication_digests": deterministic_digests,
            "passed": len(set(deterministic_digests)) == 1,
        },
        "publication": {
            "compiler_caps_are_storage_only": True,
            "counters": publication_counters,
            "emitted_packet_topology": publication_topology,
            "emitted_packet_godot_1e_7_strict_topology": (
                publication_godot_strict_topology
            ),
            "emitted_packet_plane_seams": publication_plane_seams,
            "emitted_packet_degeneracy": publication_degeneracy,
            "independent_welded_organic_crosscheck": regional_assembly_diagnostics,
            "organic_fragment_packets": publication_packets,
        },
        "geometry_gates": geometry_gates,
        "geometry_passed": geometry_passed,
        "timing": timing_summary,
        "limitations": [
            "The surface-distance oracle is a deterministic mesh sample, not an analytic Hausdorff bound.",
            "This tools-only additive proof does not yet implement Forge Remove/VOID or material arbitration.",
            "Compiler caps remain in closed storage fragments and are deliberately absent from render/collision packets.",
            "Production cutover is not performed by this program.",
        ],
        "elapsed_ms": (time.perf_counter_ns() - proof_started) / 1.0e6,
    }
    return result, timing_rows


def _csv_text(rows: Sequence[Mapping[str, Any]]) -> str:
    fieldnames = [
        "state",
        "pair_index",
        "order_in_pair",
        "warmup",
        "region_selection_ms",
        "assembly_ms",
        "boolean_ms",
        "splitting_ms",
        "validation_ms",
        "transaction_publish_ms",
        "prototype_transaction_ms",
        "candidate_coordinate_count",
        "selected_populated_fragment_count",
        "pre_edit_populated_fragment_count",
        "changed_fragment_count",
        "post_edit_populated_fragment_count",
        "assembled_triangle_count",
        "boolean_output_triangle_count",
        "organic_output_triangle_count",
        "compiler_cap_output_triangle_count",
        "remote_fragment_count",
        "remote_rebuild_count",
        "expansion_count",
    ]
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fieldnames, extrasaction="ignore", lineterminator="\n")
    writer.writeheader()
    for row in rows:
        writer.writerow(row)
    return output.getvalue()


def _report_text(result: Mapping[str, Any]) -> str:
    passed = bool(result.get("proof_passed", False))
    outcome = "PASS" if passed else "FAIL"
    lines = [
        "# Forge V2 Exact Regional Manifold Prototype",
        "",
        f"Outcome: **{outcome}**",
        "",
        "The 64 mm chunks are spatial ownership only. The proof imports the exact indexed organic sweeps exported by Forge, moves no vertices, performs no voxelization, and publishes no compiler-cap triangles.",
        "",
    ]
    if not passed:
        lines.extend([f"Failure: `{result.get('failure_reason', 'unknown')}`", ""])
        if result.get("traceback"):
            lines.extend(["The full exception is retained in the JSON artifact.", ""])
        return "\n".join(lines) + "\n"

    setup = result["setup"]
    comparison = result["regional_reconstruction"]["comparison"]
    timing = result["timing"]
    edit = result["regional_edit"]
    publication = result["publication"]
    lines.extend(
        [
            "## Geometry result",
            "",
            f"- A was partitioned into {setup['young_fragment_count']} closed exact fragments; the mature connected fixture used {setup['mature_fragment_count']} fragments.",
            f"- The local edit selected {edit['counters']['selected_populated_fragment_count']} populated fragments and rebuilt {edit['counters']['remote_rebuild_count']} remote fragments.",
            f"- Symmetric-difference volume against monolithic A+B: `{comparison['symmetric_difference_volume_m3']:.12g} m³`.",
            f"- Maximum sampled bidirectional surface distance: `{comparison['sampled_surface_max_m']:.12g} m`.",
            f"- The rejected emitter had {publication['counters']['organic_source_triangles']} organic triangles and three unmatched edges. Conforming refinement is now propagated into the emitted packets: {publication['counters']['organic_triangles']} triangles, {publication['emitted_packet_topology']['boundary_edge_count']} boundary edges, and {publication['emitted_packet_topology']['nonmanifold_edge_count']} nonmanifold edges.",
            f"- Published compiler-cap triangles: {publication['counters']['published_cap_triangles']}.",
            "- Every paired cap outline matched after normalizing split-only collinear points within the 10 nm comparison quantum; areas matched within the hard tolerance and windings were opposite.",
            f"- Young/mature post-edit equivalence used `{result['young_mature_post_edit_equivalence']['equivalence_mode']}`; compiler-cap counts were {result['young_mature_post_edit_equivalence']['young_compiler_cap_triangle_count']} / {result['young_mature_post_edit_equivalence']['mature_compiler_cap_triangle_count']}.",
            "- Injected failure published nothing; three clean replays produced the same organic publication digest.",
            "",
            "## Paired prototype transaction timing",
            "",
            f"After {timing['warmup_pairs']} warm-up pairs, {timing['measured_pairs']} alternating measured pairs were recorded.",
            "",
            f"- Young p50/p95: `{timing['young']['p50_prototype_transaction_ms']:.3f} / {timing['young']['p95_prototype_transaction_ms']:.3f} ms`.",
            f"- Mature p50/p95: `{timing['mature']['p50_prototype_transaction_ms']:.3f} / {timing['mature']['p95_prototype_transaction_ms']:.3f} ms`.",
            f"- Mature/young ratios: `{timing['mature_to_young_p50_ratio']:.4f}` p50 and `{timing['mature_to_young_p95_ratio']:.4f}` p95.",
            f"- Paired p95 delta: `{timing['paired_delta_p95_ms']:.3f} ms` (limit `{timing['paired_delta_limit_ms']:.3f} ms`).",
            "- This is `prototype_transaction_ms`, not ready latency. Godot render mesh creation, collision construction, resource swaps, persistence, exhaustive remote audit, and artifact serialization are excluded.",
            "",
            "## Boundary of this proof",
            "",
            "This validates the additive analytic-edit exact-regional kernel and isolated overlay transaction law. It does not yet validate a B stroke sourced from physical ray hits, BC continuity/exterior gates, tangent/coplanar/tiny-overlap/chunk-corner fixtures, expansion/retry, Remove/VOID, multiple materials, UV/normal property preservation, Godot render/collision publication, undo/redo, or persistence.",
            "",
        ]
    )
    return "\n".join(lines)


def _emit_artifacts(result: Mapping[str, Any], rows: Sequence[Mapping[str, Any]]) -> None:
    _atomic_write_text(
        OUTPUT_JSON,
        json.dumps(result, indent=2, sort_keys=True, ensure_ascii=True, allow_nan=False) + "\n",
    )
    _atomic_write_text(OUTPUT_CSV, _csv_text(rows))
    _atomic_write_text(OUTPUT_REPORT, _report_text(result))


def main() -> int:
    rows: list[dict[str, Any]] = []
    try:
        result, rows = _run_proof()
        _emit_artifacts(result, rows)
        print(
            "EXACT REGIONAL MANIFOLD %s fragments=%d/%d p50_ratio=%.4f p95_ratio=%.4f"
            % (
                result["outcome"].upper(),
                result["setup"]["young_fragment_count"],
                result["setup"]["mature_fragment_count"],
                result["timing"]["mature_to_young_p50_ratio"],
                result["timing"]["mature_to_young_p95_ratio"],
            )
        )
        return 0 if result["proof_passed"] else 1
    except Exception as error:  # Preserve exact blocker evidence atomically.
        result = {
            "schema": "forge_v2_exact_regional_manifold_prototype_result",
            "schema_version": 1,
            "generated_at_unix_seconds": time.time(),
            "production_files_touched": False,
            "production_ready": False,
            "proof_passed": False,
            "outcome": "fail",
            "failure_type": type(error).__name__,
            "failure_reason": str(error),
            "traceback": traceback.format_exc(),
            "engine": {
                "name": "manifold3d",
                "version": MANIFOLD_VERSION,
                "module_path": str(Path(manifold3d.__file__).resolve()),
                "isolated_target": str(ISOLATED_SITE),
                "system_install_performed": False,
            },
        }
        _emit_artifacts(result, rows)
        print(f"EXACT REGIONAL MANIFOLD FAIL: {type(error).__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
