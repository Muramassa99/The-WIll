#!/usr/bin/env python3
"""Tools-only proof for a persistent incremental Forge V2 publication atlas.

The frozen pre-edit states are young ``A`` and mature ``A + remote extension``.
Both receive the identical ``B`` operand.  Closed 64 mm storage fragments are
selected and assembled for one regional Boolean, while visible publication
pages remain non-clipping containers of whole provenance atoms.  Expensive
whole-state equivalence oracles run only outside the instrumented transaction.

This prototype imports the existing exact-regional and unclipped-atlas proofs;
it does not modify production, Godot, or ``user://`` state.
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import itertools
import json
import math
from pathlib import Path
import sys
import time
from typing import Any, Iterable, Iterator, Mapping, Sequence, TypeVar

import prototype_forge_v2_exact_regional_manifold as exact
import prototype_forge_v2_regional_publication_atlas as atlas


np = exact.np
manifold3d = exact.manifold3d

OUTPUT_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_prototype.json"
)
OUTPUT_PACKETS_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_packets.json"
)
OUTPUT_YOUNG_OPTIMIZED_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_young_optimized.json"
)
OUTPUT_YOUNG_OPTIMIZED_PACKETS_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_young_optimized_packets.json"
)
OUTPUT_PAIRED_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_paired.json"
)
OUTPUT_PAIRED_PACKETS_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_paired_packets.json"
)
OUTPUT_STITCHED_MATURE_VALIDATION_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_stitched_mature_validation.json"
)
OUTPUT_STITCHED_PRESTATE_VALIDATION_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_stitched_prestate_validation.json"
)
OUTPUT_STITCHED_PRESTATE_MANIFEST_DIAGNOSTIC_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_stitched_prestate_manifest_diagnostic.json"
)
OUTPUT_STITCHED_PAIR_TRANSACTION_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_stitched_pair_transaction.json"
)
OUTPUT_STITCHED_PAIR_FRAGMENT_DIAGNOSTIC_JSON = (
    exact.WORKSPACE
    / "godot_runs"
    / "forge_v2_incremental_publication_atlas_stitched_pair_fragment_diagnostic.json"
)
ACCEPTED_STITCHED_PRESTATE_SHA256 = (
    "3f205f050f0dbb4f800c68dee8edca15aa9c4f4bc27918a6d4b8ea1498c4c1b7"
)
ACCEPTED_STITCHED_PAIR_FRAGMENT_DIAGNOSTIC_SHA256 = (
    "4c752c2700d8273ac05c82b0d4c0df0ed4840d38a03a4f506cf57e25141d5068"
)

CHUNK_SIZE_METERS = exact.CHUNK_SIZE_METERS
HALO_RINGS = exact.HALO_RINGS
TRIANGLE_CROSS_SQUARED_FLOOR_M4 = atlas.TRIANGLE_CROSS_SQUARED_FLOOR_M4
MAX_PATCH_VERTEX_DISPLACEMENT_METERS = (
    atlas.MAX_PATCH_VERTEX_DISPLACEMENT_METERS
)
MAX_SAMPLED_SURFACE_DISTANCE_METERS = atlas.MAX_SAMPLED_SURFACE_DISTANCE_METERS
MAX_SYMMETRIC_DIFFERENCE_VOLUME_M3 = atlas.MAX_SYMMETRIC_DIFFERENCE_VOLUME_M3
TOPOLOGY_QUANTA_METERS = atlas.TOPOLOGY_QUANTA_METERS
MAX_ZERO_MOVE_DIRTY_ATOM_TRIANGLES = 256
MAX_ZERO_MOVE_BOUNDARY_VERTICES = 64
MAX_ZERO_MOVE_TRIANGULATION_TRIPLET_EVALUATIONS = math.comb(
    MAX_ZERO_MOVE_BOUNDARY_VERTICES, 3
)
STITCHED_A_RING_COUNT = 25
STITCHED_RING_VERTEX_COUNT = 29
STITCHED_RAIL_NEW_RING_COUNT = 149
STITCHED_SIDE_TRIANGLES_PER_INTERVAL = 58
STITCHED_TERMINAL_CAP_TRIANGLE_COUNT = 27
STITCHED_RAIL_X_LENGTH_METERS = 2.304

Coordinate = tuple[int, int, int]
Record = atlas.Record
T = TypeVar("T")


class ProofFailure(RuntimeError):
    """A hard incremental-atlas gate failed."""


@dataclass(frozen=True)
class PublicationAtom:
    """Immutable atom version plus its stable logical lineage.

    ``lineage_id`` is the slot used by persistent indexes and page membership.
    ``version_id`` is content addressed and therefore changes whenever the
    exact arrays or their source/material lineage change.  Keeping the two
    identities separate prevents an in-place payload mutation from masquerading
    as an unchanged persistent atom.
    """

    lineage_id: str
    version_id: str
    source_id: int
    face_id: int
    records: tuple[Record, ...]
    payload_sha256: str
    bounds: tuple[float, float, float, float, float, float]
    overlap_cells: tuple[Coordinate, ...]

    @property
    def atom_id(self) -> str:
        """Compatibility alias: atlas maps are keyed by stable lineage."""
        return self.lineage_id


@dataclass(frozen=True)
class PublicationPage:
    """Immutable non-clipping page object with stable content-addressed identity."""

    page_id: str
    shard_key: str
    atom_ids: tuple[str, ...]
    payload: Mapping[str, Any]
    payload_sha256: str
    bounds: tuple[float, float, float, float, float, float]
    overlap_cells: tuple[Coordinate, ...]


@dataclass(frozen=True)
class PublicationState:
    """Persistent atlas plus read-only indexes prepared before transaction time."""

    atoms: Mapping[str, PublicationAtom]
    pages: Mapping[str, PublicationPage]
    atom_to_page: Mapping[str, str]
    atom_overlap_index: Mapping[Coordinate, frozenset[str]]
    provenance_index: Mapping[tuple[int, int], frozenset[str]]
    page_overlap_index: Mapping[Coordinate, frozenset[str]]
    half_edge_neighbors: Mapping[str, frozenset[str]]
    half_edge_index: Mapping[atlas.EdgeKey, frozenset[str]]
    revision: int


@dataclass
class AccessCounters:
    """Measured-path evidence that locality comes from indexes, not global scans."""

    fragment_coordinate_lookups: int = 0
    fragment_objects_loaded: int = 0
    atom_index_cell_lookups: int = 0
    atom_objects_loaded: int = 0
    half_edge_neighbor_lookups: int = 0
    page_index_cell_lookups: int = 0
    page_objects_loaded: int = 0
    remote_triangle_reads: int = 0
    global_fragment_iterations: int = 0
    global_atom_iterations: int = 0
    global_page_iterations: int = 0
    forbidden_fragment_items_calls: int = 0
    forbidden_fragment_values_calls: int = 0
    forbidden_atom_items_calls: int = 0
    forbidden_atom_values_calls: int = 0
    forbidden_page_items_calls: int = 0
    forbidden_page_values_calls: int = 0


@dataclass
class AccessGuard:
    """Shared switch allowing post-transaction exhaustive proof oracles."""

    active: bool = True


def _canonical_access_key(value: Any) -> Any:
    if isinstance(value, tuple):
        return [_canonical_access_key(item) for item in value]
    if isinstance(value, list):
        return [_canonical_access_key(item) for item in value]
    if isinstance(value, (set, frozenset)):
        values = [_canonical_access_key(item) for item in value]
        return sorted(
            values,
            key=lambda item: json.dumps(
                item, sort_keys=True, ensure_ascii=True, separators=(",", ":")
            ),
        )
    if isinstance(value, Mapping):
        return {
            str(key): _canonical_access_key(item)
            for key, item in sorted(value.items(), key=lambda row: repr(row[0]))
        }
    if isinstance(value, PublicationAtom):
        return {
            "kind": "PublicationAtom",
            "lineage_id": value.lineage_id,
            "version_id": value.version_id,
            "payload_sha256": value.payload_sha256,
            "records_sha256": atlas._records_digest(value.records),
            "source_id": value.source_id,
            "face_id": value.face_id,
            "bounds": list(value.bounds),
            "overlap_cells": [list(cell) for cell in value.overlap_cells],
        }
    if isinstance(value, PublicationPage):
        return {
            "kind": "PublicationPage",
            "page_id": value.page_id,
            "shard_key": value.shard_key,
            "payload_sha256": value.payload_sha256,
            "canonical_payload_sha256": atlas._page_payload_hash(value.payload),
            "atom_ids": list(value.atom_ids),
            "bounds": list(value.bounds),
            "overlap_cells": [list(cell) for cell in value.overlap_cells],
        }
    if isinstance(value, exact.Fragment):
        return {
            "kind": "Fragment",
            "coordinate": list(value.coordinate),
            "mesh_sha256": value.digest,
        }
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating,)):
        return float(value)
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    raise ProofFailure(
        f"guarded access trace cannot canonically encode {type(value).__name__}"
    )


@dataclass
class AccessTrace:
    """Ordered evidence of every timed key lookup/contains and returned value."""

    events: list[tuple[str, str, str, str]]

    def __init__(self) -> None:
        self.events = []

    def record(
        self, map_name: str, operation: str, key: Any, result: Any
    ) -> None:
        canonical_key = json.dumps(
            _canonical_access_key(key),
            sort_keys=True,
            ensure_ascii=True,
            allow_nan=False,
            separators=(",", ":"),
        )
        canonical_result = json.dumps(
            _canonical_access_key(result),
            sort_keys=True,
            ensure_ascii=True,
            allow_nan=False,
            separators=(",", ":"),
        )
        self.events.append(
            (map_name, operation, canonical_key, canonical_result)
        )

    def snapshot(self) -> dict[str, Any]:
        counts: dict[str, int] = {}
        unique_keys: dict[str, set[str]] = {}
        for map_name, operation, canonical_key, _canonical_result in self.events:
            label = f"{map_name}:{operation}"
            counts[label] = counts.get(label, 0) + 1
            unique_keys.setdefault(label, set()).add(canonical_key)
        event_rows = [list(value) for value in self.events]
        return {
            "event_count": len(event_rows),
            "events": event_rows,
            "event_sha256": _sha256_json(event_rows),
            "counts_by_map_operation": dict(sorted(counts.items())),
            "unique_keys_by_map_operation": {
                key: sorted(values) for key, values in sorted(unique_keys.items())
            },
            "trace_scope": (
                "timed key lookup/contains operations and semantic returned values; "
                "len() values are deliberately excluded because global young/mature "
                "mapping sizes differ and are not transaction work"
            ),
        }


class GuardedReadMapping(Mapping[Any, T]):
    """Read mapping that makes a timed-path global traversal fail immediately.

    This is deliberately more substantive than a convention counter: the
    wrapped authority maps themselves reject ``iter()``, ``items()`` and
    ``values()`` while the instrumented transaction is active.  The guard is
    disabled only after the timed path has returned, so exhaustive proof
    oracles can inspect the immutable result afterwards.
    """

    def __init__(
        self,
        base: Mapping[Any, T],
        guard: AccessGuard,
        counters: AccessCounters,
        family: str,
        map_name: str,
        trace: AccessTrace,
    ) -> None:
        _require(family in {"fragment", "atom", "page"}, "unknown guarded map family")
        self._base = base
        self._guard = guard
        self._counters = counters
        self._family = family
        self._map_name = map_name
        self._trace = trace

    def __getitem__(self, key: Any) -> T:
        try:
            result = self._base[key]
        except KeyError:
            if self._guard.active:
                self._trace.record(
                    self._map_name, "lookup", key, {"missing": True}
                )
            raise
        if self._guard.active:
            self._trace.record(self._map_name, "lookup", key, result)
        return result

    def __len__(self) -> int:
        return len(self._base)

    def __contains__(self, key: object) -> bool:
        result = key in self._base
        if self._guard.active:
            self._trace.record(self._map_name, "contains", key, result)
        return result

    def _reject(self, operation: str) -> None:
        if not self._guard.active:
            return
        if operation == "iter":
            setattr(
                self._counters,
                f"global_{self._family}_iterations",
                getattr(self._counters, f"global_{self._family}_iterations") + 1,
            )
        else:
            field = f"forbidden_{self._family}_{operation}_calls"
            setattr(self._counters, field, getattr(self._counters, field) + 1)
        raise ProofFailure(
            f"timed transaction attempted forbidden {self._family} mapping {operation}()"
        )

    def __iter__(self) -> Iterator[Any]:
        self._reject("iter")
        return iter(self._base)

    def items(self) -> Any:
        self._reject("items")
        return self._base.items()

    def values(self) -> Any:
        self._reject("values")
        return self._base.values()


@dataclass(frozen=True)
class FrozenInputs:
    fixture: Mapping[str, Any]
    fixture_sha256: str
    fixture_transport: Mapping[str, Any]
    stroke_a: exact.PacketSolid
    stroke_b: exact.PacketSolid
    extension: exact.PacketSolid
    organic_ids: frozenset[int]
    source_face_counts: Mapping[int, int]
    property_lookup: Mapping[tuple[int, int], tuple[int, int]]
    young_storage: exact.WorkpieceState
    mature_storage: exact.WorkpieceState
    mature_authority: Any
    selected_space: frozenset[Coordinate]
    local_coordinates: frozenset[Coordinate]
    mature_independent_fragment_count: int


@dataclass(frozen=True)
class StitchedMatureFixture:
    """Reusable tools-only A-plus-rail solid; never wired into paired mode here."""

    manifold: Any
    records: tuple[Record, ...]
    property_lookup: Mapping[tuple[int, int], tuple[int, int]]
    a_original_id: int
    b_original_id: int
    rail_original_id: int
    diagnostics: Mapping[str, Any]


@dataclass(frozen=True)
class StitchedFrozenPrestate:
    """Young and stitched mature authorities sharing one reserved source tuple."""

    stitched: StitchedMatureFixture
    stroke_a: exact.PacketSolid
    stroke_b: exact.PacketSolid
    young_storage: exact.WorkpieceState
    mature_storage: exact.WorkpieceState
    young_publication: PublicationState
    mature_publication: PublicationState
    selected_space: frozenset[Coordinate]
    edit_cells: frozenset[Coordinate]
    ungrafted_differing_page_ids: frozenset[str]
    property_lookup: Mapping[tuple[int, int], tuple[int, int]]
    diagnostics: Mapping[str, Any]


@dataclass(frozen=True)
class StitchedPublicationPrestate:
    """Minimal direct young/stitched publication bootstrap for locality audits."""

    fixture_sha256: str
    stitched: StitchedMatureFixture
    stroke_a: exact.PacketSolid
    stroke_b: exact.PacketSolid
    young_publication: PublicationState
    mature_publication: PublicationState
    selected_space: frozenset[Coordinate]
    b_edit_cells: frozenset[Coordinate]
    conditioned_a_records: tuple[Record, ...]
    mature_bootstrap_records: tuple[Record, ...]
    a_conditioning: Mapping[str, Any]
    young_publication_build: Mapping[str, Any]
    mature_publication_build: Mapping[str, Any]
    halo_manifests: Mapping[str, Mapping[str, Any]]
    edit_manifests: Mapping[str, Mapping[str, Any]]
    halo_comparison: Mapping[str, Any]
    edit_comparison: Mapping[str, Any]


@dataclass(frozen=True)
class StitchedPairInputs:
    """Lightweight accepted prestate prepared for one traced paired B edit."""

    stitched: StitchedMatureFixture
    stroke_a: exact.PacketSolid
    stroke_b: exact.PacketSolid
    young_storage: exact.WorkpieceState
    mature_storage: exact.WorkpieceState
    young_publication: PublicationState
    mature_publication: PublicationState
    selected_space: frozenset[Coordinate]
    edit_cells: frozenset[Coordinate]
    organic_ids: frozenset[int]
    property_lookup: Mapping[tuple[int, int], tuple[int, int]]
    source_face_counts: Mapping[int, int]
    source_tags: Mapping[int, str]
    ungrafted_differing_page_ids: frozenset[str]
    accepted_prestate_sha256: str
    diagnostics: Mapping[str, Any]


@dataclass(frozen=True)
class EditOutcome:
    storage: exact.WorkpieceState
    publication: PublicationState
    metrics: Mapping[str, Any]
    unsplit_region_result: Any
    unsplit_region_records: tuple[Record, ...]
    published_new_atoms: tuple[PublicationAtom, ...]
    removed_atom_ids: frozenset[str]
    rebuilt_page_ids: frozenset[str]


@dataclass(frozen=True)
class ReplacementAtomIndexes:
    """Transaction-local indexes built once for candidate atom versions."""

    by_lineage: Mapping[str, PublicationAtom]
    by_cell: Mapping[Coordinate, frozenset[str]]
    by_label: Mapping[tuple[int, int], frozenset[str]]
    by_edge: Mapping[atlas.EdgeKey, frozenset[str]]
    by_page: Mapping[str, frozenset[str]]


class PersistentOverlay(Mapping[Any, T]):
    """Immutable key overlay; constructing it never walks the base mapping."""

    def __init__(
        self,
        base: Mapping[Any, T],
        removed: Iterable[Any],
        replacements: Mapping[Any, T],
    ) -> None:
        self._base = base
        self._removed = frozenset(removed)
        self._replacements = dict(replacements)
        removed_base = sum(key in base for key in self._removed)
        added = sum(
            key not in base or key in self._removed for key in self._replacements
        )
        self._length = len(base) - removed_base + added

    def __getitem__(self, key: Any) -> T:
        if key in self._replacements:
            return self._replacements[key]
        if key in self._removed:
            raise KeyError(key)
        return self._base[key]

    def __iter__(self) -> Iterator[Any]:
        for key in self._base:
            if key not in self._removed and key not in self._replacements:
                yield key
        yield from self._replacements

    def __len__(self) -> int:
        return self._length

    def __contains__(self, key: object) -> bool:
        if key in self._replacements:
            return True
        if key in self._removed:
            return False
        return key in self._base


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ProofFailure(message)


def _sha256_json(value: Any) -> str:
    payload = json.dumps(
        value,
        sort_keys=True,
        ensure_ascii=True,
        allow_nan=False,
        separators=(",", ":"),
    ).encode("ascii")
    return hashlib.sha256(payload).hexdigest()


def _records_from_solid(solid: Any) -> list[Record]:
    vertices, triangles, source_ids, face_ids = exact._triangle_records(solid)
    return atlas._sorted_records(
        (
            int(source_ids[index]),
            int(face_ids[index]),
            vertices[triangle].copy(),
        )
        for index, triangle in enumerate(triangles)
    )


def _bounds_for_records(
    records: Sequence[Record],
) -> tuple[float, float, float, float, float, float]:
    _require(bool(records), "cannot bound an empty record sequence")
    points = np.concatenate(
        [np.asarray(record[2], dtype=np.float64) for record in records], axis=0
    )
    values = np.concatenate((points.min(axis=0), points.max(axis=0)))
    return tuple(float(value) for value in values)  # type: ignore[return-value]


def _cells_for_bounds(bounds: Sequence[float]) -> tuple[Coordinate, ...]:
    """Return every half-open 64 mm cell overlapped by an AABB."""
    _require(len(bounds) == 6, "AABB must contain min/max XYZ")
    spans = [
        exact._chunk_span(float(bounds[axis]), float(bounds[axis + 3]))
        for axis in range(3)
    ]
    return tuple(
        sorted(
            (int(x), int(y), int(z))
            for x, y, z in itertools.product(*spans)
        )
    )


def _logical_atom_rows(
    records: Sequence[Record],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
) -> list[PublicationAtom]:
    """Atomize once, then assign stable provenance-slot IDs and AABB footprints."""
    raw_atoms = atlas._make_atoms(records)
    by_face: dict[tuple[int, int], list[atlas.Atom]] = {}
    for atom in raw_atoms:
        by_face.setdefault((atom.source_id, atom.face_id), []).append(atom)

    output: list[PublicationAtom] = []
    for (source_id, face_id), face_atoms in sorted(by_face.items()):
        _require(
            (source_id, face_id) in property_lookup,
            f"atom has no source/material lineage: {(source_id, face_id)}",
        )
        ordered = sorted(
            face_atoms,
            key=lambda atom: (
                _bounds_for_records(atom.records),
                atom.digest,
            ),
        )
        for slot, atom in enumerate(ordered):
            atom_records = tuple(atlas._sorted_records(atom.records))
            bounds = _bounds_for_records(atom_records)
            payload_sha256 = atlas._atom_payload_hash(
                atom_records, property_lookup
            )
            output.append(
                PublicationAtom(
                    lineage_id=f"l:{source_id}:{face_id}:{slot}",
                    version_id=f"av:{payload_sha256}",
                    source_id=source_id,
                    face_id=face_id,
                    records=atom_records,
                    payload_sha256=payload_sha256,
                    bounds=bounds,
                    overlap_cells=_cells_for_bounds(bounds),
                )
            )
    return sorted(output, key=lambda atom: atom.atom_id)


def _build_atom_indexes(
    atoms: Sequence[PublicationAtom],
) -> tuple[
    dict[Coordinate, frozenset[str]],
    dict[str, frozenset[str]],
    dict[atlas.EdgeKey, frozenset[str]],
]:
    overlap: dict[Coordinate, set[str]] = {}
    half_edges: dict[atlas.EdgeKey, set[str]] = {}
    for atom in atoms:
        for coordinate in atom.overlap_cells:
            overlap.setdefault(coordinate, set()).add(atom.atom_id)
        for _source_id, _face_id, raw_points in atom.records:
            points = np.asarray(raw_points, dtype=np.float64)
            for first, second in (
                (points[0], points[1]),
                (points[1], points[2]),
                (points[2], points[0]),
            ):
                half_edges.setdefault(atlas._edge_key(first, second), set()).add(
                    atom.atom_id
                )
    neighbors: dict[str, set[str]] = {atom.atom_id: set() for atom in atoms}
    for atom_ids in half_edges.values():
        if len(atom_ids) < 2:
            continue
        for atom_id in atom_ids:
            neighbors[atom_id].update(atom_ids - {atom_id})
    return (
        {key: frozenset(value) for key, value in overlap.items()},
        {key: frozenset(value) for key, value in neighbors.items()},
        {key: frozenset(value) for key, value in half_edges.items()},
    )


def _prepare_frozen_inputs() -> FrozenInputs:
    """Build young A and hybrid mature A+remote-extension outside timing."""
    fixture, fixture_sha256 = exact._load_fixture()
    fixture_transport = exact._validate_fixture_hashes(fixture)
    first_original_id = int(manifold3d.Manifold.reserve_ids(3))
    stroke_a = exact._make_packet_solid(
        "stroke_a", fixture["packets"]["stroke_a"], first_original_id
    )
    stroke_b = exact._make_packet_solid(
        "stroke_b", fixture["packets"]["stroke_b"], first_original_id + 1
    )
    extension = exact._make_packet_solid(
        "mature_extension",
        fixture["packets"]["mature_extension"],
        first_original_id + 2,
    )
    organic_ids = frozenset(
        (stroke_a.original_id, stroke_b.original_id, extension.original_id)
    )
    source_face_counts = {
        stroke_a.original_id: stroke_a.triangle_count,
        stroke_b.original_id: stroke_b.triangle_count,
        extension.original_id: extension.triangle_count,
    }
    property_lookup = atlas._source_property_lookup(
        fixture,
        {
            "stroke_a": stroke_a.original_id,
            "stroke_b": stroke_b.original_id,
            "mature_extension": extension.original_id,
        },
    )

    young_fragments = exact._split_to_chunks(stroke_a.manifold)
    young_storage = exact.WorkpieceState(young_fragments, 0)
    selected_space = frozenset(
        exact._coordinates_for_bounds(stroke_b.manifold.bounding_box(), HALO_RINGS)
    )
    local_coordinates = frozenset(set(young_fragments) & set(selected_space))
    _require(bool(local_coordinates), "B's halo selected no A storage fragments")
    _require(
        bool(set(young_fragments) - set(selected_space)),
        "fixture has no young remote storage fragment",
    )

    raw_mature = stroke_a.manifold + extension.manifold
    _require(exact._is_ok(raw_mature), "A+remote-extension Boolean failed")
    mature_solid, _strict = exact._strict_weld_normalize(
        raw_mature, exact.GODOT_STRICT_WELD_QUANTUM
    )
    independent_mature = exact._split_to_chunks(mature_solid)
    independent_local = frozenset(set(independent_mature) & set(selected_space))
    _require(
        independent_local == local_coordinates,
        "remote extension changed B's selected storage jurisdiction",
    )
    mature_fragments = {
        coordinate: fragment
        for coordinate, fragment in independent_mature.items()
        if coordinate not in selected_space
    }
    for coordinate in local_coordinates:
        mature_fragments[coordinate] = young_fragments[coordinate]
    mature_storage = exact.WorkpieceState(mature_fragments, 0)
    _require(
        all(
            mature_storage.fragments[coordinate]
            is young_storage.fragments[coordinate]
            for coordinate in local_coordinates
        ),
        "mature pre-state did not retain exact young local Fragment objects",
    )
    _require(
        len(mature_storage.fragments) > len(young_storage.fragments),
        "mature pre-state added no remote storage fragments",
    )
    return FrozenInputs(
        fixture=fixture,
        fixture_sha256=fixture_sha256,
        fixture_transport=fixture_transport,
        stroke_a=stroke_a,
        stroke_b=stroke_b,
        extension=extension,
        organic_ids=organic_ids,
        source_face_counts=source_face_counts,
        property_lookup=property_lookup,
        young_storage=young_storage,
        mature_storage=mature_storage,
        mature_authority=mature_solid,
        selected_space=selected_space,
        local_coordinates=local_coordinates,
        mature_independent_fragment_count=len(independent_mature),
    )


def _page_membership(atom: PublicationAtom) -> tuple[Coordinate, str, str]:
    """Fixed hash bucket: adding/removing one atom cannot renumber later shards."""
    owner = atlas._atom_owner(atom.records)
    shard = hashlib.sha256(atom.lineage_id.encode("ascii")).hexdigest()[0]
    page_id = "p:%d:%d:%d:%s" % (*owner, shard)
    return owner, shard, page_id


def _build_page(
    page_id: str,
    atoms: Sequence[PublicationAtom],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
) -> PublicationPage:
    _require(bool(atoms), "cannot build an empty publication page")
    ordered_atoms = sorted(atoms, key=lambda atom: atom.atom_id)
    expected_page_ids = {_page_membership(atom)[2] for atom in ordered_atoms}
    _require(
        expected_page_ids == {page_id},
        f"page membership is inconsistent for {page_id}",
    )
    records: list[Record] = []
    triangle_atom_indices: list[int] = []
    atom_table: list[dict[str, Any]] = []
    for atom_index, atom in enumerate(ordered_atoms):
        material_index, surface_index = property_lookup[
            (atom.source_id, atom.face_id)
        ]
        atom_table.append(
            {
                "atom_index": atom_index,
                "atom_lineage_id": atom.lineage_id,
                "atom_version_id": atom.version_id,
                "source_original_id": atom.source_id,
                "source_face_id": atom.face_id,
                "material_index": int(material_index),
                "surface_index": int(surface_index),
                "triangle_count": len(atom.records),
                "atom_sha256": atom.payload_sha256,
                "aabb_m": list(atom.bounds),
                "overlap_cells_64mm": [list(value) for value in atom.overlap_cells],
            }
        )
        records.extend(atom.records)
        triangle_atom_indices.extend([atom_index] * len(atom.records))
    bounds = _bounds_for_records(records)
    overlap_cells = _cells_for_bounds(bounds)
    owner, shard, expected_page_id = _page_membership(ordered_atoms[0])
    _require(expected_page_id == page_id, "page ID changed during serialization")
    payload: dict[str, Any] = {
        "schema": "forge_v2_incremental_organic_publication_page",
        "schema_version": 1,
        "page_id": page_id,
        "owner_chunk_coordinate": list(owner),
        "stable_shard": shard,
        "stable_shard_law": "sha256(atom_lineage_id)[0]; no capacity-order cascade",
        "geometry_law": "whole atoms only; page AABB is an index, never a clip box",
        "coordinate_units": "meters",
        "atom_count": len(ordered_atoms),
        "triangle_count": len(records),
        "aabb_m": list(bounds),
        "overlap_cells_64mm": [list(value) for value in overlap_cells],
        "atoms": atom_table,
        "mesh64": atlas._mesh64_payload(
            records, property_lookup, triangle_atom_indices
        ),
    }
    payload_sha256 = atlas._page_payload_hash(payload)
    payload["page_sha256"] = payload_sha256
    return PublicationPage(
        page_id=page_id,
        shard_key=shard,
        atom_ids=tuple(atom.atom_id for atom in ordered_atoms),
        payload=payload,
        payload_sha256=payload_sha256,
        bounds=bounds,
        overlap_cells=overlap_cells,
    )


def _build_publication_state(
    records: Sequence[Record],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    *,
    revision: int,
) -> tuple[PublicationState, dict[str, Any]]:
    atoms = _logical_atom_rows(records, property_lookup)
    atom_map = {atom.atom_id: atom for atom in atoms}
    _require(len(atom_map) == len(atoms), "logical atom IDs are not unique")
    atom_overlap, neighbors, half_edges = _build_atom_indexes(atoms)
    provenance_index: dict[tuple[int, int], set[str]] = {}
    for atom in atoms:
        provenance_index.setdefault((atom.source_id, atom.face_id), set()).add(
            atom.atom_id
        )

    page_members: dict[str, list[PublicationAtom]] = {}
    atom_to_page: dict[str, str] = {}
    for atom in atoms:
        _owner, _shard, page_id = _page_membership(atom)
        page_members.setdefault(page_id, []).append(atom)
        atom_to_page[atom.atom_id] = page_id
    pages = {
        page_id: _build_page(page_id, members, property_lookup)
        for page_id, members in sorted(page_members.items())
    }
    page_overlap: dict[Coordinate, set[str]] = {}
    for page in pages.values():
        for coordinate in page.overlap_cells:
            page_overlap.setdefault(coordinate, set()).add(page.page_id)
    maximum_atoms = max((len(page.atom_ids) for page in pages.values()), default=0)
    maximum_triangles = max(
        (int(page.payload["triangle_count"]) for page in pages.values()), default=0
    )
    _require(
        maximum_atoms <= atlas.TARGET_PAGE_ATOMS,
        "fixed stable shard exceeded the established atom page bound",
    )
    _require(
        maximum_triangles <= atlas.TARGET_PAGE_TRIANGLES,
        "fixed stable shard exceeded the established triangle page bound",
    )
    state = PublicationState(
        atoms=atom_map,
        pages=pages,
        atom_to_page=atom_to_page,
        atom_overlap_index=atom_overlap,
        provenance_index={
            key: frozenset(value) for key, value in provenance_index.items()
        },
        page_overlap_index={
            key: frozenset(value) for key, value in page_overlap.items()
        },
        half_edge_neighbors=neighbors,
        half_edge_index=half_edges,
        revision=revision,
    )
    crossing_count = 0
    footprint_multi_cell_count = 0
    for raw_atom in atlas._make_atoms(records):
        crossing_count += int(atlas._atom_crosses_owner_plane(raw_atom))
    for atom in atoms:
        footprint_multi_cell_count += int(len(atom.overlap_cells) > 1)
    return state, {
        "atom_count": len(atoms),
        "page_count": len(pages),
        "triangle_count": len(records),
        "maximum_atoms_in_page": maximum_atoms,
        "maximum_triangles_in_page": maximum_triangles,
        "atoms_crossing_owner_cell_plane_count": crossing_count,
        "atoms_with_multi_cell_aabb_footprint_count": footprint_multi_cell_count,
        "atom_overlap_index_cell_count": len(atom_overlap),
        "page_overlap_index_cell_count": len(page_overlap),
        "half_edge_index_entry_count": len(half_edges),
        "stable_page_membership": "owner_cell_plus_fixed_sha256_nibble",
        "geometric_clip_operation_count": 0,
    }


def _condition_authority(
    solid: Any,
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
) -> tuple[list[Record], dict[str, Any]]:
    authority_records = _records_from_solid(solid)
    cleaned, emitted, _legacy_pages, stages = atlas._build_publication(
        authority_records,
        atlas._records_bounds(authority_records),
        property_lookup,
    )
    _require(
        atlas._records_digest(cleaned) == atlas._records_digest(emitted),
        "legacy page roundtrip changed conditioned authority records",
    )
    return cleaned, {
        "authority_record_count": len(authority_records),
        "conditioned_record_count": len(cleaned),
        "zero_move_retriangulation": stages["zero_move_retriangulation"],
        "bounded_patch_cleanup": stages["bounded_patch_cleanup"],
    }


def _records_by_label(
    records: Sequence[Record],
) -> dict[tuple[int, int], list[Record]]:
    grouped: dict[tuple[int, int], list[Record]] = {}
    for record in records:
        grouped.setdefault((int(record[0]), int(record[1])), []).append(record)
    return {
        key: atlas._sorted_records(value) for key, value in grouped.items()
    }


def _same_patch_geometry(
    first: Sequence[Record], second: Sequence[Record]
) -> bool:
    """Triangulation-independent equality test for one planar source-face patch."""
    if not first or not second:
        return False
    first_area = atlas._surface_area(first)
    second_area = atlas._surface_area(second)
    if abs(first_area - second_area) > max(1.0e-14, first_area * 1.0e-10):
        return False
    # Boolean output for a source face remains on that input triangle's plane.
    # Bidirectional deterministic distance plus equal area distinguishes an
    # untouched face from a cut face without depending on storage triangulation.
    return (
        atlas._directed_surface_distance(first, second) <= 1.0e-10
        and atlas._directed_surface_distance(second, first) <= 1.0e-10
    )


def _localized_zero_move_retriangulation(
    records: Sequence[Record],
    organic_ids: frozenset[int],
    progress_label: str | None = None,
) -> tuple[list[Record], dict[str, Any]]:
    """Retriangulate only edge-connected atoms seeded by bad triangles.

    Large compiler-cap polygons stay byte-for-byte exact and are handed to the
    unchanged topology/quality pipeline instead of entering an unbounded
    polygon triangulation heuristic.  This function moves no point and retains
    the same boundary/area acceptance law for every attempted atom.
    """
    started = time.perf_counter_ns()
    input_records = atlas._sorted_records(records)
    input_point_keys = {
        atlas._point_key(point)
        for _source, _face, points in input_records
        for point in np.asarray(points, dtype=np.float64)
    }
    input_area = atlas._surface_area(input_records)
    qualities = [
        float(atlas._triangle_quality(record[2])[2])
        for record in input_records
    ]
    bad_indices = {
        index
        for index, (quality, record) in enumerate(zip(qualities, input_records))
        if int(record[0]) in organic_ids
        and quality <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
    }
    excluded_cap_bad_count = sum(
        int(record[0]) not in organic_ids
        and quality <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
        for quality, record in zip(qualities, input_records)
    )
    bad_labels = frozenset(
        (int(input_records[index][0]), int(input_records[index][1]))
        for index in bad_indices
    )
    edge_index_started = time.perf_counter_ns()
    face_edges: dict[tuple[int, int, atlas.EdgeKey], list[int]] = {}
    triangle_face_edges: list[tuple[tuple[int, int, atlas.EdgeKey], ...]] = []
    quantum_edge_ledgers: dict[
        float, dict[tuple[Any, Any], list[tuple[int, Any, Any]]]
    ] = {quantum: {} for quantum in TOPOLOGY_QUANTA_METERS}
    input_quantized_degenerate_triangles = {
        str(quantum): 0 for quantum in TOPOLOGY_QUANTA_METERS
    }
    for index, (source_id, face_id, raw_points) in enumerate(input_records):
        points = np.asarray(raw_points, dtype=np.float64)
        keys: list[tuple[int, int, atlas.EdgeKey]] = []
        if (int(source_id), int(face_id)) in bad_labels:
            for first, second in (
                (points[0], points[1]),
                (points[1], points[2]),
                (points[2], points[0]),
            ):
                key = (
                    int(source_id),
                    int(face_id),
                    atlas._edge_key(first, second),
                )
                face_edges.setdefault(key, []).append(index)
                keys.append(key)
        triangle_face_edges.append(tuple(keys))
        for quantum in TOPOLOGY_QUANTA_METERS:
            quantized = [
                tuple(
                    str(value)
                    for value in exact._canonical_point(point, quantum)
                )
                for point in points
            ]
            if len(set(quantized)) != 3:
                input_quantized_degenerate_triangles[str(quantum)] += 1
            for first, second in (
                (quantized[0], quantized[1]),
                (quantized[1], quantized[2]),
                (quantized[2], quantized[0]),
            ):
                edge_key = tuple(sorted((first, second)))
                quantum_edge_ledgers[quantum].setdefault(edge_key, []).append(
                    (index, first, second)
                )
    edge_index_ms = (time.perf_counter_ns() - edge_index_started) / 1.0e6

    dirty_components: list[list[int]] = []
    visited: set[int] = set()
    for seed in sorted(bad_indices):
        if seed in visited:
            continue
        pending = [seed]
        visited.add(seed)
        component: list[int] = []
        while pending:
            current = pending.pop()
            component.append(current)
            for edge_key in triangle_face_edges[current]:
                for neighbor in face_edges[edge_key]:
                    if neighbor not in visited:
                        visited.add(neighbor)
                        pending.append(neighbor)
        dirty_components.append(sorted(component))

    replacements: dict[int, list[Record]] = {}
    retriangulated = 0
    no_better_candidate = 0
    multiple_loop_skips = 0
    oversized_atom_skips = 0
    candidate_failures = 0
    dual_quantum_ledger_reject_count = 0
    dual_quantum_ledger_rejects_by_quantum = {
        str(quantum): 0 for quantum in TOPOLOGY_QUANTA_METERS
    }
    quantized_degenerate_candidate_reject_count = 0
    max_atom_area_delta = 0.0
    maximum_dirty_atom_triangles = 0
    maximum_dirty_boundary_vertices = 0
    maximum_dirty_atom_triangulation_triplet_budget = 0
    candidate_ms = 0.0
    for atom_index, component in enumerate(dirty_components):
        atom = [input_records[index] for index in component]
        maximum_dirty_atom_triangles = max(
            maximum_dirty_atom_triangles, len(atom)
        )
        if progress_label is not None:
            _cleanup_heartbeat(
                f"{progress_label}.zero_move_dirty_atom",
                atom_index=atom_index,
                dirty_atom_count=len(dirty_components),
                triangle_count=len(atom),
                source_id=int(atom[0][0]),
                face_id=int(atom[0][1]),
            )
        atom_started = time.perf_counter_ns()
        try:
            loops, normal = exact._face_boundary_loops(atom)
            if len(loops) != 1:
                multiple_loop_skips += 1
                replacements[component[0]] = atlas._sorted_records(atom)
                continue
            boundary_vertex_count = len(loops[0])
            maximum_dirty_boundary_vertices = max(
                maximum_dirty_boundary_vertices, boundary_vertex_count
            )
            triangulation_triplet_budget = (
                math.comb(boundary_vertex_count, 3)
                if boundary_vertex_count >= 3
                else 0
            )
            maximum_dirty_atom_triangulation_triplet_budget = max(
                maximum_dirty_atom_triangulation_triplet_budget,
                triangulation_triplet_budget,
            )
            if (
                len(atom) > MAX_ZERO_MOVE_DIRTY_ATOM_TRIANGLES
                or boundary_vertex_count > MAX_ZERO_MOVE_BOUNDARY_VERTICES
                or triangulation_triplet_budget
                > MAX_ZERO_MOVE_TRIANGULATION_TRIPLET_EVALUATIONS
            ):
                oversized_atom_skips += 1
                replacements[component[0]] = atlas._sorted_records(atom)
                continue
            triangles = exact._quality_triangulate_polygon(loops[0], normal)
            source_id = int(atom[0][0])
            face_id = int(atom[0][1])
            candidate = atlas._sorted_records(
                (source_id, face_id, np.asarray(triangle, dtype=np.float64))
                for triangle in triangles
            )
            candidate_area = atlas._surface_area(candidate)
            input_atom_area = atlas._surface_area(atom)
            area_delta = abs(candidate_area - input_atom_area)
            max_atom_area_delta = max(max_atom_area_delta, area_delta)
            _require(
                area_delta <= max(1.0e-15, input_atom_area * 1.0e-10),
                "localized zero-move changed a provenance atom's area",
            )
            _require(
                atlas._record_boundary(candidate) == atlas._record_boundary(atom),
                "localized zero-move changed a provenance atom boundary",
            )
            # Raw regional Boolean output may contain a bounded quantized defect
            # that the later cross-atom cleanup must repair.  This atom-local
            # candidate is accepted only when every edge it emits/touches has
            # exactly two opposite global incidences.  Untouched input defects
            # remain diagnostic here; strict post-cleanup topology decides
            # whether the transaction may publish.
            ledger_rejected = False
            component_set = set(component)
            for quantum in TOPOLOGY_QUANTA_METERS:
                ledger = quantum_edge_ledgers[quantum]
                touched_edges: set[tuple[Any, Any]] = set()
                candidate_uses: dict[
                    tuple[Any, Any], list[tuple[int, Any, Any]]
                ] = {}
                for input_index in component:
                    source_points = np.asarray(
                        input_records[input_index][2], dtype=np.float64
                    )
                    source_keys = [
                        tuple(
                            str(value)
                            for value in exact._canonical_point(point, quantum)
                        )
                        for point in source_points
                    ]
                    for first, second in (
                        (source_keys[0], source_keys[1]),
                        (source_keys[1], source_keys[2]),
                        (source_keys[2], source_keys[0]),
                    ):
                        touched_edges.add(tuple(sorted((first, second))))
                for candidate_index, candidate_record in enumerate(candidate):
                    candidate_points = np.asarray(
                        candidate_record[2], dtype=np.float64
                    )
                    candidate_keys = [
                        tuple(
                            str(value)
                            for value in exact._canonical_point(point, quantum)
                        )
                        for point in candidate_points
                    ]
                    if len(set(candidate_keys)) != 3:
                        quantized_degenerate_candidate_reject_count += 1
                        ledger_rejected = True
                        break
                    synthetic_index = len(input_records) + candidate_index
                    for first, second in (
                        (candidate_keys[0], candidate_keys[1]),
                        (candidate_keys[1], candidate_keys[2]),
                        (candidate_keys[2], candidate_keys[0]),
                    ):
                        edge_key = tuple(sorted((first, second)))
                        touched_edges.add(edge_key)
                        candidate_uses.setdefault(edge_key, []).append(
                            (synthetic_index, first, second)
                        )
                if ledger_rejected:
                    dual_quantum_ledger_rejects_by_quantum[str(quantum)] += 1
                    break
                for edge_key in touched_edges:
                    uses = [
                        use
                        for use in ledger.get(edge_key, ())
                        if use[0] not in component_set
                    ] + candidate_uses.get(edge_key, [])
                    # A replaced atom may delete one of its old internal edge
                    # keys completely.  Such a zero-use key is absent, not an
                    # open boundary.  Every emitted key must remain a pair.
                    if not uses:
                        continue
                    if len(uses) != 2 or not (
                        uses[0][1] == uses[1][2]
                        and uses[0][2] == uses[1][1]
                    ):
                        ledger_rejected = True
                        dual_quantum_ledger_rejects_by_quantum[str(quantum)] += 1
                        break
                if ledger_rejected:
                    break
            if ledger_rejected:
                replacements[component[0]] = atlas._sorted_records(atom)
                dual_quantum_ledger_reject_count += 1
                continue
            input_minimum = min(qualities[index] for index in component)
            candidate_minimum = min(
                atlas._triangle_quality(record[2])[2] for record in candidate
            )
            candidate_bad = sum(
                atlas._triangle_quality(record[2])[2]
                <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
                for record in candidate
            )
            input_bad = sum(
                qualities[index] <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
                for index in component
            )
            if candidate_bad < input_bad or (
                candidate_bad == input_bad
                and candidate_minimum > input_minimum
            ):
                replacements[component[0]] = candidate
                retriangulated += 1
            else:
                replacements[component[0]] = atlas._sorted_records(atom)
                no_better_candidate += 1
        except atlas.GateFailure:
            raise
        except Exception:
            replacements[component[0]] = atlas._sorted_records(atom)
            candidate_failures += 1
        finally:
            candidate_ms += (time.perf_counter_ns() - atom_started) / 1.0e6

    component_members = {
        index for component in dirty_components for index in component
    }
    output: list[Record] = []
    for index, record in enumerate(input_records):
        if index in replacements:
            output.extend(replacements[index])
        elif index not in component_members:
            output.append(record)
    output = atlas._sorted_records(output)
    input_cap_records = [
        record for record in input_records if int(record[0]) not in organic_ids
    ]
    output_cap_records = [
        record for record in output if int(record[0]) not in organic_ids
    ]
    _require(
        atlas._records_digest(input_cap_records)
        == atlas._records_digest(output_cap_records),
        "localized zero-move changed compiler-cap records",
    )
    output_point_keys = {
        atlas._point_key(point)
        for _source, _face, points in output
        for point in np.asarray(points, dtype=np.float64)
    }
    _require(
        output_point_keys <= input_point_keys,
        "localized zero-move created a vertex",
    )
    output_area = atlas._surface_area(output)
    _require(
        abs(output_area - input_area) <= max(1.0e-14, input_area * 1.0e-10),
        "localized zero-move changed global surface area",
    )
    return output, {
        "method": "indexed_bad_seed_connected_provenance_atom_zero_move",
        "candidate_bound_law": (
            f"attempt <= {MAX_ZERO_MOVE_DIRTY_ATOM_TRIANGLES} triangles and "
            f"<= {MAX_ZERO_MOVE_BOUNDARY_VERTICES} boundary vertices; "
            f"<= {MAX_ZERO_MOVE_TRIANGULATION_TRIPLET_EVALUATIONS} "
            "candidate vertex triplets; "
            "oversized atoms remain exact for downstream hard gates"
        ),
        "input_triangle_count": len(input_records),
        "bad_seed_triangle_count": len(bad_indices),
        "compiler_cap_bad_triangle_count_excluded_from_retriangulation": (
            excluded_cap_bad_count
        ),
        "compiler_cap_records_changed_by_zero_move": 0,
        "input_quantized_degenerate_triangle_count_by_quantum": (
            input_quantized_degenerate_triangles
        ),
        "dirty_atom_count": len(dirty_components),
        "retriangulated_atom_count": retriangulated,
        "multiple_boundary_loop_skip_count": multiple_loop_skips,
        "oversized_atom_skip_count": oversized_atom_skips,
        "no_better_candidate_count": no_better_candidate,
        "unsupported_candidate_count": candidate_failures,
        "dual_quantum_ledger_reject_count": dual_quantum_ledger_reject_count,
        "dual_quantum_ledger_rejects_by_quantum": (
            dual_quantum_ledger_rejects_by_quantum
        ),
        "quantized_degenerate_candidate_reject_count": (
            quantized_degenerate_candidate_reject_count
        ),
        "maximum_dirty_atom_triangle_count": maximum_dirty_atom_triangles,
        "maximum_dirty_boundary_vertex_count": maximum_dirty_boundary_vertices,
        "maximum_dirty_atom_triangulation_triplet_budget": (
            maximum_dirty_atom_triangulation_triplet_budget
        ),
        "input": atlas._quality_summary(input_records),
        "output": atlas._quality_summary(output),
        "surface_area_absolute_delta_m2": abs(output_area - input_area),
        "maximum_atom_area_absolute_delta_m2": max_atom_area_delta,
        "phase_ms": {
            "edge_index_and_bad_frontier_ms": edge_index_ms,
            "dirty_atom_candidate_ms": candidate_ms,
        },
        "total_ms": (time.perf_counter_ns() - started) / 1.0e6,
        "vertex_coordinates_moved": False,
        "vertices_created": False,
        "authority_modified": False,
        "validation_reduction": False,
    }


def _eligible_bad_count(
    state: atlas.IndexedState, eligible_labels: frozenset[tuple[int, int]]
) -> int:
    count = 0
    for triangle, label in zip(state.triangles, state.labels):
        if label not in eligible_labels:
            continue
        points = np.asarray([state.vertices[index] for index in triangle])
        count += int(
            atlas._triangle_quality(points)[2]
            <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
        )
    return count


def _quantized_topology_defect_labels(
    records: Sequence[Record],
) -> tuple[frozenset[tuple[int, int]], dict[str, Any]]:
    """Identify labels directly participating in quantized topology defects."""
    ordered = atlas._sorted_records(records)
    all_defect_labels: set[tuple[int, int]] = set()
    by_quantum: dict[str, Any] = {}
    for quantum in TOPOLOGY_QUANTA_METERS:
        edge_uses: dict[
            tuple[Any, Any],
            list[tuple[int, tuple[int, int], Any, Any]],
        ] = {}
        collapsed_labels: set[tuple[int, int]] = set()
        collapsed_triangle_count = 0
        for triangle_index, (source_id, face_id, raw_points) in enumerate(ordered):
            label = (int(source_id), int(face_id))
            keys = [
                tuple(
                    str(value)
                    for value in exact._canonical_point(point, quantum)
                )
                for point in np.asarray(raw_points, dtype=np.float64)
            ]
            if len(set(keys)) != 3:
                collapsed_triangle_count += 1
                collapsed_labels.add(label)
            for first, second in (
                (keys[0], keys[1]),
                (keys[1], keys[2]),
                (keys[2], keys[0]),
            ):
                edge_uses.setdefault(tuple(sorted((first, second))), []).append(
                    (triangle_index, label, first, second)
                )
        incidence_labels: set[tuple[int, int]] = set()
        invalid_edge_count = 0
        for uses in edge_uses.values():
            valid_pair = len(uses) == 2 and (
                uses[0][2] == uses[1][3] and uses[0][3] == uses[1][2]
            )
            if valid_pair:
                continue
            invalid_edge_count += 1
            incidence_labels.update(use[1] for use in uses)
        defect_labels = collapsed_labels | incidence_labels
        all_defect_labels.update(defect_labels)
        by_quantum[str(quantum)] = {
            "collapsed_triangle_count": collapsed_triangle_count,
            "collapsed_triangle_labels": [
                list(value) for value in sorted(collapsed_labels)
            ],
            "invalid_incidence_edge_count": invalid_edge_count,
            "invalid_incidence_labels": [
                list(value) for value in sorted(incidence_labels)
            ],
            "defect_labels": [list(value) for value in sorted(defect_labels)],
        }
    return frozenset(all_defect_labels), by_quantum


@dataclass(frozen=True)
class CollapseDelta:
    edge: tuple[int, int]
    target: Any
    merged_origins: tuple[Any, ...]
    affected_triangle_indices: frozenset[int]
    replacement_triangles: Mapping[int, tuple[int, int, int] | None]
    eligible_bad_after: int
    total_bad_after: int
    minimum_quality_after: float
    diagnostics: Mapping[str, Any]


@dataclass(frozen=True)
class DirtyCleanupCache:
    edge_triangles: Mapping[tuple[int, int], tuple[int, ...]]
    neighbors: Mapping[int, frozenset[int]]
    vertex_triangles: Mapping[int, frozenset[int]]
    qualities: tuple[float, ...]
    sorted_qualities: tuple[tuple[float, int], ...]
    bad_triangles: frozenset[int]
    eligible_bad_triangles: frozenset[int]
    active_vertices: frozenset[int]
    point_vertices: Mapping[atlas.PointKey, frozenset[int]]
    coordinate_counts: tuple[Mapping[float, int], ...]
    coordinate_values: tuple[tuple[float, ...], ...]
    quantum_edge_ledgers: Mapping[
        float,
        Mapping[
            tuple[Any, Any],
            tuple[tuple[int, Any, Any], ...],
        ],
    ]


def _cleanup_heartbeat(phase: str, **values: Any) -> None:
    row = {"prototype_phase": phase, **values}
    print(json.dumps(row, sort_keys=True, separators=(",", ":")), flush=True)


def _quantized_triangle_edge_uses(
    state: atlas.IndexedState,
    triangle: tuple[int, int, int],
    triangle_index: int,
    quantum: float,
    target_by_vertex: Mapping[int, Any] | None = None,
) -> list[tuple[tuple[Any, Any], tuple[int, Any, Any]]]:
    keys: list[Any] = []
    for vertex_index in triangle:
        point = (
            target_by_vertex[vertex_index]
            if target_by_vertex is not None and vertex_index in target_by_vertex
            else state.vertices[vertex_index]
        )
        keys.append(
            tuple(str(value) for value in exact._canonical_point(point, quantum))
        )
    if len(set(keys)) != 3:
        return []
    output: list[tuple[tuple[Any, Any], tuple[int, Any, Any]]] = []
    for first, second in (
        (keys[0], keys[1]),
        (keys[1], keys[2]),
        (keys[2], keys[0]),
    ):
        output.append(
            (tuple(sorted((first, second))), (triangle_index, first, second))
        )
    return output


def _build_dirty_cleanup_cache(
    state: atlas.IndexedState,
    eligible_labels: frozenset[tuple[int, int]],
) -> DirtyCleanupCache:
    edge_triangles_raw: dict[tuple[int, int], list[int]] = {}
    neighbors_raw: dict[int, set[int]] = {}
    vertex_triangles_raw: dict[int, set[int]] = {}
    qualities: list[float] = []
    bad_triangles: set[int] = set()
    eligible_bad_triangles: set[int] = set()
    active_vertices: set[int] = set()
    ledgers_raw: dict[
        float, dict[tuple[Any, Any], list[tuple[int, Any, Any]]]
    ] = {quantum: {} for quantum in TOPOLOGY_QUANTA_METERS}
    for triangle_index, (triangle, label) in enumerate(
        zip(state.triangles, state.labels)
    ):
        points = np.asarray([state.vertices[index] for index in triangle])
        quality = float(atlas._triangle_quality(points)[2])
        qualities.append(quality)
        if quality <= TRIANGLE_CROSS_SQUARED_FLOOR_M4:
            bad_triangles.add(triangle_index)
            if label in eligible_labels:
                eligible_bad_triangles.add(triangle_index)
        for vertex_index in triangle:
            active_vertices.add(int(vertex_index))
            vertex_triangles_raw.setdefault(int(vertex_index), set()).add(
                triangle_index
            )
        for first, second in (
            (triangle[0], triangle[1]),
            (triangle[1], triangle[2]),
            (triangle[2], triangle[0]),
        ):
            first = int(first)
            second = int(second)
            edge = tuple(sorted((first, second)))
            edge_triangles_raw.setdefault(edge, []).append(triangle_index)
            neighbors_raw.setdefault(first, set()).add(second)
            neighbors_raw.setdefault(second, set()).add(first)
        for quantum in TOPOLOGY_QUANTA_METERS:
            for edge, use in _quantized_triangle_edge_uses(
                state, triangle, triangle_index, quantum
            ):
                ledgers_raw[quantum].setdefault(edge, []).append(use)

    point_vertices_raw: dict[atlas.PointKey, set[int]] = {}
    coordinate_counts_raw: list[dict[float, int]] = [dict(), dict(), dict()]
    for vertex_index in active_vertices:
        point = np.asarray(state.vertices[vertex_index], dtype=np.float64)
        point_vertices_raw.setdefault(atlas._point_key(point), set()).add(
            vertex_index
        )
        for axis in range(3):
            value = float(point[axis])
            coordinate_counts_raw[axis][value] = (
                coordinate_counts_raw[axis].get(value, 0) + 1
            )
    return DirtyCleanupCache(
        edge_triangles={
            edge: tuple(indices) for edge, indices in edge_triangles_raw.items()
        },
        neighbors={
            vertex: frozenset(values) for vertex, values in neighbors_raw.items()
        },
        vertex_triangles={
            vertex: frozenset(values)
            for vertex, values in vertex_triangles_raw.items()
        },
        qualities=tuple(qualities),
        sorted_qualities=tuple(
            sorted((quality, index) for index, quality in enumerate(qualities))
        ),
        bad_triangles=frozenset(bad_triangles),
        eligible_bad_triangles=frozenset(eligible_bad_triangles),
        active_vertices=frozenset(active_vertices),
        point_vertices={
            key: frozenset(values) for key, values in point_vertices_raw.items()
        },
        coordinate_counts=tuple(coordinate_counts_raw),
        coordinate_values=tuple(
            tuple(sorted(values)) for values in coordinate_counts_raw
        ),
        quantum_edge_ledgers={
            quantum: {
                edge: tuple(uses) for edge, uses in ledger.items()
            }
            for quantum, ledger in ledgers_raw.items()
        },
    )


def _candidate_bounds_from_cache(
    state: atlas.IndexedState,
    cache: DirtyCleanupCache,
    edge: tuple[int, int],
    target: Any,
) -> tuple[float, ...]:
    output_min: list[float] = []
    output_max: list[float] = []
    removed = set(edge)
    for axis in range(3):
        counts = cache.coordinate_counts[axis]
        values = cache.coordinate_values[axis]
        remaining_min = math.inf
        remaining_max = -math.inf
        for value in values:
            removed_here = sum(
                float(state.vertices[index][axis]) == value for index in removed
            )
            if int(counts[value]) > removed_here:
                remaining_min = value
                break
        for value in reversed(values):
            removed_here = sum(
                float(state.vertices[index][axis]) == value for index in removed
            )
            if int(counts[value]) > removed_here:
                remaining_max = value
                break
        target_value = float(target[axis])
        output_min.append(min(remaining_min, target_value))
        output_max.append(max(remaining_max, target_value))
    return tuple(output_min + output_max)


def _minimum_unaffected_quality(
    cache: DirtyCleanupCache, affected: frozenset[int]
) -> float:
    for quality, triangle_index in cache.sorted_qualities:
        if triangle_index not in affected:
            return quality
    return math.inf


def _evaluate_collapse_delta(
    state: atlas.IndexedState,
    cache: DirtyCleanupCache,
    edge: tuple[int, int],
    authority_bounds: Sequence[float],
    eligible_labels: frozenset[tuple[int, int]],
) -> CollapseDelta | None:
    first, second = edge
    incident = cache.edge_triangles.get(tuple(sorted(edge)), ())
    if len(incident) != 2:
        return None
    opposites = {
        index
        for triangle_index in incident
        for index in state.triangles[triangle_index]
        if index not in edge
    }
    common_neighbors = (
        (set(cache.neighbors.get(first, frozenset())) - {second})
        & (set(cache.neighbors.get(second, frozenset())) - {first})
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
    target_key = atlas._point_key(target)
    if set(cache.point_vertices.get(target_key, frozenset())) - set(edge):
        return None
    if (
        atlas._bounds_delta(
            _candidate_bounds_from_cache(state, cache, edge, target),
            authority_bounds,
        )
        > atlas.SAME_BOUNDS_TOLERANCE_METERS
    ):
        return None

    affected = frozenset(
        set(cache.vertex_triangles.get(first, frozenset()))
        | set(cache.vertex_triangles.get(second, frozenset()))
    )
    replacement_triangles: dict[int, tuple[int, int, int] | None] = {}
    removed_labels: list[tuple[int, int]] = []
    new_qualities: list[float] = []
    new_bad_count = 0
    new_eligible_bad_count = 0
    changed_triangle_count = 0
    removed_triangle_count = 0
    for triangle_index in sorted(affected):
        triangle = state.triangles[triangle_index]
        label = state.labels[triangle_index]
        mapped = tuple(first if index == second else int(index) for index in triangle)
        if len(set(mapped)) != 3:
            if first in triangle and second in triangle:
                replacement_triangles[triangle_index] = None
                removed_triangle_count += 1
                removed_labels.append(label)
                continue
            return None
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
        quality = float(atlas._triangle_quality(new_points)[2])
        if quality <= 1.0e-24:
            return None
        replacement_triangles[triangle_index] = mapped
        new_qualities.append(quality)
        is_bad = quality <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
        new_bad_count += int(is_bad)
        new_eligible_bad_count += int(is_bad and label in eligible_labels)
    if removed_triangle_count != 2:
        return None

    old_bad_affected = len(cache.bad_triangles & affected)
    old_eligible_bad_affected = len(cache.eligible_bad_triangles & affected)
    total_bad_after = len(cache.bad_triangles) - old_bad_affected + new_bad_count
    eligible_bad_after = (
        len(cache.eligible_bad_triangles)
        - old_eligible_bad_affected
        + new_eligible_bad_count
    )
    minimum_quality_after = min(
        [_minimum_unaffected_quality(cache, affected), *new_qualities]
    )

    # Validate the candidate's one-ring delta at both quanta and require every
    # emitted/touched edge to become a valid opposite pair.  Untouched input
    # defects remain visible to the strict final full-topology gate.
    for quantum in TOPOLOGY_QUANTA_METERS:
        ledger = cache.quantum_edge_ledgers[quantum]
        touched_edges: set[tuple[Any, Any]] = set()
        new_uses: dict[tuple[Any, Any], list[tuple[int, Any, Any]]] = {}
        for triangle_index in affected:
            for edge_key, _use in _quantized_triangle_edge_uses(
                state,
                state.triangles[triangle_index],
                triangle_index,
                quantum,
            ):
                touched_edges.add(edge_key)
        target_by_vertex = {first: target}
        for triangle_index, triangle in replacement_triangles.items():
            if triangle is None:
                continue
            uses = _quantized_triangle_edge_uses(
                state,
                triangle,
                triangle_index,
                quantum,
                target_by_vertex,
            )
            if len(uses) != 3:
                return None
            for edge_key, use in uses:
                touched_edges.add(edge_key)
                new_uses.setdefault(edge_key, []).append(use)
        for edge_key in touched_edges:
            uses = [
                use
                for use in ledger.get(edge_key, ())
                if use[0] not in affected
            ] + new_uses.get(edge_key, [])
            # An internal one-ring edge may disappear entirely when its two
            # incident triangles are removed/retriangulated.  Zero incidences
            # means the ledger key is deleted; it is not a boundary edge.
            if not uses:
                continue
            if len(uses) != 2:
                return None
            if not (uses[0][1] == uses[1][2] and uses[0][2] == uses[1][1]):
                return None

    return CollapseDelta(
        edge=edge,
        target=target.copy(),
        merged_origins=merged_origins,
        affected_triangle_indices=affected,
        replacement_triangles=replacement_triangles,
        eligible_bad_after=eligible_bad_after,
        total_bad_after=total_bad_after,
        minimum_quality_after=minimum_quality_after,
        diagnostics={
            "edge_length_m": edge_length,
            "maximum_merged_origin_displacement_m": maximum_merged_displacement,
            "changed_neighbor_triangle_count": changed_triangle_count,
            "removed_triangle_count": removed_triangle_count,
            "removed_paired_provenance_faces": [
                [int(source_id), int(face_id)]
                for source_id, face_id in sorted(set(removed_labels))
            ],
            "edge_digest": _sha256_json(
                sorted((atlas._point_key(first_point), atlas._point_key(second_point)))
            ),
            "candidate_validation_scope": "affected_vertex_one_ring_plus_dual_quantum_edge_ledger",
        },
    )


def _commit_collapse_delta(
    state: atlas.IndexedState, delta: CollapseDelta
) -> atlas.IndexedState:
    first, second = delta.edge
    candidate = atlas._copy_state(state)
    candidate.vertices[first] = np.asarray(delta.target, dtype=np.float64).copy()
    candidate.origins[first] = delta.merged_origins
    output_triangles: list[tuple[int, int, int]] = []
    output_labels: list[tuple[int, int]] = []
    for triangle_index, (triangle, label) in enumerate(
        zip(state.triangles, state.labels)
    ):
        if triangle_index not in delta.affected_triangle_indices:
            output_triangles.append(triangle)
            output_labels.append(label)
            continue
        replacement = delta.replacement_triangles[triangle_index]
        if replacement is not None:
            output_triangles.append(replacement)
            output_labels.append(label)
    candidate.triangles = output_triangles
    candidate.labels = output_labels
    candidate.vertices[second] = np.asarray(delta.target, dtype=np.float64).copy()
    candidate.origins[second] = ()
    return candidate


def _bounded_dirty_cleanup(
    records: Sequence[Record],
    authority_bounds: Sequence[float],
    eligible_labels: frozenset[tuple[int, int]],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    source_tags: Mapping[int, str],
    progress_label: str | None = None,
) -> tuple[list[Record], dict[str, Any]]:
    """Apply the 20 um law with cached one-ring collapse deltas.

    One full dual-quantum input audit records defects handed forward by the raw
    regional Boolean and zero-move stage.  Each candidate then touches only its
    vertex star and the corresponding 1e-8 / 1e-7 edge-ledger entries.  The
    deterministic winning delta is committed, caches are rebuilt, and the final
    full dual-quantum audit remains a strict publication gate.
    """
    total_started = time.perf_counter_ns()
    state = atlas._records_to_indexed(records)
    input_records = atlas._indexed_to_records(state)
    collapse_rows: list[dict[str, Any]] = []
    timing_ms: dict[str, float] = {
        "full_topology_pre_ms": 0.0,
        "cache_build_ms": 0.0,
        "collapse_delta_evaluation_ms": 0.0,
        "collapse_commit_ms": 0.0,
        "full_topology_post_ms": 0.0,
    }
    evaluation_count = 0
    def heartbeat(phase: str, **values: Any) -> None:
        label = f"{progress_label}.{phase}" if progress_label else phase
        _cleanup_heartbeat(label, **values)

    heartbeat(
        "dirty_cleanup_pre_topology",
        triangle_count=len(state.triangles),
        eligible_label_count=len(eligible_labels),
    )
    phase_started = time.perf_counter_ns()
    input_topology = {
        str(quantum): atlas._topology_for_records(input_records, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    timing_ms["full_topology_pre_ms"] = (
        time.perf_counter_ns() - phase_started
    ) / 1.0e6
    input_topology_passes = all(
        atlas._topology_passes(value) for value in input_topology.values()
    )
    eligible_bad_input_count = _eligible_bad_count(state, eligible_labels)
    _require(
        eligible_bad_input_count > 0,
        "dirty cleanup requires at least one explicitly eligible bad input triangle",
    )
    heartbeat(
        "dirty_cleanup_pre_diagnostics_complete",
        input_topology_passes=input_topology_passes,
        eligible_bad_input_count=eligible_bad_input_count,
    )
    for collapse_index in range(atlas.MAX_CLEANUP_COLLAPSES):
        phase_started = time.perf_counter_ns()
        cache = _build_dirty_cleanup_cache(state, eligible_labels)
        timing_ms["cache_build_ms"] += (
            time.perf_counter_ns() - phase_started
        ) / 1.0e6
        eligible_before = len(cache.eligible_bad_triangles)
        if eligible_before == 0:
            break
        total_bad_before = len(cache.bad_triangles)
        minimum_before = (
            cache.sorted_qualities[0][0]
            if cache.sorted_qualities
            else math.inf
        )
        candidate_edges: set[tuple[int, int]] = set()
        for triangle_index in cache.eligible_bad_triangles:
            triangle = state.triangles[triangle_index]
            for first, second in (
                (triangle[0], triangle[1]),
                (triangle[1], triangle[2]),
                (triangle[2], triangle[0]),
            ):
                candidate_edges.add(tuple(sorted((int(first), int(second)))))
        heartbeat(
            "dirty_cleanup_collapse_evaluation",
            collapse_index=collapse_index,
            candidate_edge_count=len(candidate_edges),
            eligible_bad_before=eligible_before,
            total_bad_before=total_bad_before,
        )
        accepted: list[tuple[tuple[Any, ...], CollapseDelta, dict[str, Any]]] = []
        phase_started = time.perf_counter_ns()
        for edge in sorted(
            candidate_edges,
            key=lambda value: tuple(
                sorted(
                    (
                        atlas._point_key(state.vertices[value[0]]),
                        atlas._point_key(state.vertices[value[1]]),
                    )
                )
            ),
        ):
            evaluation_count += 1
            delta = _evaluate_collapse_delta(
                state,
                cache,
                edge,
                authority_bounds,
                eligible_labels,
            )
            if delta is None:
                continue
            if (
                delta.eligible_bad_after >= eligible_before
                or delta.total_bad_after >= total_bad_before
            ):
                continue
            diagnostics = dict(delta.diagnostics)
            diagnostics.update(
                {
                    "collapse_index": collapse_index,
                    "eligible_bad_before": eligible_before,
                    "eligible_bad_after": delta.eligible_bad_after,
                    "total_bad_before": total_bad_before,
                    "total_bad_after": delta.total_bad_after,
                    "minimum_quality_before_m4": minimum_before,
                    "minimum_quality_after_m4": delta.minimum_quality_after,
                }
            )
            score = (
                delta.eligible_bad_after,
                delta.total_bad_after,
                float(diagnostics["maximum_merged_origin_displacement_m"]),
                -delta.minimum_quality_after,
                str(diagnostics["edge_digest"]),
            )
            accepted.append((score, delta, diagnostics))
        timing_ms["collapse_delta_evaluation_ms"] += (
            time.perf_counter_ns() - phase_started
        ) / 1.0e6
        if not accepted:
            break
        accepted.sort(key=lambda item: item[0])
        _score, winner, row = accepted[0]
        phase_started = time.perf_counter_ns()
        state = _commit_collapse_delta(state, winner)
        timing_ms["collapse_commit_ms"] += (
            time.perf_counter_ns() - phase_started
        ) / 1.0e6
        collapse_rows.append(row)
        heartbeat(
            "dirty_cleanup_collapse_committed",
            collapse_index=collapse_index,
            eligible_bad_after=winner.eligible_bad_after,
            total_bad_after=winner.total_bad_after,
            edge_digest=row["edge_digest"],
        )

    output = atlas._indexed_to_records(state)
    heartbeat(
        "dirty_cleanup_post_topology",
        triangle_count=len(state.triangles),
        collapse_count=len(collapse_rows),
    )
    phase_started = time.perf_counter_ns()
    output_topology = {
        str(quantum): atlas._topology_for_records(output, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    timing_ms["full_topology_post_ms"] = (
        time.perf_counter_ns() - phase_started
    ) / 1.0e6
    _require(
        all(atlas._topology_passes(value) for value in output_topology.values()),
        "dirty cleanup output is not closed/oriented at both weld quanta",
    )
    input_groups = _records_by_label(input_records)
    output_groups = _records_by_label(output)
    changed_labels = {
        label
        for label in set(input_groups) | set(output_groups)
        if atlas._records_digest(input_groups.get(label, []))
        != atlas._records_digest(output_groups.get(label, []))
    }
    lineage_rows: list[dict[str, Any]] = []
    for source_id, face_id in sorted(changed_labels):
        if (source_id, face_id) not in property_lookup:
            continue
        material_index, surface_index = property_lookup[(source_id, face_id)]
        lineage_rows.append(
            {
                "source_tag": source_tags.get(source_id, "unknown"),
                "source_original_id": source_id,
                "source_face_id": face_id,
                "material_index": int(material_index),
                "surface_index": int(surface_index),
                "input_triangle_count": len(input_groups.get((source_id, face_id), [])),
                "output_triangle_count": len(output_groups.get((source_id, face_id), [])),
            }
        )
    maximum_displacement = atlas._active_origin_displacement(state)
    _require(
        maximum_displacement
        <= MAX_PATCH_VERTEX_DISPLACEMENT_METERS + 1.0e-15,
        "dirty conditioner exceeded the established 20 um displacement gate",
    )
    return output, {
        "method": "closed_unsplit_regional_dirty_face_midpoint_edge_collapse",
        "candidate_evaluator": "cached_vertex_star_CollapseDelta_with_dual_quantum_edge_ledgers",
        "full_topology_audit_count": 2,
        "full_topology_before": input_topology,
        "full_topology_before_passes": input_topology_passes,
        "full_topology_after": output_topology,
        "collapse_delta_evaluation_count": evaluation_count,
        "phase_ms": timing_ms,
        "total_ms": (time.perf_counter_ns() - total_started) / 1.0e6,
        "eligible_source_face_count": len(eligible_labels),
        "eligible_bad_input_count": eligible_bad_input_count,
        "eligible_bad_output_count": _eligible_bad_count(state, eligible_labels),
        "collapse_count": len(collapse_rows),
        "maximum_allowed_vertex_displacement_m": MAX_PATCH_VERTEX_DISPLACEMENT_METERS,
        "maximum_actual_cumulative_vertex_displacement_m": maximum_displacement,
        "changed_source_faces": [list(value) for value in sorted(changed_labels)],
        "moved_triangle_lineage": lineage_rows,
        "collapses": collapse_rows,
        "input_topology_is_recorded_diagnostic": True,
        "strict_output_topology_gate_retained": True,
        "validation_reduction": False,
    }


def _atom_edge_keys(atom: PublicationAtom) -> frozenset[atlas.EdgeKey]:
    edges: set[atlas.EdgeKey] = set()
    for _source_id, _face_id, raw_points in atom.records:
        points = np.asarray(raw_points, dtype=np.float64)
        for first, second in (
            (points[0], points[1]),
            (points[1], points[2]),
            (points[2], points[0]),
        ):
            edges.add(atlas._edge_key(first, second))
    return frozenset(edges)


def _index_replacement_atoms(
    atoms: Sequence[PublicationAtom],
) -> ReplacementAtomIndexes:
    """Preindex a replacement set once; overlay loops never rescan all candidates."""
    by_lineage: dict[str, PublicationAtom] = {}
    by_cell: dict[Coordinate, set[str]] = {}
    by_label: dict[tuple[int, int], set[str]] = {}
    by_edge: dict[atlas.EdgeKey, set[str]] = {}
    by_page: dict[str, set[str]] = {}
    for atom in atoms:
        _require(
            atom.lineage_id not in by_lineage,
            f"duplicate replacement lineage {atom.lineage_id}",
        )
        expected_version = f"av:{atom.payload_sha256}"
        _require(
            atom.version_id == expected_version,
            f"replacement atom version is not content addressed: {atom.lineage_id}",
        )
        by_lineage[atom.lineage_id] = atom
        for coordinate in atom.overlap_cells:
            by_cell.setdefault(coordinate, set()).add(atom.lineage_id)
        by_label.setdefault((atom.source_id, atom.face_id), set()).add(
            atom.lineage_id
        )
        for edge in _atom_edge_keys(atom):
            by_edge.setdefault(edge, set()).add(atom.lineage_id)
        by_page.setdefault(_page_membership(atom)[2], set()).add(atom.lineage_id)
    return ReplacementAtomIndexes(
        by_lineage=by_lineage,
        by_cell={key: frozenset(value) for key, value in by_cell.items()},
        by_label={key: frozenset(value) for key, value in by_label.items()},
        by_edge={key: frozenset(value) for key, value in by_edge.items()},
        by_page={key: frozenset(value) for key, value in by_page.items()},
    )


def _directed_edge_uses(
    records: Sequence[Record],
) -> dict[atlas.EdgeKey, list[tuple[atlas.PointKey, atlas.PointKey]]]:
    uses: dict[atlas.EdgeKey, list[tuple[atlas.PointKey, atlas.PointKey]]] = {}
    for _source_id, _face_id, raw_points in records:
        points = np.asarray(raw_points, dtype=np.float64)
        keys = [atlas._point_key(point) for point in points]
        for first, second in (
            (keys[0], keys[1]),
            (keys[1], keys[2]),
            (keys[2], keys[0]),
        ):
            edge = tuple(sorted((first, second)))
            uses.setdefault(edge, []).append((first, second))  # type: ignore[arg-type]
    return uses


def _opposite_edge_uses(
    first: tuple[atlas.PointKey, atlas.PointKey],
    second: tuple[atlas.PointKey, atlas.PointKey],
) -> bool:
    return first[0] == second[1] and first[1] == second[0]


def _atom_touches_jurisdiction_perimeter(
    atom: PublicationAtom,
    selected_space: frozenset[Coordinate],
) -> bool:
    """Conservative perimeter test for closure expansion.

    An atom whose AABB footprint leaves the loaded jurisdiction, or occupies a
    loaded cell adjacent to an unloaded cell in a direction crossed by its
    bounds, cannot be safely rebuilt from the current regional Boolean.  The
    caller must expand the jurisdiction or abort atomically.
    """
    if not set(atom.overlap_cells) <= set(selected_space):
        return True
    epsilon = exact.PLANE_EPSILON
    for coordinate in atom.overlap_cells:
        for axis in range(3):
            lower = coordinate[axis] * CHUNK_SIZE_METERS
            upper = lower + CHUNK_SIZE_METERS
            for side, plane in ((-1, lower), (1, upper)):
                neighbor = list(coordinate)
                neighbor[axis] += side
                if tuple(neighbor) in selected_space:
                    continue
                bound_index = axis if side < 0 else axis + 3
                if abs(float(atom.bounds[bound_index]) - plane) <= epsilon:
                    return True
    return False


def _close_replacement_interface(
    publication: PublicationState,
    regional_organic_records: Sequence[Record],
    initial_labels: frozenset[tuple[int, int]],
    selected_space: frozenset[Coordinate],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    counters: AccessCounters,
) -> tuple[
    frozenset[tuple[int, int]],
    frozenset[str],
    tuple[PublicationAtom, ...],
    frozenset[str],
    dict[str, Any],
]:
    """Reach a two-sided retained/replacement interface by transitive rebuild.

    The replacement patch is open only where it meets retained publication.
    At convergence its boundary edge multiset equals the old cut boundary
    exactly, and each incidence is opposite to the retained incidence.  A
    mismatch expands through the precomputed half-edge graph by whole atom
    lineage.  Expansion is refused at the regional compiler-cap perimeter.
    """
    regional_groups = _records_by_label(regional_organic_records)
    labels = set(initial_labels)
    seed_labels = set(initial_labels)
    rebuilt_retained_labels: set[tuple[int, int]] = set()
    _require(bool(labels), "replacement interface closure has no seed labels")
    loaded_lineages: set[str] = set()
    iteration_rows: list[dict[str, Any]] = []
    maximum_iterations = len(regional_groups) + 1

    def load(lineage_id: str) -> PublicationAtom:
        if lineage_id not in loaded_lineages:
            counters.atom_objects_loaded += 1
            loaded_lineages.add(lineage_id)
        return publication.atoms[lineage_id]

    for iteration in range(maximum_iterations):
        removed_ids: set[str] = set()
        for label in sorted(labels):
            removed_ids.update(publication.provenance_index.get(label, frozenset()))
        _require(bool(removed_ids), "closure seed removed no existing atom lineage")

        regional_seed_records = [
            record
            for label in sorted(seed_labels)
            for record in regional_groups.get(label, [])
        ]
        rebuilt_retained_records = [
            record
            for label in sorted(rebuilt_retained_labels)
            for lineage_id in sorted(
                publication.provenance_index.get(label, frozenset())
            )
            for record in load(lineage_id).records
        ]
        replacement_records_raw = (
            regional_seed_records + rebuilt_retained_records
        )
        replacement_records_any, conforming = exact._make_triangle_soup_conforming(
            replacement_records_raw
        )
        replacement_records: list[Record] = [
            (int(record[-3]), int(record[-2]), np.asarray(record[-1], dtype=np.float64))
            for record in replacement_records_any
        ]
        replacement_atoms = tuple(
            _logical_atom_rows(replacement_records, property_lookup)
        )
        replacement_indexes = _index_replacement_atoms(replacement_atoms)
        new_uses = _directed_edge_uses(replacement_records)
        new_boundary = {
            edge: uses[0] for edge, uses in new_uses.items() if len(uses) == 1
        }
        _require(
            all(len(uses) <= 2 for uses in new_uses.values()),
            "replacement patch contains a nonmanifold internal edge",
        )
        _require(
            all(
                len(uses) != 2 or _opposite_edge_uses(uses[0], uses[1])
                for uses in new_uses.values()
            ),
            "replacement patch contains a same-direction internal edge",
        )

        old_records = [
            record
            for lineage_id in sorted(removed_ids)
            for record in load(lineage_id).records
        ]
        old_uses = _directed_edge_uses(old_records)
        retained_interface: dict[
            atlas.EdgeKey, tuple[atlas.PointKey, atlas.PointKey]
        ] = {}
        frontier_ids: set[str] = set()
        for edge, uses in old_uses.items():
            if len(uses) != 1:
                continue
            counters.half_edge_neighbor_lookups += 1
            retained_ids = set(
                publication.half_edge_index.get(edge, frozenset())
            ) - removed_ids
            for lineage_id in retained_ids:
                atom = load(lineage_id)
                atom_uses = _directed_edge_uses(atom.records).get(edge, [])
                for use in atom_uses:
                    if edge in retained_interface:
                        raise ProofFailure(
                            "retained interface has more than one incidence for an edge"
                        )
                    retained_interface[edge] = use
                frontier_ids.add(lineage_id)

        mismatched_edges = set(new_boundary) ^ set(retained_interface)
        winding_mismatches = {
            edge
            for edge in set(new_boundary) & set(retained_interface)
            if not _opposite_edge_uses(
                new_boundary[edge], retained_interface[edge]
            )
        }
        valid = not mismatched_edges and not winding_mismatches
        iteration_rows.append(
            {
                "iteration": iteration,
                "rebuilt_label_count": len(labels),
                "removed_lineage_count": len(removed_ids),
                "replacement_atom_count": len(replacement_atoms),
                "replacement_boundary_edge_count": len(new_boundary),
                "retained_interface_edge_count": len(retained_interface),
                "edge_multiset_mismatch_count": len(mismatched_edges),
                "opposite_incidence_mismatch_count": len(winding_mismatches),
                "frontier_atom_count": len(frontier_ids),
                "rebuilt_retained_label_count": len(rebuilt_retained_labels),
                "local_zero_move_interface_conforming": conforming,
                "replacement_index_counts": {
                    "cell": len(replacement_indexes.by_cell),
                    "label": len(replacement_indexes.by_label),
                    "edge": len(replacement_indexes.by_edge),
                    "page": len(replacement_indexes.by_page),
                },
            }
        )
        if valid:
            closure_ids = set(removed_ids) | frontier_ids
            removed_perimeter_ids = [
                lineage_id
                for lineage_id in sorted(removed_ids)
                if _atom_touches_jurisdiction_perimeter(
                    load(lineage_id), selected_space
                )
            ]
            replacement_perimeter_ids = [
                atom.lineage_id
                for atom in replacement_atoms
                if _atom_touches_jurisdiction_perimeter(atom, selected_space)
            ]
            return (
                frozenset(labels),
                frozenset(removed_ids),
                replacement_atoms,
                frozenset(closure_ids),
                {
                    "converged": True,
                    "iteration_count": iteration + 1,
                    "transitive_neighbor_expansion_count": iteration,
                    "final_interface_edge_count": len(new_boundary),
                    "every_interface_edge_has_two_opposite_incidences": True,
                    "jurisdiction_perimeter_touched": False,
                    "removed_atom_perimeter_touch_count": len(
                        removed_perimeter_ids
                    ),
                    "replacement_atom_perimeter_touch_count": len(
                        replacement_perimeter_ids
                    ),
                    "removed_atom_perimeter_touch_examples": (
                        removed_perimeter_ids[:20]
                    ),
                    "replacement_atom_perimeter_touch_examples": (
                        replacement_perimeter_ids[:20]
                    ),
                    "loaded_atom_count": len(loaded_lineages),
                    "iterations": iteration_rows,
                },
            )

        expandable_ids = frontier_ids - removed_ids
        _require(
            bool(expandable_ids),
            "replacement interface cannot close and has no indexed neighbor to expand",
        )
        for lineage_id in sorted(expandable_ids):
            atom = load(lineage_id)
            _require(
                not _atom_touches_jurisdiction_perimeter(atom, selected_space),
                "replacement closure reached regional compiler-cap perimeter; "
                "expand jurisdiction or abort: "
                f"{atom.lineage_id} label={(atom.source_id, atom.face_id)} "
                f"bounds={atom.bounds} cells={atom.overlap_cells}",
            )
            labels.add((atom.source_id, atom.face_id))
            rebuilt_retained_labels.add((atom.source_id, atom.face_id))

    raise ProofFailure("replacement interface closure exceeded its finite label bound")


def _indexed_dirty_selection(
    publication: PublicationState,
    edit_cells: Sequence[Coordinate],
    regional_organic_records: Sequence[Record],
    counters: AccessCounters,
) -> tuple[
    frozenset[str],
    frozenset[str],
    frozenset[tuple[int, int]],
    dict[str, Any],
]:
    """Load dirty seeds through footprints, then one precomputed half-edge ring."""
    seed_ids: set[str] = set()
    for coordinate in edit_cells:
        counters.atom_index_cell_lookups += 1
        seed_ids.update(publication.atom_overlap_index.get(coordinate, frozenset()))
    loaded_ids: set[str] = set()

    def load(atom_id: str) -> PublicationAtom:
        if atom_id not in loaded_ids:
            counters.atom_objects_loaded += 1
            loaded_ids.add(atom_id)
        return publication.atoms[atom_id]

    candidate_faces = {
        (load(atom_id).source_id, load(atom_id).face_id)
        for atom_id in sorted(seed_ids)
    }
    regional_groups = _records_by_label(regional_organic_records)
    changed_faces: set[tuple[int, int]] = set()
    changed_seed_ids: set[str] = set()
    comparisons = 0
    for label in sorted(candidate_faces):
        old_ids = publication.provenance_index.get(label, frozenset())
        old_records = [
            record
            for atom_id in sorted(old_ids)
            for record in load(atom_id).records
        ]
        comparisons += 1
        if not _same_patch_geometry(old_records, regional_groups.get(label, [])):
            changed_faces.add(label)
            changed_seed_ids.update(old_ids)

    closure_ids = set(changed_seed_ids)
    for atom_id in sorted(changed_seed_ids):
        counters.half_edge_neighbor_lookups += 1
        neighbors = publication.half_edge_neighbors.get(atom_id, frozenset())
        closure_ids.update(neighbors)
        for neighbor_id in neighbors:
            load(neighbor_id)
    return (
        frozenset(changed_seed_ids),
        frozenset(closure_ids),
        frozenset(changed_faces),
        {
            "edit_cell_count": len(edit_cells),
            "footprint_seed_atom_count": len(seed_ids),
            "changed_seed_atom_count": len(changed_seed_ids),
            "half_edge_closure_atom_count": len(closure_ids),
            "loaded_atom_count": len(loaded_ids),
            "triangulation_independent_face_comparison_count": comparisons,
            "changed_seed_source_faces": [
                list(value) for value in sorted(changed_faces)
            ],
        },
    )


def _overlay_publication(
    base: PublicationState,
    removed_ids: frozenset[str],
    candidate_atoms: Sequence[PublicationAtom],
    closure_ids: frozenset[str],
    edit_cells: Sequence[Coordinate],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    counters: AccessCounters,
) -> tuple[PublicationState, dict[str, Any], frozenset[str]]:
    """Replace atom/page/index keys without walking any base mapping."""
    candidate_indexes = _index_replacement_atoms(candidate_atoms)
    replacement_atoms: dict[str, PublicationAtom] = {}
    reused_atom_ids: set[str] = set()
    for atom in candidate_indexes.by_lineage.values():
        previous = base.atoms.get(atom.atom_id)
        if previous is not None and previous.version_id == atom.version_id:
            replacement_atoms[atom.atom_id] = previous
            reused_atom_ids.add(atom.atom_id)
        else:
            replacement_atoms[atom.atom_id] = atom
    final_removed_ids = frozenset(set(removed_ids) - set(replacement_atoms))
    post_atoms: Mapping[str, PublicationAtom] = PersistentOverlay(
        base.atoms, final_removed_ids, replacement_atoms
    )

    touched_atom_cells: set[Coordinate] = set()
    old_atoms: dict[str, PublicationAtom] = {}
    for atom_id in removed_ids:
        atom = base.atoms[atom_id]
        old_atoms[atom_id] = atom
        touched_atom_cells.update(atom.overlap_cells)
    touched_atom_cells.update(candidate_indexes.by_cell)
    atom_overlap_replacements: dict[Coordinate, frozenset[str]] = {}
    atom_overlap_removals: set[Coordinate] = set()
    for coordinate in sorted(touched_atom_cells):
        members = set(base.atom_overlap_index.get(coordinate, frozenset()))
        members.difference_update(removed_ids)
        members.update(candidate_indexes.by_cell.get(coordinate, frozenset()))
        if members:
            atom_overlap_replacements[coordinate] = frozenset(members)
        else:
            atom_overlap_removals.add(coordinate)
    post_atom_overlap: Mapping[Coordinate, frozenset[str]] = PersistentOverlay(
        base.atom_overlap_index,
        atom_overlap_removals,
        atom_overlap_replacements,
    )

    touched_labels = {
        (atom.source_id, atom.face_id) for atom in old_atoms.values()
    } | set(candidate_indexes.by_label)
    provenance_replacements: dict[tuple[int, int], frozenset[str]] = {}
    provenance_removals: set[tuple[int, int]] = set()
    for label in touched_labels:
        members = set(base.provenance_index.get(label, frozenset()))
        members.difference_update(removed_ids)
        members.update(candidate_indexes.by_label.get(label, frozenset()))
        if members:
            provenance_replacements[label] = frozenset(members)
        else:
            provenance_removals.add(label)
    post_provenance: Mapping[tuple[int, int], frozenset[str]] = PersistentOverlay(
        base.provenance_index, provenance_removals, provenance_replacements
    )

    touched_edges: set[atlas.EdgeKey] = set()
    for atom in old_atoms.values():
        touched_edges.update(_atom_edge_keys(atom))
    touched_edges.update(candidate_indexes.by_edge)
    edge_replacements: dict[atlas.EdgeKey, frozenset[str]] = {}
    edge_removals: set[atlas.EdgeKey] = set()
    neighbor_affected_ids: set[str] = set(closure_ids)
    for edge in touched_edges:
        members = set(base.half_edge_index.get(edge, frozenset()))
        neighbor_affected_ids.update(members)
        members.difference_update(removed_ids)
        members.update(candidate_indexes.by_edge.get(edge, frozenset()))
        neighbor_affected_ids.update(members)
        if members:
            edge_replacements[edge] = frozenset(members)
        else:
            edge_removals.add(edge)
    post_half_edges: Mapping[atlas.EdgeKey, frozenset[str]] = PersistentOverlay(
        base.half_edge_index, edge_removals, edge_replacements
    )
    neighbor_replacements: dict[str, frozenset[str]] = {}
    neighbor_removals = set(final_removed_ids)
    for atom_id in sorted(neighbor_affected_ids - set(final_removed_ids)):
        if atom_id not in post_atoms:
            continue
        atom = post_atoms[atom_id]
        neighbors: set[str] = set()
        for edge in _atom_edge_keys(atom):
            counters.half_edge_neighbor_lookups += 1
            neighbors.update(post_half_edges.get(edge, frozenset()))
        neighbors.discard(atom_id)
        neighbor_replacements[atom_id] = frozenset(neighbors)
    post_neighbors: Mapping[str, frozenset[str]] = PersistentOverlay(
        base.half_edge_neighbors, neighbor_removals, neighbor_replacements
    )

    page_closure_ids: set[str] = set()
    for coordinate in edit_cells:
        counters.page_index_cell_lookups += 1
        page_closure_ids.update(
            base.page_overlap_index.get(coordinate, frozenset())
        )
    for atom_id in closure_ids:
        page_id = base.atom_to_page.get(atom_id)
        if page_id is not None:
            page_closure_ids.add(page_id)

    old_page_ids = {
        base.atom_to_page[atom_id]
        for atom_id in removed_ids
        if atom_id in base.atom_to_page
    }
    new_page_ids = set(candidate_indexes.by_page)
    # New content-addressed versions may move lineage to a different owner
    # page.  Such pages join the closure explicitly; every old page must have
    # been reached through edit-cell or transitive atom closure indexing.
    page_closure_ids.update(new_page_ids)
    required_page_ids = old_page_ids | new_page_ids
    _require(
        old_page_ids <= page_closure_ids,
        "removed atom page escaped the indexed page closure",
    )
    touched_page_ids = required_page_ids & page_closure_ids
    _require(
        touched_page_ids == required_page_ids,
        "page closure failed to contain the complete rebuild set",
    )
    page_replacements: dict[str, PublicationPage] = {}
    page_removals: set[str] = set()
    new_by_page: dict[str, set[str]] = {}
    for page_id, lineage_ids in candidate_indexes.by_page.items():
        new_by_page[page_id] = set(lineage_ids)
    loaded_page_ids: set[str] = set()
    for page_id in sorted(touched_page_ids):
        members: set[str] = set()
        if page_id in base.pages:
            counters.page_objects_loaded += 1
            loaded_page_ids.add(page_id)
            members.update(base.pages[page_id].atom_ids)
        members.difference_update(removed_ids)
        members.update(new_by_page.get(page_id, set()))
        if members:
            page_replacements[page_id] = _build_page(
                page_id,
                [post_atoms[atom_id] for atom_id in sorted(members)],
                property_lookup,
            )
        else:
            page_removals.add(page_id)
    post_pages: Mapping[str, PublicationPage] = PersistentOverlay(
        base.pages, page_removals, page_replacements
    )

    atom_to_page_replacements = {
        atom_id: _page_membership(post_atoms[atom_id])[2]
        for atom_id in replacement_atoms
    }
    post_atom_to_page: Mapping[str, str] = PersistentOverlay(
        base.atom_to_page, final_removed_ids, atom_to_page_replacements
    )
    touched_page_cells: set[Coordinate] = set()
    for page_id in touched_page_ids:
        old_page = base.pages.get(page_id)
        if old_page is not None:
            touched_page_cells.update(old_page.overlap_cells)
        new_page = page_replacements.get(page_id)
        if new_page is not None:
            touched_page_cells.update(new_page.overlap_cells)
    page_overlap_replacements: dict[Coordinate, frozenset[str]] = {}
    page_overlap_removals: set[Coordinate] = set()
    for coordinate in sorted(touched_page_cells):
        members = set(base.page_overlap_index.get(coordinate, frozenset()))
        members.difference_update(touched_page_ids)
        members.update(
            page.page_id
            for page in page_replacements.values()
            if coordinate in page.overlap_cells
        )
        if members:
            page_overlap_replacements[coordinate] = frozenset(members)
        else:
            page_overlap_removals.add(coordinate)
    post_page_overlap: Mapping[Coordinate, frozenset[str]] = PersistentOverlay(
        base.page_overlap_index,
        page_overlap_removals,
        page_overlap_replacements,
    )
    post = PublicationState(
        atoms=post_atoms,
        pages=post_pages,
        atom_to_page=post_atom_to_page,
        atom_overlap_index=post_atom_overlap,
        provenance_index=post_provenance,
        page_overlap_index=post_page_overlap,
        half_edge_neighbors=post_neighbors,
        half_edge_index=post_half_edges,
        revision=base.revision + 1,
    )
    return post, {
        "removed_atom_count": len(removed_ids),
        "replacement_atom_count": len(replacement_atoms),
        "replacement_atom_index_counts": {
            "cell": len(candidate_indexes.by_cell),
            "label": len(candidate_indexes.by_label),
            "edge": len(candidate_indexes.by_edge),
            "page": len(candidate_indexes.by_page),
        },
        "same_payload_atom_object_reuse_count": len(reused_atom_ids),
        "atom_index_key_rebuild_count": len(touched_atom_cells),
        "atom_index_rebuilt_keys": [
            list(value) for value in sorted(touched_atom_cells)
        ],
        "provenance_index_rebuilt_keys": [
            list(value) for value in sorted(touched_labels)
        ],
        "half_edge_index_key_rebuild_count": len(touched_edges),
        "half_edge_index_rebuilt_keys": [
            _canonical_access_key(value) for value in sorted(touched_edges)
        ],
        "neighbor_atom_key_rebuild_count": len(neighbor_replacements),
        "neighbor_atom_rebuilt_keys": sorted(neighbor_replacements),
        "page_overlap_closure_count": len(page_closure_ids),
        "page_overlap_closure_ids": sorted(page_closure_ids),
        "page_closure_constrained_rebuild": touched_page_ids == required_page_ids,
        "page_object_load_count": len(loaded_page_ids),
        "loaded_page_ids": sorted(loaded_page_ids),
        "page_rebuild_count": len(page_replacements),
        "rebuilt_page_ids": sorted(touched_page_ids),
        "replaced_page_ids": sorted(page_replacements),
        "rebuilt_page_payload_sha256": {
            page_id: page_replacements[page_id].payload_sha256
            for page_id in sorted(page_replacements)
        },
        "page_remove_count": len(page_removals),
        "removed_page_ids": sorted(page_removals),
        "page_index_key_rebuild_count": len(touched_page_cells),
        "page_index_rebuilt_keys": [
            list(value) for value in sorted(touched_page_cells)
        ],
        "touched_page_ids": sorted(touched_page_ids),
        "stable_shard_membership_cascade_count": 0,
    }, frozenset(touched_page_ids)


def _guard_publication_state(
    publication: PublicationState,
    guard: AccessGuard,
    counters: AccessCounters,
    trace: AccessTrace,
) -> PublicationState:
    """Wrap every persistent atlas map used by the timed transaction."""
    return PublicationState(
        atoms=GuardedReadMapping(
            publication.atoms, guard, counters, "atom", "atoms", trace
        ),
        pages=GuardedReadMapping(
            publication.pages, guard, counters, "page", "pages", trace
        ),
        atom_to_page=GuardedReadMapping(
            publication.atom_to_page,
            guard,
            counters,
            "atom",
            "atom_to_page",
            trace,
        ),
        atom_overlap_index=GuardedReadMapping(
            publication.atom_overlap_index,
            guard,
            counters,
            "atom",
            "atom_overlap_index",
            trace,
        ),
        provenance_index=GuardedReadMapping(
            publication.provenance_index,
            guard,
            counters,
            "atom",
            "provenance_index",
            trace,
        ),
        page_overlap_index=GuardedReadMapping(
            publication.page_overlap_index,
            guard,
            counters,
            "page",
            "page_overlap_index",
            trace,
        ),
        half_edge_neighbors=GuardedReadMapping(
            publication.half_edge_neighbors,
            guard,
            counters,
            "atom",
            "half_edge_neighbors",
            trace,
        ),
        half_edge_index=GuardedReadMapping(
            publication.half_edge_index,
            guard,
            counters,
            "atom",
            "half_edge_index",
            trace,
        ),
        revision=publication.revision,
    )


def _incremental_add(
    storage: exact.WorkpieceState,
    publication: PublicationState,
    operand: Any,
    organic_ids: frozenset[int],
    operand_source_id: int,
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    source_tags: Mapping[int, str],
    progress_label: str | None = None,
) -> EditOutcome:
    """Execute one instrumented, index-addressed regional publication edit."""
    counters = AccessCounters()
    access_guard = AccessGuard()
    access_trace = AccessTrace()
    storage = exact.WorkpieceState(
        GuardedReadMapping(
            storage.fragments,
            access_guard,
            counters,
            "fragment",
            "fragments",
            access_trace,
        ),
        storage.revision,
    )
    publication = _guard_publication_state(
        publication, access_guard, counters, access_trace
    )
    phase_ms: dict[str, float] = {}
    total_started = time.perf_counter_ns()

    def heartbeat(phase: str, **values: Any) -> None:
        if progress_label is None:
            return
        _cleanup_heartbeat(f"{progress_label}.{phase}", **values)

    heartbeat("start", storage_revision=storage.revision)

    phase_started = time.perf_counter_ns()
    selected_space = frozenset(
        exact._coordinates_for_bounds(operand.bounding_box(), HALO_RINGS)
    )
    selected_fragments: dict[Coordinate, exact.Fragment] = {}
    for coordinate in sorted(selected_space):
        counters.fragment_coordinate_lookups += 1
        if coordinate in storage.fragments:
            selected_fragments[coordinate] = storage.fragments[coordinate]
            counters.fragment_objects_loaded += 1
    _require(bool(selected_fragments), "operand halo selected no storage fragment")
    edit_cells = _cells_for_bounds(tuple(float(v) for v in operand.bounding_box()))
    phase_ms["indexed_region_selection_ms"] = (
        time.perf_counter_ns() - phase_started
    ) / 1.0e6
    heartbeat(
        "indexed_region_selection_complete",
        candidate_coordinate_count=len(selected_space),
        selected_fragment_count=len(selected_fragments),
    )

    phase_started = time.perf_counter_ns()
    assembled, assembly = exact._assemble_region_from_fragments(
        selected_fragments, set(organic_ids)
    )
    _require(
        exact._is_ok(assembled) and not assembled.is_empty(),
        "selected capped storage fragments did not assemble",
    )
    phase_ms["capped_fragment_assembly_ms"] = (
        time.perf_counter_ns() - phase_started
    ) / 1.0e6
    heartbeat("capped_fragment_assembly_complete")

    phase_started = time.perf_counter_ns()
    region_result = assembled + operand
    _require(
        exact._is_ok(region_result) and not region_result.is_empty(),
        "single regional Boolean failed",
    )
    _require(
        len(region_result.decompose()) == 1,
        "single regional Boolean is disconnected",
    )
    phase_ms["single_local_boolean_ms"] = (
        time.perf_counter_ns() - phase_started
    ) / 1.0e6
    heartbeat("single_local_boolean_complete")

    # Split-back is storage authority.  These closed fragments retain compiler
    # caps; publication below is built separately from the unsplit result.
    phase_started = time.perf_counter_ns()
    changed_fragments = exact._split_to_chunks(region_result)
    _require(
        set(changed_fragments) <= set(selected_space),
        "regional result escaped the fixed two-ring jurisdiction",
    )
    post_storage = exact.WorkpieceState(
        exact.FragmentOverlay(
            storage.fragments,
            set(selected_fragments),
            changed_fragments,
        ),
        storage.revision + 1,
    )
    phase_ms["closed_storage_split_back_ms"] = (
        time.perf_counter_ns() - phase_started
    ) / 1.0e6
    heartbeat(
        "closed_storage_split_back_complete",
        changed_fragment_count=len(changed_fragments),
    )

    phase_started = time.perf_counter_ns()
    region_records = _records_from_solid(region_result)
    region_cap_records = [
        record for record in region_records if int(record[0]) not in organic_ids
    ]
    _require(bool(region_cap_records), "unsplit regional result has no perimeter caps")
    nested_started = time.perf_counter_ns()
    heartbeat("zero_move_retriangulation_start", triangle_count=len(region_records))
    zero_records, zero_diagnostics = _localized_zero_move_retriangulation(
        region_records, organic_ids, progress_label
    )
    phase_ms["zero_move_retriangulation_ms"] = (
        time.perf_counter_ns() - nested_started
    ) / 1.0e6
    heartbeat("zero_move_retriangulation_complete", triangle_count=len(zero_records))
    nested_started = time.perf_counter_ns()
    zero_move_topology = {
        str(quantum): atlas._topology_for_records(zero_records, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    zero_move_topology_passes = {
        quantum: atlas._topology_passes(value)
        for quantum, value in zero_move_topology.items()
    }
    zero_diagnostics = {
        **zero_diagnostics,
        "full_recombined_topology_by_quantum": zero_move_topology,
        "full_recombined_topology_passes_by_quantum": zero_move_topology_passes,
        "topology_is_diagnostic_before_cross_atom_cleanup": True,
    }
    phase_ms["zero_move_full_topology_diagnostic_ms"] = (
        time.perf_counter_ns() - nested_started
    ) / 1.0e6
    heartbeat(
        "zero_move_full_topology_diagnostic_complete",
        topology_passes=all(zero_move_topology_passes.values()),
    )
    zero_organic = [
        record for record in zero_records if int(record[0]) in organic_ids
    ]
    nested_started = time.perf_counter_ns()
    (
        changed_seed_ids,
        closure_ids,
        changed_seed_faces,
        selection,
    ) = _indexed_dirty_selection(
        publication, edit_cells, zero_organic, counters
    )
    phase_ms["indexed_dirty_selection_ms"] = (
        time.perf_counter_ns() - nested_started
    ) / 1.0e6
    heartbeat(
        "indexed_dirty_selection_complete",
        changed_seed_face_count=len(changed_seed_faces),
    )
    zero_groups = _records_by_label(zero_organic)
    operand_faces = frozenset(
        label for label in zero_groups if label[0] == operand_source_id
    )
    _require(bool(operand_faces), "regional Boolean published no operand provenance")
    eligible_labels = frozenset(set(changed_seed_faces) | set(operand_faces))
    remaining_bad_organic_labels = frozenset(
        (int(source_id), int(face_id))
        for source_id, face_id, points in zero_organic
        if atlas._triangle_quality(points)[2]
        <= TRIANGLE_CROSS_SQUARED_FLOOR_M4
    )
    topology_defect_labels, topology_defect_diagnostics = (
        _quantized_topology_defect_labels(zero_records)
    )
    missing_topology_defect_eligible_labels = (
        topology_defect_labels - eligible_labels
    )
    _require(
        not missing_topology_defect_eligible_labels,
        "zero-move topology defects involve labels outside the explicitly selected cleanup labels: "
        + repr(sorted(missing_topology_defect_eligible_labels)),
    )
    unrelated_bad_organic_labels = remaining_bad_organic_labels - eligible_labels
    zero_diagnostics = {
        **zero_diagnostics,
        "explicit_cleanup_eligible_labels": [
            list(value) for value in sorted(eligible_labels)
        ],
        "remaining_bad_organic_labels": [
            list(value) for value in sorted(remaining_bad_organic_labels)
        ],
        "unrelated_bad_organic_labels_not_selected_for_republication": [
            list(value) for value in sorted(unrelated_bad_organic_labels)
        ],
        "quantized_topology_defect_labels": [
            list(value) for value in sorted(topology_defect_labels)
        ],
        "quantized_topology_defect_diagnostics": topology_defect_diagnostics,
        "all_quantized_topology_defect_labels_explicitly_eligible": True,
    }
    heartbeat(
        "dirty_cleanup_eligibility_verified",
        eligible_label_count=len(eligible_labels),
        remaining_bad_organic_label_count=len(remaining_bad_organic_labels),
        unrelated_bad_organic_label_count=len(unrelated_bad_organic_labels),
        topology_defect_label_count=len(topology_defect_labels),
    )
    nested_started = time.perf_counter_ns()
    conditioned_records, cleanup = _bounded_dirty_cleanup(
        zero_records,
        atlas._records_bounds(region_records),
        eligible_labels,
        property_lookup,
        source_tags,
        progress_label,
    )
    phase_ms["dirty_cleanup_ms"] = (
        time.perf_counter_ns() - nested_started
    ) / 1.0e6
    heartbeat(
        "dirty_cleanup_complete",
        collapse_count=cleanup["collapse_count"],
    )
    _require(
        int(cleanup["eligible_bad_output_count"]) == 0,
        "dirty conditioner left a subthreshold triangle on changed faces",
    )
    conditioned_organic = [
        record for record in conditioned_records if int(record[0]) in organic_ids
    ]
    cleanup_changed_labels = {
        (int(row[0]), int(row[1])) for row in cleanup["changed_source_faces"]
    }
    initial_publish_labels = frozenset(
        set(changed_seed_faces)
        | set(operand_faces)
        | (cleanup_changed_labels & set(_records_by_label(conditioned_organic)))
    )
    nested_started = time.perf_counter_ns()
    (
        publish_labels,
        removed_ids,
        new_atoms,
        expanded_closure,
        interface_closure,
    ) = _close_replacement_interface(
        publication,
        conditioned_organic,
        initial_publish_labels,
        selected_space,
        property_lookup,
        counters,
    )
    phase_ms["replacement_interface_closure_ms"] = (
        time.perf_counter_ns() - nested_started
    ) / 1.0e6
    heartbeat(
        "replacement_interface_closure_complete",
        iteration_count=interface_closure["iteration_count"],
    )
    changed_records = [
        record for atom in new_atoms for record in atom.records
    ]
    changed_quality = atlas._quality_summary(changed_records)
    _require(
        int(changed_quality["double_subthreshold_triangle_count"]) == 0
        and int(changed_quality["float32_subthreshold_triangle_count"]) == 0,
        "changed publication records violate the strict 1e-16 quality gate",
    )
    phase_ms["unsplit_dirty_atom_conditioning_ms"] = (
        time.perf_counter_ns() - phase_started
    ) / 1.0e6

    phase_started = time.perf_counter_ns()
    post_publication, overlay, rebuilt_page_ids = _overlay_publication(
        publication,
        removed_ids,
        new_atoms,
        expanded_closure,
        edit_cells,
        property_lookup,
        counters,
    )
    phase_ms["persistent_page_overlay_ms"] = (
        time.perf_counter_ns() - phase_started
    ) / 1.0e6
    heartbeat(
        "persistent_page_overlay_complete",
        rebuilt_page_count=len(rebuilt_page_ids),
    )
    phase_ms["instrumented_transaction_ms"] = (
        time.perf_counter_ns() - total_started
    ) / 1.0e6

    counter_values = vars(counters).copy()
    no_global_scan = (
        counters.global_fragment_iterations == 0
        and counters.global_atom_iterations == 0
        and counters.global_page_iterations == 0
    )
    _require(no_global_scan, "instrumented transaction performed a forbidden global scan")
    access_guard.active = False
    heartbeat(
        "complete",
        transaction_ms=phase_ms["instrumented_transaction_ms"],
    )
    return EditOutcome(
        storage=post_storage,
        publication=post_publication,
        metrics={
            "phase_ms": phase_ms,
            "access_counters": counter_values,
            "access_trace": access_trace.snapshot(),
            "no_global_fragment_atom_page_scan": no_global_scan,
            "remote_triangle_counter_is_inert_and_not_used_as_proof": True,
            "selected_fragment_count": len(selected_fragments),
            "candidate_coordinate_count": len(selected_space),
            "changed_storage_fragment_count": len(changed_fragments),
            "unsplit_region_triangle_count": len(region_records),
            "unsplit_region_organic_triangle_count": len(region_records) - len(region_cap_records),
            "unsplit_region_storage_cap_triangle_count": len(region_cap_records),
            "publication_compiler_cap_triangle_count": 0,
            "assembly": assembly,
            "zero_move_retriangulation": zero_diagnostics,
            "dirty_selection": selection,
            "dirty_conditioner": cleanup,
            "replacement_interface_closure": interface_closure,
            "changed_record_quality": changed_quality,
            "changed_source_faces": [list(value) for value in sorted(publish_labels)],
            "new_atom_count": len(new_atoms),
            "removed_atom_count": len(removed_ids),
            "half_edge_closure_atom_count": len(expanded_closure),
            "overlay": overlay,
            "one_local_boolean_count": 1,
            "geometric_page_clip_operation_count": 0,
        },
        unsplit_region_result=region_result,
        unsplit_region_records=tuple(region_records),
        published_new_atoms=tuple(new_atoms),
        removed_atom_ids=frozenset(removed_ids),
        rebuilt_page_ids=rebuilt_page_ids,
    )


def _roundtrip_publication_state(
    publication: PublicationState,
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
) -> tuple[list[Record], list[dict[str, Any]], dict[str, Any]]:
    """Consume the exact post-overlay page arrays and audit both atom IDs."""
    atoms = sorted(publication.atoms.values(), key=lambda atom: atom.lineage_id)
    records = atlas._sorted_records(
        record for atom in atoms for record in atom.records
    )
    pages = [
        dict(page.payload)
        for page in sorted(
            publication.pages.values(), key=lambda page: page.page_id
        )
    ]
    decoded_pages, emitted_records, roundtrip = atlas._roundtrip_owner_pages(
        pages,
        property_lookup,
        records,
        [atom.payload_sha256 for atom in atoms],
    )
    atom_by_lineage = {atom.lineage_id: atom for atom in atoms}
    emitted_lineages: list[str] = []
    emitted_versions: list[str] = []
    for page in decoded_pages:
        page_id = str(page.get("page_id", ""))
        for entry in page.get("atoms", []):
            _require(isinstance(entry, dict), "decoded incremental atom entry is malformed")
            lineage_id = str(entry.get("atom_lineage_id", ""))
            version_id = str(entry.get("atom_version_id", ""))
            _require(
                lineage_id in atom_by_lineage,
                f"decoded page contains unknown atom lineage {lineage_id}",
            )
            atom = atom_by_lineage[lineage_id]
            _require(
                publication.atom_to_page.get(lineage_id) == page_id,
                f"decoded atom lineage is in the wrong page: {lineage_id}",
            )
            _require(
                version_id == atom.version_id == f"av:{atom.payload_sha256}",
                f"decoded atom version is not content addressed: {lineage_id}",
            )
            _require(
                str(entry.get("atom_sha256", "")) == atom.payload_sha256,
                f"decoded atom payload hash differs: {lineage_id}",
            )
            emitted_lineages.append(lineage_id)
            emitted_versions.append(version_id)
    _require(
        len(emitted_lineages) == len(set(emitted_lineages)) == len(atoms),
        "post-overlay pages duplicated or omitted an atom lineage",
    )
    _require(
        set(emitted_lineages) == set(atom_by_lineage),
        "post-overlay page lineage set differs from atlas authority",
    )
    roundtrip = dict(roundtrip)
    roundtrip.update(
        {
            "stable_lineage_ids_verified": True,
            "content_addressed_version_ids_verified": True,
            "atom_lineage_count": len(emitted_lineages),
            "distinct_atom_version_count": len(set(emitted_versions)),
            "lineage_manifest_sha256": _sha256_json(sorted(emitted_lineages)),
            "version_manifest_sha256": _sha256_json(sorted(emitted_versions)),
        }
    )
    return emitted_records, decoded_pages, roundtrip


def _source_material_lineage_audit(
    records: Sequence[Record],
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    source_tags: Mapping[int, str],
    expected_source_ids: frozenset[int],
) -> dict[str, Any]:
    """Keep source lineage distinct even when all fixture faces share material 0."""
    counts: dict[str, int] = {}
    material_counts: dict[str, int] = {}
    invalid_labels: list[list[int]] = []
    invalid_sources: list[int] = []
    for source_id, face_id, _points in records:
        source_id = int(source_id)
        face_id = int(face_id)
        label = (source_id, face_id)
        if source_id not in expected_source_ids:
            invalid_sources.append(source_id)
            continue
        if label not in property_lookup or source_id not in source_tags:
            invalid_labels.append([source_id, face_id])
            continue
        material_index, surface_index = property_lookup[label]
        tag = source_tags[source_id]
        counts[tag] = counts.get(tag, 0) + 1
        key = f"{tag}:material_{material_index}:surface_{surface_index}"
        material_counts[key] = material_counts.get(key, 0) + 1
    expected_tags = {source_tags[source_id] for source_id in expected_source_ids}
    present_tags = set(counts)
    material_pairs = sorted(
        {
            property_lookup[(int(source_id), int(face_id))]
            for source_id, face_id, _points in records
            if (int(source_id), int(face_id)) in property_lookup
        }
    )
    passed = (
        not invalid_sources
        and not invalid_labels
        and present_tags == expected_tags
        and material_pairs == [(0, 0)]
    )
    return {
        "passed": passed,
        "source_triangle_counts_by_tag": counts,
        "source_material_surface_triangle_counts": material_counts,
        "expected_source_tags": sorted(expected_tags),
        "present_source_tags": sorted(present_tags),
        "material_surface_pairs": [list(value) for value in material_pairs],
        "fixture_single_material_does_not_collapse_source_lineage": (
            material_pairs == [(0, 0)] and present_tags == expected_tags
        ),
        "invalid_source_count": len(invalid_sources),
        "invalid_source_ids": sorted(set(invalid_sources)),
        "invalid_label_count": len(invalid_labels),
        "invalid_label_examples": invalid_labels[:20],
    }


def _caps_are_paired(caps: Mapping[str, Any]) -> bool:
    return (
        int(caps["unpaired_cap_count"]) == 0
        and int(caps["outline_mismatch_count"]) == 0
        and int(caps["orientation_mismatch_count"]) == 0
        and float(caps["maximum_area_delta_m2"]) <= exact.SEAM_AREA_TOLERANCE
    )


def _selected_fragment_identity_manifest(
    state: exact.WorkpieceState,
    selected_space: frozenset[Coordinate],
) -> list[dict[str, Any]]:
    return [
        {
            "coordinate": list(coordinate),
            "object_id": id(state.fragments[coordinate]),
            "mesh_sha256": state.fragments[coordinate].digest,
        }
        for coordinate in sorted(selected_space)
        if coordinate in state.fragments
    ]


def _indexed_atom_manifest(
    publication: PublicationState,
    cells: Sequence[Coordinate],
) -> list[dict[str, Any]]:
    lineage_ids: set[str] = set()
    for coordinate in cells:
        lineage_ids.update(
            publication.atom_overlap_index.get(coordinate, frozenset())
        )
    return [
        {
            "lineage_id": lineage_id,
            "version_id": publication.atoms[lineage_id].version_id,
            "payload_sha256": publication.atoms[lineage_id].payload_sha256,
        }
        for lineage_id in sorted(lineage_ids)
    ]


def _retained_local_atom_manifest(
    before: PublicationState,
    after: PublicationState,
    removed_ids: frozenset[str],
    cells: Sequence[Coordinate],
) -> list[dict[str, Any]]:
    return [
        row
        for row in _indexed_atom_manifest(before, cells)
        if row["lineage_id"] not in removed_ids
        and after.atoms.get(row["lineage_id"]) is before.atoms.get(
            row["lineage_id"]
        )
        and after.atoms[row["lineage_id"]].version_id == row["version_id"]
        and after.atoms[row["lineage_id"]].payload_sha256
        == row["payload_sha256"]
    ]


def _replacement_atom_manifest(edit: EditOutcome) -> list[dict[str, Any]]:
    return [
        {
            "lineage_id": atom.lineage_id,
            "version_id": atom.version_id,
            "payload_sha256": atom.payload_sha256,
        }
        for atom in sorted(
            edit.published_new_atoms, key=lambda atom: atom.lineage_id
        )
    ]


def _rebuilt_page_manifest(edit: EditOutcome) -> list[dict[str, Any]]:
    return [
        {
            "page_id": page_id,
            "payload_sha256": edit.publication.pages[page_id].payload_sha256,
            "atom_lineage_ids": list(edit.publication.pages[page_id].atom_ids),
        }
        for page_id in sorted(edit.rebuilt_page_ids)
        if page_id in edit.publication.pages
    ]


def _remote_publication_identity_audit(
    before: PublicationState,
    after: PublicationState,
    selected_space: frozenset[Coordinate],
) -> dict[str, Any]:
    """Exhaustive untimed identity/hash audit outside B's halo jurisdiction."""
    remote_atoms = [
        atom
        for atom in before.atoms.values()
        if set(atom.overlap_cells).isdisjoint(selected_space)
    ]
    remote_pages = [
        page
        for page in before.pages.values()
        if set(page.overlap_cells).isdisjoint(selected_space)
    ]
    atom_failures = [
        atom.lineage_id
        for atom in remote_atoms
        if after.atoms.get(atom.lineage_id) is not atom
        or after.atoms[atom.lineage_id].payload_sha256 != atom.payload_sha256
        or after.atoms[atom.lineage_id].version_id != atom.version_id
    ]
    page_failures = [
        page.page_id
        for page in remote_pages
        if after.pages.get(page.page_id) is not page
        or after.pages[page.page_id].payload_sha256 != page.payload_sha256
    ]
    return {
        "passed": not atom_failures and not page_failures,
        "definition": "whole atom/page AABB footprint disjoint from B two-ring selected_space",
        "remote_atom_count": len(remote_atoms),
        "remote_page_count": len(remote_pages),
        "atom_object_or_payload_change_count": len(atom_failures),
        "page_object_or_payload_change_count": len(page_failures),
        "atom_failure_examples": atom_failures[:20],
        "page_failure_examples": page_failures[:20],
    }


def _semantic_fragment_manifest(
    state: exact.WorkpieceState,
    coordinates: Iterable[Coordinate],
) -> list[dict[str, Any]]:
    return [
        {
            "coordinate": list(coordinate),
            "mesh_sha256": state.fragments[coordinate].digest,
        }
        for coordinate in sorted(set(coordinates))
        if coordinate in state.fragments
    ]


def _changed_fragment_manifest(
    before: exact.WorkpieceState,
    after: exact.WorkpieceState,
) -> list[dict[str, Any]]:
    coordinates = sorted(set(before.fragments) | set(after.fragments))
    return [
        {
            "coordinate": list(coordinate),
            "before_sha256": (
                None
                if coordinate not in before.fragments
                else before.fragments[coordinate].digest
            ),
            "after_sha256": (
                None
                if coordinate not in after.fragments
                else after.fragments[coordinate].digest
            ),
        }
        for coordinate in coordinates
        if before.fragments.get(coordinate) is not after.fragments.get(coordinate)
    ]


def _semantic_changed_fragment_work_manifest(
    before: exact.WorkpieceState,
    after: exact.WorkpieceState,
    organic_ids: frozenset[int],
) -> list[dict[str, Any]]:
    """Compact allocator-independent identity for every changed fragment."""
    rows: list[dict[str, Any]] = []
    coordinates = sorted(set(before.fragments) | set(after.fragments))
    for coordinate in coordinates:
        before_fragment = before.fragments.get(coordinate)
        after_fragment = after.fragments.get(coordinate)
        if before_fragment is after_fragment:
            continue
        after_bits = (
            None
            if after_fragment is None
            else _bit_exact_fragment_triangle_manifest(
                after_fragment, organic_ids
            )
        )
        rows.append(
            {
                "coordinate": list(coordinate),
                "before_semantic_mesh_sha256": (
                    None
                    if before_fragment is None
                    else exact._semantic_mesh_digest(
                        before_fragment.manifold, set(organic_ids)
                    )
                ),
                "after_semantic_mesh_sha256": (
                    None
                    if after_fragment is None
                    else exact._semantic_mesh_digest(
                        after_fragment.manifold, set(organic_ids)
                    )
                ),
                "after_bit_exact": (
                    None
                    if after_bits is None
                    else {
                        "all_oriented_geometry_sha256": after_bits[
                            "all_oriented_triangle_multiset_sha256"
                        ],
                        "all_oriented_geometry_triangle_count": after_bits[
                            "triangle_count"
                        ],
                        "organic_source_face_oriented_geometry_sha256": (
                            after_bits[
                                "organic_source_face_oriented_triangle_multiset_sha256"
                            ]
                        ),
                        "organic_source_face_triangle_count": after_bits[
                            "organic_triangle_count"
                        ],
                        "compiler_cap_geometry_winding_sha256": after_bits[
                            "compiler_cap_oriented_triangle_multiset_sha256"
                        ],
                        "compiler_cap_triangle_count": after_bits[
                            "compiler_cap_triangle_count"
                        ],
                        "orientation_law": after_bits["orientation_law"],
                    }
                ),
            }
        )
    return rows


def _trace_events(
    trace: Mapping[str, Any],
    map_name: str,
    operation: str | None = None,
) -> list[tuple[str, Any, Any]]:
    rows: list[tuple[str, Any, Any]] = []
    for event_map, event_operation, key_json, result_json in trace["events"]:
        if event_map != map_name:
            continue
        if operation is not None and event_operation != operation:
            continue
        rows.append(
            (
                str(event_operation),
                json.loads(str(key_json)),
                json.loads(str(result_json)),
            )
        )
    return rows


def _traced_page_and_rail_read_audit(
    trace: Mapping[str, Any],
    before: PublicationState,
    rebuilt_page_ids: frozenset[str],
    rail_original_id: int,
    forbidden_page_ids: frozenset[str],
) -> dict[str, Any]:
    """Resolve traced index results into page reach and real rail geometry reads."""
    reached_page_ids: set[str] = set(rebuilt_page_ids)
    page_lookup_ids: list[str] = []
    atom_lookup_ids: list[str] = []
    for operation, key, _result in _trace_events(trace, "pages"):
        if isinstance(key, str):
            reached_page_ids.add(key)
            if operation == "lookup":
                page_lookup_ids.append(key)
    for operation, key, result in _trace_events(trace, "atom_to_page"):
        if operation == "lookup" and isinstance(result, str):
            reached_page_ids.add(result)
    for operation, _key, result in _trace_events(trace, "page_overlap_index"):
        if operation == "lookup" and isinstance(result, list):
            reached_page_ids.update(
                value for value in result if isinstance(value, str)
            )
    for operation, key, _result in _trace_events(trace, "atoms"):
        if operation == "lookup" and isinstance(key, str):
            atom_lookup_ids.append(key)

    rail_atom_lookup_ids = [
        atom_id
        for atom_id in atom_lookup_ids
        if atom_id in before.atoms
        and int(before.atoms[atom_id].source_id) == rail_original_id
    ]
    rail_atom_triangle_reads = sum(
        len(before.atoms[atom_id].records) for atom_id in rail_atom_lookup_ids
    )
    rail_page_lookup_rows: list[dict[str, Any]] = []
    rail_page_triangle_reads = 0
    for page_id in page_lookup_ids:
        if page_id not in before.pages:
            continue
        rail_member_ids = [
            atom_id
            for atom_id in before.pages[page_id].atom_ids
            if atom_id in before.atoms
            and int(before.atoms[atom_id].source_id) == rail_original_id
        ]
        if not rail_member_ids:
            continue
        triangle_count = sum(
            len(before.atoms[atom_id].records) for atom_id in rail_member_ids
        )
        rail_page_triangle_reads += triangle_count
        rail_page_lookup_rows.append(
            {
                "page_id": page_id,
                "rail_atom_ids": rail_member_ids,
                "rail_triangle_count": triangle_count,
            }
        )
    forbidden_reached = sorted(reached_page_ids & set(forbidden_page_ids))
    return {
        "passed": (
            not forbidden_reached
            and not rail_atom_lookup_ids
            and not rail_page_lookup_rows
            and rail_atom_triangle_reads == 0
            and rail_page_triangle_reads == 0
        ),
        "reached_page_ids": sorted(reached_page_ids),
        "forbidden_ungrafted_page_ids": sorted(forbidden_page_ids),
        "forbidden_reached_page_ids": forbidden_reached,
        "rail_atom_lookup_event_count": len(rail_atom_lookup_ids),
        "rail_atom_lookup_ids": rail_atom_lookup_ids,
        "rail_atom_triangle_reads": rail_atom_triangle_reads,
        "rail_page_lookup_event_count": len(rail_page_lookup_rows),
        "rail_page_lookup_rows": rail_page_lookup_rows,
        "rail_page_triangle_reads": rail_page_triangle_reads,
        "remote_triangle_read_count": (
            rail_atom_triangle_reads + rail_page_triangle_reads
        ),
        "claim_law": (
            "literal rail atom-record reads and conservative rail triangles exposed "
            "by traced page lookups are derived from actual traced keys plus prestate "
            "membership; the inert counter is ignored"
        ),
    }


def _fragment_contains_source(
    fragment: exact.Fragment, source_id: int
) -> bool:
    _vertices, _triangles, source_ids, _face_ids = exact._triangle_records(
        fragment.manifold
    )
    return any(int(value) == source_id for value in source_ids)


def _symmetric_remote_rail_identity_audit(
    before_storage: exact.WorkpieceState,
    after_storage: exact.WorkpieceState,
    before_publication: PublicationState,
    after_publication: PublicationState,
    selected_space: frozenset[Coordinate],
    rail_original_id: int,
    edit: EditOutcome,
) -> dict[str, Any]:
    """Require exact symmetric remote rail keys, objects, and payload hashes."""
    before_atom_ids = {
        atom.lineage_id
        for atom in before_publication.atoms.values()
        if int(atom.source_id) == rail_original_id
        and set(atom.overlap_cells).isdisjoint(selected_space)
    }
    after_atom_ids = {
        atom.lineage_id
        for atom in after_publication.atoms.values()
        if int(atom.source_id) == rail_original_id
        and set(atom.overlap_cells).isdisjoint(selected_space)
    }

    def remote_page_ids(publication: PublicationState) -> set[str]:
        return {
            page.page_id
            for page in publication.pages.values()
            if set(page.overlap_cells).isdisjoint(selected_space)
            and any(
                atom_id in publication.atoms
                and int(publication.atoms[atom_id].source_id)
                == rail_original_id
                for atom_id in page.atom_ids
            )
        }

    before_page_ids = remote_page_ids(before_publication)
    after_page_ids = remote_page_ids(after_publication)
    before_fragment_ids = {
        coordinate
        for coordinate, fragment in before_storage.fragments.items()
        if coordinate not in selected_space
        and _fragment_contains_source(fragment, rail_original_id)
    }
    after_fragment_ids = {
        coordinate
        for coordinate, fragment in after_storage.fragments.items()
        if coordinate not in selected_space
        and _fragment_contains_source(fragment, rail_original_id)
    }
    symmetric_atoms = before_atom_ids == after_atom_ids
    symmetric_pages = before_page_ids == after_page_ids
    symmetric_fragments = before_fragment_ids == after_fragment_ids
    atom_identity = all(
        after_publication.atoms[atom_id]
        is before_publication.atoms[atom_id]
        and after_publication.atoms[atom_id].version_id
        == before_publication.atoms[atom_id].version_id
        and after_publication.atoms[atom_id].payload_sha256
        == before_publication.atoms[atom_id].payload_sha256
        for atom_id in before_atom_ids & after_atom_ids
    )
    page_identity = all(
        after_publication.pages[page_id]
        is before_publication.pages[page_id]
        and after_publication.pages[page_id].payload_sha256
        == before_publication.pages[page_id].payload_sha256
        for page_id in before_page_ids & after_page_ids
    )
    fragment_identity = all(
        after_storage.fragments[coordinate]
        is before_storage.fragments[coordinate]
        and after_storage.fragments[coordinate].digest
        == before_storage.fragments[coordinate].digest
        for coordinate in before_fragment_ids & after_fragment_ids
    )
    replacement_ids = {
        atom.lineage_id for atom in edit.published_new_atoms
    }
    changed_fragment_ids = {
        coordinate
        for coordinate in set(before_storage.fragments)
        | set(after_storage.fragments)
        if before_storage.fragments.get(coordinate)
        is not after_storage.fragments.get(coordinate)
    }
    intersections = {
        "removed_remote_atom_ids": sorted(
            before_atom_ids & set(edit.removed_atom_ids)
        ),
        "replacement_remote_atom_ids": sorted(
            before_atom_ids & replacement_ids
        ),
        "rebuilt_remote_page_ids": sorted(
            before_page_ids & set(edit.rebuilt_page_ids)
        ),
        "changed_remote_fragment_ids": [
            list(value)
            for value in sorted(before_fragment_ids & changed_fragment_ids)
        ],
    }
    passed = (
        bool(before_atom_ids)
        and bool(before_page_ids)
        and bool(before_fragment_ids)
        and symmetric_atoms
        and symmetric_pages
        and symmetric_fragments
        and atom_identity
        and page_identity
        and fragment_identity
        and all(not values for values in intersections.values())
    )
    return {
        "passed": passed,
        "before_atom_count": len(before_atom_ids),
        "after_atom_count": len(after_atom_ids),
        "before_page_count": len(before_page_ids),
        "after_page_count": len(after_page_ids),
        "before_fragment_count": len(before_fragment_ids),
        "after_fragment_count": len(after_fragment_ids),
        "symmetric_atom_ids": symmetric_atoms,
        "symmetric_page_ids": symmetric_pages,
        "symmetric_fragment_ids": symmetric_fragments,
        "atom_object_and_hash_identity": atom_identity,
        "page_object_and_hash_identity": page_identity,
        "fragment_object_and_hash_identity": fragment_identity,
        "atom_ids": sorted(before_atom_ids),
        "page_ids": sorted(before_page_ids),
        "fragment_ids": [list(value) for value in sorted(before_fragment_ids)],
        "changed_or_rebuilt_intersections": intersections,
    }


def _without_timing(value: Mapping[str, Any]) -> dict[str, Any]:
    return {
        key: item
        for key, item in value.items()
        if key not in {"phase_ms", "total_ms"}
    }


def _paired_non_time_work_signature(
    before: exact.WorkpieceState,
    edit: EditOutcome,
    organic_ids: frozenset[int],
) -> dict[str, Any]:
    metrics = edit.metrics
    return {
        "candidate_coordinate_count": metrics["candidate_coordinate_count"],
        "selected_fragment_count": metrics["selected_fragment_count"],
        "changed_storage_fragment_count": metrics[
            "changed_storage_fragment_count"
        ],
        "semantic_changed_fragment_work_manifest": (
            _semantic_changed_fragment_work_manifest(
                before, edit.storage, organic_ids
            )
        ),
        "unsplit_region_triangle_count": metrics[
            "unsplit_region_triangle_count"
        ],
        "unsplit_region_organic_triangle_count": metrics[
            "unsplit_region_organic_triangle_count"
        ],
        "unsplit_region_storage_cap_triangle_count": metrics[
            "unsplit_region_storage_cap_triangle_count"
        ],
        "unsplit_region_geometry_sha256": atlas._records_digest(
            edit.unsplit_region_records
        ),
        "zero_move_retriangulation": _without_timing(
            metrics["zero_move_retriangulation"]
        ),
        "dirty_selection": metrics["dirty_selection"],
        "dirty_conditioner": _without_timing(metrics["dirty_conditioner"]),
        "replacement_interface_closure": metrics[
            "replacement_interface_closure"
        ],
        "changed_source_faces": metrics["changed_source_faces"],
        "new_atom_count": metrics["new_atom_count"],
        "removed_atom_count": metrics["removed_atom_count"],
        "removed_atom_ids": sorted(edit.removed_atom_ids),
        "replacement_atom_manifest": _replacement_atom_manifest(edit),
        "half_edge_closure_atom_count": metrics[
            "half_edge_closure_atom_count"
        ],
        "overlay": metrics["overlay"],
        "rebuilt_page_ids": sorted(edit.rebuilt_page_ids),
        "rebuilt_page_manifest": _rebuilt_page_manifest(edit),
        "access_counters": metrics["access_counters"],
        "access_trace": metrics["access_trace"],
    }


def _publication_authority_audit(
    publication: PublicationState,
    authority: Any,
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    source_face_counts: Mapping[int, int],
    source_tags: Mapping[int, str],
    expected_sources: frozenset[int],
) -> tuple[list[Record], list[dict[str, Any]], Any, dict[str, Any]]:
    emitted_records, decoded_pages, roundtrip = _roundtrip_publication_state(
        publication, property_lookup
    )
    quality = atlas._quality_summary(emitted_records)
    topologies = {
        str(quantum): atlas._topology_for_records(emitted_records, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    solid, mesh64 = atlas._make_publication_solid(emitted_records)
    authority_records = _records_from_solid(authority)
    comparison = atlas._surface_and_volume_comparison(
        solid, authority, emitted_records, authority_records
    )
    bounds_delta = atlas._bounds_delta(
        atlas._records_bounds(emitted_records),
        atlas._records_bounds(authority_records),
    )
    provenance = atlas._provenance_summary(
        emitted_records, source_face_counts
    )
    material_lineage = _source_material_lineage_audit(
        emitted_records,
        property_lookup,
        source_tags,
        expected_sources,
    )
    passed = (
        all(atlas._topology_passes(value) for value in topologies.values())
        and int(quality["double_subthreshold_triangle_count"]) == 0
        and int(quality["float32_subthreshold_triangle_count"]) == 0
        and mesh64["status"] == "NoError"
        and int(mesh64["component_count"]) == 1
        and mesh64["component_genera"] == [0]
        and bool(provenance["passed"])
        and int(provenance["compiler_cap_triangle_count"]) == 0
        and set(
            int(value) for value in provenance["triangle_counts_by_original_id"]
        ) == set(expected_sources)
        and bool(material_lineage["passed"])
        and float(comparison["sampled_bidirectional_maximum_m"])
        <= MAX_SAMPLED_SURFACE_DISTANCE_METERS
        and float(comparison["symmetric_difference_volume_m3"])
        <= MAX_SYMMETRIC_DIFFERENCE_VOLUME_M3
        and bounds_delta <= atlas.SAME_BOUNDS_TOLERANCE_METERS
    )
    return emitted_records, decoded_pages, solid, {
        "passed": passed,
        "triangle_count": len(emitted_records),
        "quality": quality,
        "topology": topologies,
        "mesh64": mesh64,
        "page_roundtrip": roundtrip,
        "provenance": provenance,
        "source_material_lineage": material_lineage,
        "comparison_to_authority": comparison,
        "bounds_max_delta_m": bounds_delta,
    }


def _reuse_verified_b_local_fragments(
    young: exact.WorkpieceState,
    mature_transaction_state: exact.WorkpieceState,
    selected_space: frozenset[Coordinate],
    organic_ids: frozenset[int],
) -> tuple[exact.WorkpieceState, dict[str, Any]]:
    young_local = {
        coordinate: young.fragments[coordinate]
        for coordinate in selected_space
        if coordinate in young.fragments
    }
    mature_local = {
        coordinate: mature_transaction_state.fragments[coordinate]
        for coordinate in selected_space
        if coordinate in mature_transaction_state.fragments
    }
    equivalence = exact._fragment_map_geometry_equivalence(
        young_local, mature_local
    )
    _require(
        bool(equivalence["passed"]),
        "extension transaction changed B-selected fragment geometry",
    )
    young_caps = exact._cap_geometry_signature(young_local, set(organic_ids))
    mature_caps = exact._cap_geometry_signature(mature_local, set(organic_ids))
    _require(
        young_caps == mature_caps,
        "extension transaction changed B-selected compiler-cap seams",
    )
    mature = exact.WorkpieceState(
        exact.FragmentOverlay(
            mature_transaction_state.fragments,
            set(young_local),
            young_local,
        ),
        mature_transaction_state.revision,
    )
    identity_count = sum(
        mature.fragments[coordinate] is young.fragments[coordinate]
        for coordinate in young_local
    )
    _require(
        identity_count == len(young_local),
        "verified B-local Fragment objects were not reused",
    )
    return mature, {
        "selected_coordinate_count": len(young_local),
        "reused_identical_object_count": identity_count,
        "geometry_equivalence": equivalence,
        "compiler_cap_signatures_equal": True,
        "reuse_law": "reuse only after per-fragment solid and cap-seam equivalence",
    }


def _load_accepted_young_baseline() -> dict[str, Any]:
    _require(OUTPUT_JSON.is_file(), "accepted young baseline result is missing")
    _require(
        OUTPUT_PACKETS_JSON.is_file(),
        "accepted young baseline packet artifact is missing",
    )
    result = json.loads(OUTPUT_JSON.read_text(encoding="utf-8"))
    packets = json.loads(OUTPUT_PACKETS_JSON.read_text(encoding="utf-8"))
    _require(
        result.get("outcome") == "pass"
        and result.get("scope") == "tools_only_incremental_young_geometry_gate",
        "existing artifact is not the accepted young baseline",
    )
    transaction = result["transaction"]
    publication = result["actual_post_overlay_publication"]
    return {
        "result_file_sha256": exact._sha256_bytes(OUTPUT_JSON.read_bytes()),
        "packet_file_sha256": exact._sha256_bytes(
            OUTPUT_PACKETS_JSON.read_bytes()
        ),
        "combined_geometry_sha256": packets["combined_geometry_sha256"],
        "page_hashes": publication["page_roundtrip"]["page_hashes"],
        "topology": publication["topology"],
        "closure": {
            key: transaction["replacement_interface_closure"][key]
            for key in (
                "iteration_count",
                "transitive_neighbor_expansion_count",
                "final_interface_edge_count",
                "every_interface_edge_has_two_opposite_incidences",
                "jurisdiction_perimeter_touched",
            )
        },
        "cleanup_edge_digests": [
            row["edge_digest"]
            for row in transaction["dirty_conditioner"]["collapses"]
        ],
        "cleanup_changed_source_faces": transaction["dirty_conditioner"][
            "changed_source_faces"
        ],
        "cleanup_collapse_count": transaction["dirty_conditioner"][
            "collapse_count"
        ],
        "cleanup_maximum_displacement_m": transaction["dirty_conditioner"][
            "maximum_actual_cumulative_vertex_displacement_m"
        ],
        "publication_comparison": result["monolithic_a_plus_b"][
            "publication_comparison"
        ],
    }


def _points_bounds(points: Any) -> tuple[float, float, float, float, float, float]:
    values = np.asarray(points, dtype=np.float64)
    _require(values.ndim == 2 and values.shape[1:] == (3,), "points must be Nx3")
    minimum = values.min(axis=0)
    maximum = values.max(axis=0)
    return tuple(float(value) for value in np.concatenate((minimum, maximum)))


def _aabb_disjoint(first: Sequence[float], second: Sequence[float]) -> bool:
    _require(len(first) == 6 and len(second) == 6, "AABB must contain six values")
    return any(
        float(first[axis + 3]) <= float(second[axis])
        or float(second[axis + 3]) <= float(first[axis])
        for axis in range(3)
    )


def _publication_jurisdiction_manifest(
    publication: PublicationState,
    cells: Sequence[Coordinate],
) -> dict[str, Any]:
    """Describe every directly indexed B-halo object plus its available frontier."""
    ordered_cells = tuple(sorted(set(cells)))
    direct_atom_ids: set[str] = set()
    direct_page_ids: set[str] = set()
    index_rows: list[dict[str, Any]] = []
    for coordinate in ordered_cells:
        atom_ids = tuple(
            sorted(publication.atom_overlap_index.get(coordinate, frozenset()))
        )
        page_ids = tuple(
            sorted(publication.page_overlap_index.get(coordinate, frozenset()))
        )
        direct_atom_ids.update(atom_ids)
        direct_page_ids.update(page_ids)
        index_rows.append(
            {
                "coordinate": list(coordinate),
                "atom_lineage_ids": list(atom_ids),
                "page_ids": list(page_ids),
            }
        )
    neighbor_frontier_ids = {
        neighbor_id
        for lineage_id in direct_atom_ids
        for neighbor_id in publication.half_edge_neighbors.get(
            lineage_id, frozenset()
        )
    }
    accessed_atom_ids = direct_atom_ids | neighbor_frontier_ids
    accessed_page_ids = direct_page_ids | {
        publication.atom_to_page[lineage_id]
        for lineage_id in accessed_atom_ids
    }
    atom_rows = [
        {
            "lineage_id": lineage_id,
            "version_id": publication.atoms[lineage_id].version_id,
            "payload_sha256": publication.atoms[lineage_id].payload_sha256,
            "source_id": publication.atoms[lineage_id].source_id,
            "face_id": publication.atoms[lineage_id].face_id,
            "overlap_cells": [
                list(value)
                for value in publication.atoms[lineage_id].overlap_cells
            ],
            "page_id": publication.atom_to_page[lineage_id],
        }
        for lineage_id in sorted(accessed_atom_ids)
    ]
    page_rows = [
        {
            "page_id": page_id,
            "payload_sha256": publication.pages[page_id].payload_sha256,
            "atom_lineage_ids": list(publication.pages[page_id].atom_ids),
            "overlap_cells": [
                list(value) for value in publication.pages[page_id].overlap_cells
            ],
        }
        for page_id in sorted(accessed_page_ids)
    ]
    half_edge_rows = [
        {
            "lineage_id": lineage_id,
            "neighbor_lineage_ids": list(
                sorted(
                    publication.half_edge_neighbors.get(
                        lineage_id, frozenset()
                    )
                )
            ),
        }
        for lineage_id in sorted(accessed_atom_ids)
    ]
    semantic_manifest = {
        "cells": index_rows,
        "direct_atom_lineage_ids": sorted(direct_atom_ids),
        "indexed_neighbor_frontier_lineage_ids": sorted(neighbor_frontier_ids),
        "atoms": atom_rows,
        "pages": page_rows,
        "half_edge_neighbors": half_edge_rows,
    }
    return {
        **semantic_manifest,
        "semantic_sha256": _sha256_json(semantic_manifest),
        "atom_object_ids": [
            {
                "lineage_id": lineage_id,
                "object_id": id(publication.atoms[lineage_id]),
            }
            for lineage_id in sorted(accessed_atom_ids)
        ],
        "page_object_ids": [
            {
                "page_id": page_id,
                "object_id": id(publication.pages[page_id]),
            }
            for page_id in sorted(accessed_page_ids)
        ],
        "direct_atom_count": len(direct_atom_ids),
        "neighbor_frontier_atom_count": len(neighbor_frontier_ids),
        "accessed_atom_count": len(accessed_atom_ids),
        "accessed_page_count": len(accessed_page_ids),
        "object_identity_is_diagnostic_not_cross_bootstrap_gate": True,
    }


_JURISDICTION_MANIFEST_COMPONENTS = (
    "cells",
    "direct_atom_lineage_ids",
    "indexed_neighbor_frontier_lineage_ids",
    "atoms",
    "pages",
    "half_edge_neighbors",
)


def _jurisdiction_component_key(component: str, row: Any) -> Any:
    if component == "cells":
        return tuple(int(value) for value in row["coordinate"])
    if component in (
        "direct_atom_lineage_ids",
        "indexed_neighbor_frontier_lineage_ids",
    ):
        return str(row)
    if component == "atoms":
        return str(row["lineage_id"])
    if component == "pages":
        return str(row["page_id"])
    if component == "half_edge_neighbors":
        return str(row["lineage_id"])
    raise ProofFailure(f"unknown jurisdiction manifest component {component!r}")


def _jsonable_manifest_key(value: Any) -> Any:
    if isinstance(value, tuple):
        return list(value)
    return value


def _jurisdiction_manifest_comparison(
    young: Mapping[str, Any],
    mature: Mapping[str, Any],
) -> dict[str, Any]:
    """Emit exact per-component differences without asserting equivalence."""
    components: dict[str, Any] = {}
    all_equal = True
    for component in _JURISDICTION_MANIFEST_COMPONENTS:
        young_rows = list(young[component])
        mature_rows = list(mature[component])
        young_by_key = {
            _jurisdiction_component_key(component, row): row
            for row in young_rows
        }
        mature_by_key = {
            _jurisdiction_component_key(component, row): row
            for row in mature_rows
        }
        _require(
            len(young_by_key) == len(young_rows)
            and len(mature_by_key) == len(mature_rows),
            f"duplicate keys in {component} jurisdiction manifest",
        )
        young_keys = set(young_by_key)
        mature_keys = set(mature_by_key)
        young_only = sorted(young_keys - mature_keys)
        mature_only = sorted(mature_keys - young_keys)
        differing_common = sorted(
            key
            for key in young_keys & mature_keys
            if young_by_key[key] != mature_by_key[key]
        )
        first_key = next(
            iter(sorted(set(young_only) | set(mature_only) | set(differing_common))),
            None,
        )
        equal = young_rows == mature_rows
        all_equal = all_equal and equal
        components[component] = {
            "equal": equal,
            "young_count": len(young_rows),
            "mature_count": len(mature_rows),
            "young_sha256": _sha256_json(young_rows),
            "mature_sha256": _sha256_json(mature_rows),
            "young_only_keys": [
                _jsonable_manifest_key(value) for value in young_only
            ],
            "mature_only_keys": [
                _jsonable_manifest_key(value) for value in mature_only
            ],
            "differing_common_keys": [
                _jsonable_manifest_key(value) for value in differing_common
            ],
            "first_difference": (
                None
                if first_key is None
                else {
                    "key": _jsonable_manifest_key(first_key),
                    "young_row": young_by_key.get(first_key),
                    "mature_row": mature_by_key.get(first_key),
                }
            ),
        }
    page_first = components["pages"]["first_difference"]
    return {
        "all_components_equal": all_equal,
        "whole_semantic_sha256_equal": (
            young["semantic_sha256"] == mature["semantic_sha256"]
        ),
        "young_whole_semantic_sha256": young["semantic_sha256"],
        "mature_whole_semantic_sha256": mature["semantic_sha256"],
        "components": components,
        "first_differing_page_membership_and_footprint": page_first,
    }


def _publication_atoms_semantically_equal(
    first: PublicationAtom,
    second: PublicationAtom,
) -> bool:
    """Exact atom comparison that never asks NumPy arrays for truth values."""
    return (
        first.lineage_id == second.lineage_id
        and first.version_id == second.version_id
        and first.payload_sha256 == second.payload_sha256
        and int(first.source_id) == int(second.source_id)
        and int(first.face_id) == int(second.face_id)
        and first.bounds == second.bounds
        and first.overlap_cells == second.overlap_cells
        and atlas._records_digest(first.records)
        == atlas._records_digest(second.records)
    )


def _publication_pages_semantically_equal(
    first: PublicationPage,
    second: PublicationPage,
) -> bool:
    """Exact page comparison through stable fields and canonical payload hashes."""
    first_canonical_payload_sha256 = atlas._page_payload_hash(first.payload)
    second_canonical_payload_sha256 = atlas._page_payload_hash(second.payload)
    return (
        first.page_id == second.page_id
        and first.payload_sha256 == second.payload_sha256
        and first.atom_ids == second.atom_ids
        and first.bounds == second.bounds
        and first.overlap_cells == second.overlap_cells
        and first_canonical_payload_sha256 == first.payload_sha256
        and second_canonical_payload_sha256 == second.payload_sha256
        and first_canonical_payload_sha256 == second_canonical_payload_sha256
    )


def _classify_halo_page_leakage(
    young: PublicationState,
    mature: PublicationState,
    young_manifest: Mapping[str, Any],
    mature_manifest: Mapping[str, Any],
    comparison: Mapping[str, Any],
    a_original_id: int,
    rail_original_id: int,
) -> dict[str, Any]:
    """Allow only terminal-cap/rail page leakage; geometry indexes stay exact."""
    components = comparison["components"]
    invariant_components = (
        "direct_atom_lineage_ids",
        "indexed_neighbor_frontier_lineage_ids",
        "atoms",
        "half_edge_neighbors",
    )
    invariant_components_equal = all(
        bool(components[name]["equal"]) for name in invariant_components
    )
    page_component = components["pages"]
    page_ids = sorted(
        set(page_component["young_only_keys"])
        | set(page_component["mature_only_keys"])
        | set(page_component["differing_common_keys"])
    )
    page_rows: list[dict[str, Any]] = []
    classified_page_ids: set[str] = set()
    for page_id in page_ids:
        young_page = young.pages.get(page_id)
        mature_page = mature.pages.get(page_id)
        young_members = set(() if young_page is None else young_page.atom_ids)
        mature_members = set(() if mature_page is None else mature_page.atom_ids)
        young_only = sorted(young_members - mature_members)
        mature_only = sorted(mature_members - young_members)
        common = sorted(young_members & mature_members)
        common_atoms_exact = all(
            atom_id in young.atoms
            and atom_id in mature.atoms
            and _publication_atoms_semantically_equal(
                young.atoms[atom_id], mature.atoms[atom_id]
            )
            for atom_id in common
        )
        young_terminal_cap_only = all(
            atom_id in young.atoms
            and int(young.atoms[atom_id].source_id) == a_original_id
            and 1419 <= int(young.atoms[atom_id].face_id) <= 1445
            for atom_id in young_only
        )
        mature_rail_only = all(
            atom_id in mature.atoms
            and int(mature.atoms[atom_id].source_id) == rail_original_id
            for atom_id in mature_only
        )
        classified = (
            bool(young_only or mature_only)
            and common_atoms_exact
            and young_terminal_cap_only
            and mature_rail_only
        )
        if classified:
            classified_page_ids.add(page_id)
        page_rows.append(
            {
                "page_id": page_id,
                "classified_terminal_cap_to_rail_join": classified,
                "common_atom_count": len(common),
                "common_atoms_exact": common_atoms_exact,
                "young_only_terminal_cap_atoms": young_only,
                "mature_only_rail_atoms": mature_only,
                "mature_only_rail_face_ids": [
                    int(mature.atoms[atom_id].face_id)
                    for atom_id in mature_only
                    if atom_id in mature.atoms
                ],
                "young_payload_sha256": (
                    None if young_page is None else young_page.payload_sha256
                ),
                "mature_payload_sha256": (
                    None if mature_page is None else mature_page.payload_sha256
                ),
                "young_overlap_cells": (
                    []
                    if young_page is None
                    else [list(value) for value in young_page.overlap_cells]
                ),
                "mature_overlap_cells": (
                    []
                    if mature_page is None
                    else [list(value) for value in mature_page.overlap_cells]
                ),
            }
        )

    young_cells = {
        tuple(row["coordinate"]): row for row in young_manifest["cells"]
    }
    mature_cells = {
        tuple(row["coordinate"]): row for row in mature_manifest["cells"]
    }
    cell_keys = sorted(set(young_cells) | set(mature_cells))
    differing_cell_rows: list[dict[str, Any]] = []
    cells_are_page_only = True
    for coordinate in cell_keys:
        young_row = young_cells.get(coordinate)
        mature_row = mature_cells.get(coordinate)
        if young_row == mature_row:
            continue
        young_atoms = set(
            () if young_row is None else young_row["atom_lineage_ids"]
        )
        mature_atoms = set(
            () if mature_row is None else mature_row["atom_lineage_ids"]
        )
        young_pages = set(() if young_row is None else young_row["page_ids"])
        mature_pages = set(() if mature_row is None else mature_row["page_ids"])
        page_delta = young_pages ^ mature_pages
        classified = (
            young_atoms == mature_atoms
            and bool(page_delta)
            and page_delta <= classified_page_ids
        )
        cells_are_page_only = cells_are_page_only and classified
        differing_cell_rows.append(
            {
                "coordinate": list(coordinate),
                "classified_page_only": classified,
                "atom_lineage_ids_equal": young_atoms == mature_atoms,
                "young_only_page_ids": sorted(young_pages - mature_pages),
                "mature_only_page_ids": sorted(mature_pages - young_pages),
            }
        )
    page_differences_classified = classified_page_ids == set(page_ids)
    passed = (
        invariant_components_equal
        and page_differences_classified
        and cells_are_page_only
    )
    return {
        "passed": passed,
        "invariant_components": list(invariant_components),
        "invariant_components_equal": invariant_components_equal,
        "cell_difference_count": len(differing_cell_rows),
        "page_difference_count": len(page_ids),
        "page_differences_classified": page_differences_classified,
        "cells_are_page_only": cells_are_page_only,
        "differing_cell_rows": differing_cell_rows,
        "differing_pages": page_rows,
        "classified_differing_page_ids": sorted(classified_page_ids),
        "classification_law": (
            "common atoms exact; young-only atoms are A terminal-cap faces "
            "1419..1445; mature-only atoms are stitched-rail provenance; "
            "cell atom indexes remain exact and only page IDs may leak"
        ),
    }


def _graft_exact_edit_publication_objects(
    young: PublicationState,
    mature: PublicationState,
    edit_cells: frozenset[Coordinate],
    young_manifest: Mapping[str, Any],
    mature_manifest: Mapping[str, Any],
    comparison: Mapping[str, Any],
    rail_original_id: int,
) -> tuple[PublicationState, dict[str, Any]]:
    """Reuse only already-identical B-edit atom/page objects from young."""
    _require(
        bool(comparison["all_components_equal"])
        and bool(comparison["whole_semantic_sha256_equal"]),
        "B edit-cell publication semantics differ before exact object graft",
    )
    atom_ids = tuple(row["lineage_id"] for row in young_manifest["atoms"])
    page_ids = tuple(row["page_id"] for row in young_manifest["pages"])
    _require(
        atom_ids
        == tuple(row["lineage_id"] for row in mature_manifest["atoms"])
        and page_ids
        == tuple(row["page_id"] for row in mature_manifest["pages"]),
        "B edit-cell accessed object keys differ before graft",
    )
    atom_payloads_equal = all(
        _publication_atoms_semantically_equal(
            young.atoms[atom_id], mature.atoms[atom_id]
        )
        for atom_id in atom_ids
    )
    page_payloads_equal = all(
        _publication_pages_semantically_equal(
            young.pages[page_id], mature.pages[page_id]
        )
        for page_id in page_ids
    )
    rail_atoms_in_pages = sorted(
        atom_id
        for page_id in page_ids
        for atom_id in mature.pages[page_id].atom_ids
        if int(mature.atoms[atom_id].source_id) == rail_original_id
    )
    atom_cells = set(edit_cells)
    page_cells = set(edit_cells)
    provenance_keys: set[tuple[int, int]] = set()
    edge_keys: set[atlas.EdgeKey] = set()
    for atom_id in atom_ids:
        atom = mature.atoms[atom_id]
        atom_cells.update(atom.overlap_cells)
        provenance_keys.add((atom.source_id, atom.face_id))
        edge_keys.update(_atom_edge_keys(atom))
    for page_id in page_ids:
        page_cells.update(mature.pages[page_id].overlap_cells)
    index_equality = {
        "atom_to_page": all(
            young.atom_to_page.get(atom_id) == mature.atom_to_page.get(atom_id)
            for atom_id in atom_ids
        ),
        "atom_overlap_index": all(
            young.atom_overlap_index.get(cell, frozenset())
            == mature.atom_overlap_index.get(cell, frozenset())
            for cell in atom_cells
        ),
        "provenance_index": all(
            young.provenance_index.get(key, frozenset())
            == mature.provenance_index.get(key, frozenset())
            for key in provenance_keys
        ),
        "page_overlap_index": all(
            young.page_overlap_index.get(cell, frozenset())
            == mature.page_overlap_index.get(cell, frozenset())
            for cell in page_cells
        ),
        "half_edge_neighbors": all(
            young.half_edge_neighbors.get(atom_id, frozenset())
            == mature.half_edge_neighbors.get(atom_id, frozenset())
            for atom_id in atom_ids
        ),
        "half_edge_index": all(
            young.half_edge_index.get(key, frozenset())
            == mature.half_edge_index.get(key, frozenset())
            for key in edge_keys
        ),
    }
    _require(atom_payloads_equal, "B edit-cell atom payloads differ before graft")
    _require(page_payloads_equal, "B edit-cell page payloads differ before graft")
    _require(
        not rail_atoms_in_pages,
        "B edit-cell exact page graft would capture stitched-rail atoms",
    )
    _require(
        all(index_equality.values()),
        "B edit-cell publication indexes differ before exact object graft",
    )
    grafted = PublicationState(
        atoms=PersistentOverlay(
            mature.atoms,
            (),
            {atom_id: young.atoms[atom_id] for atom_id in atom_ids},
        ),
        pages=PersistentOverlay(
            mature.pages,
            (),
            {page_id: young.pages[page_id] for page_id in page_ids},
        ),
        atom_to_page=mature.atom_to_page,
        atom_overlap_index=mature.atom_overlap_index,
        provenance_index=mature.provenance_index,
        page_overlap_index=mature.page_overlap_index,
        half_edge_neighbors=mature.half_edge_neighbors,
        half_edge_index=mature.half_edge_index,
        revision=mature.revision,
    )
    atom_identity_count = sum(
        grafted.atoms[atom_id] is young.atoms[atom_id] for atom_id in atom_ids
    )
    page_identity_count = sum(
        grafted.pages[page_id] is young.pages[page_id] for page_id in page_ids
    )
    post_manifest = _publication_jurisdiction_manifest(grafted, edit_cells)
    post_comparison = _jurisdiction_manifest_comparison(
        young_manifest, post_manifest
    )
    _require(
        atom_identity_count == len(atom_ids)
        and page_identity_count == len(page_ids),
        "B edit-cell publication objects were not reused by exact identity",
    )
    _require(
        bool(post_comparison["all_components_equal"])
        and bool(post_comparison["whole_semantic_sha256_equal"]),
        "B edit-cell publication semantics changed during exact object graft",
    )
    return grafted, {
        "grafted_atom_count": len(atom_ids),
        "grafted_page_count": len(page_ids),
        "identical_atom_object_count": atom_identity_count,
        "identical_page_object_count": page_identity_count,
        "atom_payloads_exact_before_graft": atom_payloads_equal,
        "page_payloads_exact_before_graft": page_payloads_equal,
        "index_equality": index_equality,
        "all_indexes_exact_before_graft": all(index_equality.values()),
        "rail_atom_count_in_grafted_pages": len(rail_atoms_in_pages),
        "post_graft_edit_semantics_equal": bool(
            post_comparison["all_components_equal"]
            and post_comparison["whole_semantic_sha256_equal"]
        ),
        "graft_scope_law": (
            "only semantically identical B edit-cell accessed atoms/pages; "
            "no differing halo page is grafted"
        ),
    }


def _build_stitched_mature_fixture(
    *,
    fixture: Mapping[str, Any] | None = None,
    fixture_sha256: str | None = None,
    fixture_transport: Mapping[str, Any] | None = None,
    source_ids: tuple[int, int, int] | None = None,
    stroke_a: exact.PacketSolid | None = None,
) -> StitchedMatureFixture:
    """Replace A's positive terminal cap with a long translated ring rail."""
    if fixture is None:
        fixture, fixture_sha256 = exact._load_fixture()
        fixture_transport = exact._validate_fixture_hashes(fixture)
    else:
        _require(fixture_sha256 is not None, "shared stitched fixture SHA is missing")
        _require(
            fixture_transport is not None,
            "shared stitched fixture transport audit is missing",
        )
    if source_ids is None:
        first_original_id = int(manifold3d.Manifold.reserve_ids(3))
        source_ids = (
            first_original_id,
            first_original_id + 1,
            first_original_id + 2,
        )
    a_original_id, b_original_id, rail_original_id = source_ids
    _require(
        b_original_id == a_original_id + 1
        and rail_original_id == a_original_id + 2,
        "stitched source IDs are not one shared contiguous reservation",
    )

    packet_a = fixture["packets"]["stroke_a"]
    packet_b = fixture["packets"]["stroke_b"]
    a_vertices = np.asarray(packet_a.get("vertices", []), dtype=np.float64)
    raw_a_triangles = exact._packet_triangles(packet_a)
    expected_a_vertices = STITCHED_A_RING_COUNT * STITCHED_RING_VERTEX_COUNT
    _require(
        len(a_vertices) == expected_a_vertices == 725,
        "stitched fixture expected exactly 25x29 A vertices",
    )
    _require(len(raw_a_triangles) == 1446, "stitched fixture expected 1446 A triangles")

    base_property_lookup = atlas._source_property_lookup(
        fixture,
        {"stroke_a": a_original_id, "stroke_b": b_original_id},
    )
    if stroke_a is None:
        stroke_a = exact._make_packet_solid("stroke_a", packet_a, a_original_id)
    else:
        _require(
            stroke_a.original_id == a_original_id,
            "shared young A does not use the stitched A source ID",
        )
    imported_a_records = _records_from_solid(stroke_a.manifold)
    conditioned_a_records, a_conditioning = _condition_authority(
        stroke_a.manifold, base_property_lookup
    )
    imported_a_digest = atlas._records_digest(imported_a_records)
    conditioned_a_digest = atlas._records_digest(conditioned_a_records)
    _require(
        conditioned_a_digest == imported_a_digest
        and len(conditioned_a_records) == len(imported_a_records) == 1446,
        "accepted A conditioner is not exact identity",
    )

    oriented_a_triangles = np.asarray(raw_a_triangles, dtype=np.uint64).copy()
    signed_volume = exact._signed_mesh_volume(a_vertices, oriented_a_triangles)
    reversed_for_manifold = signed_volume < 0.0
    if reversed_for_manifold:
        oriented_a_triangles = oriented_a_triangles[:, [0, 2, 1]].copy()
    raw_oriented_a_records = atlas._sorted_records(
        (
            a_original_id,
            face_id,
            np.asarray(a_vertices[triangle], dtype=np.float64),
        )
        for face_id, triangle in enumerate(oriented_a_triangles)
    )
    _require(
        atlas._records_digest(raw_oriented_a_records) == imported_a_digest,
        "raw oriented A arrays do not roundtrip to the accepted A Mesh64",
    )

    terminal_start = (STITCHED_A_RING_COUNT - 1) * STITCHED_RING_VERTEX_COUNT
    previous_start = terminal_start - STITCHED_RING_VERTEX_COUNT
    terminal_ring_indices = frozenset(
        range(terminal_start, terminal_start + STITCHED_RING_VERTEX_COUNT)
    )
    previous_ring_indices = frozenset(range(previous_start, terminal_start))
    terminal_cap_faces = tuple(
        face_id
        for face_id, triangle in enumerate(oriented_a_triangles)
        if set(int(value) for value in triangle) <= terminal_ring_indices
    )
    _require(
        len(terminal_cap_faces) == STITCHED_TERMINAL_CAP_TRIANGLE_COUNT
        and terminal_cap_faces == tuple(range(1419, 1446)),
        "terminal-ring membership did not identify exactly A faces 1419..1445",
    )
    last_side_band_faces = tuple(
        face_id
        for face_id, triangle in enumerate(oriented_a_triangles)
        if set(int(value) for value in triangle)
        <= (terminal_ring_indices | previous_ring_indices)
        and bool(set(int(value) for value in triangle) & terminal_ring_indices)
        and bool(set(int(value) for value in triangle) & previous_ring_indices)
    )
    _require(
        len(last_side_band_faces) == STITCHED_SIDE_TRIANGLES_PER_INTERVAL
        and last_side_band_faces == tuple(range(1334, 1392)),
        "last A ring interval did not expose the expected 58 side triangles",
    )
    terminal_cap_face_set = frozenset(terminal_cap_faces)
    retained_a_faces = tuple(
        face_id
        for face_id in range(len(oriented_a_triangles))
        if face_id not in terminal_cap_face_set
    )
    _require(len(retained_a_faces) == 1419, "A terminal-cap removal count drifted")

    side_template: list[tuple[tuple[int, int], tuple[int, int], tuple[int, int]]] = []
    for face_id in last_side_band_faces:
        mapped: list[tuple[int, int]] = []
        for raw_index in oriented_a_triangles[face_id]:
            index = int(raw_index)
            if index in previous_ring_indices:
                mapped.append((0, index - previous_start))
            elif index in terminal_ring_indices:
                mapped.append((1, index - terminal_start))
            else:
                raise ProofFailure("last-side template escaped its two source rings")
        _require(
            {side for side, _profile in mapped} == {0, 1},
            "last-side template triangle does not bridge both rings",
        )
        side_template.append((mapped[0], mapped[1], mapped[2]))
    _require(len(side_template) == 58, "side-band template count drifted")

    stitched_vertices = [
        np.asarray(point, dtype=np.float64).copy() for point in a_vertices
    ]
    terminal_ring = np.asarray(
        a_vertices[terminal_start : terminal_start + STITCHED_RING_VERTEX_COUNT],
        dtype=np.float64,
    )
    for ring_number in range(1, STITCHED_RAIL_NEW_RING_COUNT + 1):
        fraction = ring_number / STITCHED_RAIL_NEW_RING_COUNT
        offset = np.asarray(
            [
                STITCHED_RAIL_X_LENGTH_METERS * fraction,
                0.0025 * math.sin(2.0 * math.pi * 3.0 * fraction),
                0.0015 * math.sin(2.0 * math.pi * 5.0 * fraction),
            ],
            dtype=np.float64,
        )
        stitched_vertices.extend(point.copy() for point in terminal_ring + offset)
    stitched_vertices_array = np.ascontiguousarray(
        np.asarray(stitched_vertices, dtype=np.float64)
    )
    _require(
        len(stitched_vertices_array) == 725 + 29 * 149 == 5046,
        "stitched mature vertex count drifted",
    )

    retained_triangles = [
        tuple(int(value) for value in oriented_a_triangles[face_id])
        for face_id in retained_a_faces
    ]
    rail_triangles: list[tuple[int, int, int]] = []
    for interval in range(STITCHED_RAIL_NEW_RING_COUNT):
        low_start = (
            terminal_start
            if interval == 0
            else expected_a_vertices
            + (interval - 1) * STITCHED_RING_VERTEX_COUNT
        )
        high_start = expected_a_vertices + interval * STITCHED_RING_VERTEX_COUNT
        interval_start = len(rail_triangles)
        for triangle_template in side_template:
            generated: list[int] = []
            for side, profile_index in triangle_template:
                generated.append(
                    (low_start if side == 0 else high_start) + profile_index
                )
            rail_triangles.append(tuple(generated))
        _require(
            len(rail_triangles) - interval_start
            == STITCHED_SIDE_TRIANGLES_PER_INTERVAL,
            "rail interval did not copy all 58 side triangles",
        )
    far_ring_start = (
        expected_a_vertices
        + (STITCHED_RAIL_NEW_RING_COUNT - 1) * STITCHED_RING_VERTEX_COUNT
    )
    for face_id in terminal_cap_faces:
        rail_triangles.append(
            tuple(
                far_ring_start + int(index) - terminal_start
                for index in oriented_a_triangles[face_id]
            )
        )
    expected_rail_triangles = 58 * 149 + 27
    _require(
        len(rail_triangles) == expected_rail_triangles == 8669,
        "stitched mature rail triangle count drifted",
    )
    stitched_triangles = np.ascontiguousarray(
        np.asarray(retained_triangles + rail_triangles, dtype=np.uint64)
    )
    _require(
        len(stitched_triangles) == 1446 + 58 * 149 == 10088,
        "stitched mature total triangle count drifted",
    )
    face_ids = np.ascontiguousarray(
        np.asarray(
            [*retained_a_faces, *range(expected_rail_triangles)],
            dtype=np.uint64,
        )
    )
    run_index = np.asarray(
        [0, len(retained_a_faces) * 3, len(stitched_triangles) * 3],
        dtype=np.uint64,
    )
    run_original_id = np.asarray(
        [a_original_id, rail_original_id], dtype=np.uint32
    )
    mesh = manifold3d.Mesh64(
        stitched_vertices_array,
        stitched_triangles,
        run_index=run_index,
        run_original_id=run_original_id,
        face_id=face_ids,
        tolerance=0.0,
    )
    stitched_solid = manifold3d.Manifold(mesh)
    _require(
        exact._is_ok(stitched_solid),
        "stitched mature two-run Mesh64 failed: " + exact._status_name(stitched_solid),
    )
    _require(not stitched_solid.is_empty(), "stitched mature Mesh64 is empty")
    components = stitched_solid.decompose()
    _require(
        len(components) == 1 and int(components[0].genus()) == 0,
        "stitched mature Mesh64 is not one genus-zero component",
    )
    _require(
        int(stitched_solid.num_tri()) == 10088,
        "stitched mature Mesh64 changed the triangle count",
    )
    post_mesh = stitched_solid.to_mesh64()
    post_vertex_count = len(np.asarray(post_mesh.vert_properties, dtype=np.float64))
    _require(post_vertex_count == 5046, "stitched mature Mesh64 changed vertex count")
    post_records = tuple(_records_from_solid(stitched_solid))

    donor_property_pairs = {
        base_property_lookup[(a_original_id, face_id)]
        for face_id in (*last_side_band_faces, *terminal_cap_faces)
    }
    _require(
        len(donor_property_pairs) == 1,
        "rail donor faces do not share one material/surface pair",
    )
    rail_property_pair = next(iter(donor_property_pairs))
    property_lookup = dict(base_property_lookup)
    for face_id in range(expected_rail_triangles):
        property_lookup[(rail_original_id, face_id)] = rail_property_pair

    expected_retained_a_records = atlas._sorted_records(
        (
            a_original_id,
            face_id,
            np.asarray(a_vertices[oriented_a_triangles[face_id]], dtype=np.float64),
        )
        for face_id in retained_a_faces
    )
    post_a_records = [
        record for record in post_records if int(record[0]) == a_original_id
    ]
    post_rail_records = [
        record for record in post_records if int(record[0]) == rail_original_id
    ]
    post_a_face_ids = sorted(int(record[1]) for record in post_a_records)
    post_rail_face_ids = sorted(int(record[1]) for record in post_rail_records)
    _require(
        post_a_face_ids == list(retained_a_faces)
        and atlas._records_digest(post_a_records)
        == atlas._records_digest(expected_retained_a_records),
        "post-import A vertices/source/face IDs changed",
    )
    _require(
        len(post_rail_records) == expected_rail_triangles
        and post_rail_face_ids == list(range(expected_rail_triangles)),
        "post-import rail triangle provenance changed",
    )

    removed_cap_records = atlas._sorted_records(
        (
            a_original_id,
            face_id,
            np.asarray(a_vertices[oriented_a_triangles[face_id]], dtype=np.float64),
        )
        for face_id in terminal_cap_faces
    )
    seam_boundary = atlas._record_boundary(removed_cap_records)
    seam_edge_keys = frozenset(row[0] for row in seam_boundary)
    _require(len(seam_edge_keys) == 29, "removed terminal cap has no 29-edge ring")
    post_edge_uses: dict[
        atlas.EdgeKey, list[tuple[int, atlas.PointKey, atlas.PointKey]]
    ] = {}
    for source_id, _face_id, raw_points in post_records:
        keys = [
            atlas._point_key(point)
            for point in np.asarray(raw_points, dtype=np.float64)
        ]
        for first, second in (
            (keys[0], keys[1]),
            (keys[1], keys[2]),
            (keys[2], keys[0]),
        ):
            post_edge_uses.setdefault(tuple(sorted((first, second))), []).append(
                (int(source_id), first, second)
            )
    seam_failures: list[Any] = []
    for edge_key in sorted(seam_edge_keys):
        uses = post_edge_uses.get(edge_key, [])
        if not (
            len(uses) == 2
            and {uses[0][0], uses[1][0]}
            == {a_original_id, rail_original_id}
            and uses[0][1] == uses[1][2]
            and uses[0][2] == uses[1][1]
        ):
            seam_failures.append((edge_key, uses))
    _require(not seam_failures, "stitched join has an invalid seam incidence")

    terminal_point_keys = {
        atlas._point_key(point) for point in terminal_ring
    }
    far_ring_points = stitched_vertices_array[
        far_ring_start : far_ring_start + STITCHED_RING_VERTEX_COUNT
    ]
    far_point_keys = {atlas._point_key(point) for point in far_ring_points}
    terminal_cap_duplicates = sum(
        {
            atlas._point_key(point)
            for point in np.asarray(record[2], dtype=np.float64)
        }
        <= terminal_point_keys
        for record in post_records
    )
    far_cap_count = sum(
        {
            atlas._point_key(point)
            for point in np.asarray(record[2], dtype=np.float64)
        }
        <= far_point_keys
        for record in post_rail_records
    )
    _require(terminal_cap_duplicates == 0, "terminal A cap was duplicated at join")
    _require(far_cap_count == 27, "rail far terminal cap count drifted")

    quality = atlas._quality_summary(post_records)
    topologies = {
        str(quantum): atlas._topology_for_records(post_records, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    _require(
        int(quality["double_subthreshold_triangle_count"]) == 0
        and int(quality["float32_subthreshold_triangle_count"]) == 0,
        "stitched mature fixture violates the strict 1e-16 quality floor",
    )
    _require(
        all(
            atlas._topology_passes(value) and int(value["genus"]) == 0
            for value in topologies.values()
        ),
        "stitched mature fixture failed strict topology at a weld quantum",
    )

    b_vertices = np.asarray(packet_b.get("vertices", []), dtype=np.float64)
    b_bounds = _points_bounds(b_vertices)
    b_two_ring_cells = frozenset(
        exact._coordinates_for_bounds(b_bounds, HALO_RINGS)
    )
    b_two_ring_bounds = (
        min(value[0] for value in b_two_ring_cells) * CHUNK_SIZE_METERS,
        min(value[1] for value in b_two_ring_cells) * CHUNK_SIZE_METERS,
        min(value[2] for value in b_two_ring_cells) * CHUNK_SIZE_METERS,
        (max(value[0] for value in b_two_ring_cells) + 1) * CHUNK_SIZE_METERS,
        (max(value[1] for value in b_two_ring_cells) + 1) * CHUNK_SIZE_METERS,
        (max(value[2] for value in b_two_ring_cells) + 1) * CHUNK_SIZE_METERS,
    )
    rail_points = np.vstack(
        [np.asarray(record[2], dtype=np.float64) for record in post_rail_records]
    )
    rail_join_bounds = _points_bounds(rail_points)
    rail_x_chunks = frozenset(
        exact._chunk_span(rail_join_bounds[0], rail_join_bounds[3])
    )
    b_x_chunks = {coordinate[0] for coordinate in b_two_ring_cells}
    remote_rail_x_chunks = sorted(rail_x_chunks - b_x_chunks)
    _require(
        len(remote_rail_x_chunks) >= 32,
        "stitched rail does not span at least 32 remote X chunks",
    )
    _require(
        _aabb_disjoint(b_two_ring_bounds, rail_join_bounds),
        "B two-ring AABB intersects the stitched rail/join",
    )

    provenance = atlas._provenance_summary(
        post_records,
        {a_original_id: 1446, rail_original_id: expected_rail_triangles},
    )
    material_lineage = _source_material_lineage_audit(
        post_records,
        property_lookup,
        {a_original_id: "stroke_a", rail_original_id: "stitched_rail"},
        frozenset((a_original_id, rail_original_id)),
    )
    _require(bool(provenance["passed"]), "stitched provenance validation failed")
    _require(bool(material_lineage["passed"]), "stitched material lineage failed")

    diagnostics: dict[str, Any] = {
        "fixture_sha256": fixture_sha256,
        "fixture_canonical_sha256_matches": bool(
            fixture_transport["top_level"]["matches"]
        ),
        "construction": {
            "method": "terminal_ring_alias_plus_149_translated_ring_intervals",
            "a_ring_count": STITCHED_A_RING_COUNT,
            "ring_vertex_count": STITCHED_RING_VERTEX_COUNT,
            "new_rail_ring_count": STITCHED_RAIL_NEW_RING_COUNT,
            "side_triangles_per_interval": STITCHED_SIDE_TRIANGLES_PER_INTERVAL,
            "rail_x_length_m": STITCHED_RAIL_X_LENGTH_METERS,
            "input_vertex_count": len(stitched_vertices_array),
            "input_triangle_count": len(stitched_triangles),
            "retained_a_triangle_count": len(retained_a_faces),
            "rail_triangle_count": len(rail_triangles),
            "terminal_cap_faces_removed": list(terminal_cap_faces),
            "last_side_band_template_faces": list(last_side_band_faces),
            "two_run_mesh64_run_index": [int(value) for value in run_index],
            "two_run_mesh64_original_ids": [int(value) for value in run_original_id],
            "raw_a_winding_reversed_for_manifold": reversed_for_manifold,
        },
        "accepted_a_conditioning_identity": {
            "passed": conditioned_a_digest == imported_a_digest,
            "imported_sha256": imported_a_digest,
            "conditioned_sha256": conditioned_a_digest,
            "diagnostics": a_conditioning,
        },
        "mesh64": {
            "status": exact._status_name(stitched_solid),
            "component_count": len(components),
            "component_genera": [int(component.genus()) for component in components],
            "post_import_vertex_count": post_vertex_count,
            "post_import_triangle_count": int(stitched_solid.num_tri()),
            "post_import_run_original_ids": [
                int(value) for value in post_mesh.run_original_id
            ],
        },
        "seam": {
            "terminal_ring_edge_count": len(seam_edge_keys),
            "invalid_incidence_count": len(seam_failures),
            "terminal_cap_duplicate_triangle_count": terminal_cap_duplicates,
            "far_cap_triangle_count": far_cap_count,
        },
        "quality": quality,
        "topology": topologies,
        "provenance": provenance,
        "source_material_lineage": material_lineage,
        "locality": {
            "b_bounds_m": list(b_bounds),
            "b_two_ring_bounds_m": list(b_two_ring_bounds),
            "rail_join_bounds_m": list(rail_join_bounds),
            "b_two_ring_candidate_cell_count": len(b_two_ring_cells),
            "rail_x_chunks": sorted(rail_x_chunks),
            "remote_rail_x_chunks": remote_rail_x_chunks,
            "remote_rail_x_chunk_count": len(remote_rail_x_chunks),
            "b_two_ring_aabb_disjoint_from_rail_join": True,
        },
    }
    return StitchedMatureFixture(
        manifold=stitched_solid,
        records=post_records,
        property_lookup=property_lookup,
        a_original_id=a_original_id,
        b_original_id=b_original_id,
        rail_original_id=rail_original_id,
        diagnostics=diagnostics,
    )


def _validate_stitched_mature() -> dict[str, Any]:
    """Validate the isolated stitched mature fixture without running an edit."""
    started = time.perf_counter_ns()
    script_path = Path(__file__).resolve()
    script_sha256 = hashlib.sha256(script_path.read_bytes()).hexdigest()
    stitched = _build_stitched_mature_fixture()
    diagnostics = dict(stitched.diagnostics)
    quality = diagnostics["quality"]
    topology = diagnostics["topology"]
    construction = diagnostics["construction"]
    mesh64 = diagnostics["mesh64"]
    seam = diagnostics["seam"]
    locality = diagnostics["locality"]
    provenance = diagnostics["provenance"]
    hard_gates = {
        "organic_source_ids_are_exactly_A_B_rail": (
            pair.organic_ids
            == frozenset(
                (
                    pair.stitched.a_original_id,
                    pair.stitched.b_original_id,
                    pair.stitched.rail_original_id,
                )
            )
        ),
        "classified_ungrafted_forbidden_page_set_is_nonempty": bool(
            pair.ungrafted_differing_page_ids
        ),
        "accepted_A_conditioner_is_exact_identity": bool(
            diagnostics["accepted_a_conditioning_identity"]["passed"]
        ),
        "exact_5046_vertex_count": (
            int(construction["input_vertex_count"]) == 5046
            and int(mesh64["post_import_vertex_count"]) == 5046
        ),
        "exact_10088_triangle_count": (
            int(construction["input_triangle_count"]) == 10088
            and int(mesh64["post_import_triangle_count"]) == 10088
        ),
        "exact_A_and_rail_triangle_counts": (
            int(construction["retained_a_triangle_count"]) == 1419
            and int(construction["rail_triangle_count"]) == 8669
        ),
        "two_run_mesh64_A_and_rail": (
            len(construction["two_run_mesh64_original_ids"]) == 2
            and construction["two_run_mesh64_original_ids"]
            == [stitched.a_original_id, stitched.rail_original_id]
        ),
        "seam_has_29_two_source_opposite_incidence_edges": (
            int(seam["terminal_ring_edge_count"]) == 29
            and int(seam["invalid_incidence_count"]) == 0
        ),
        "terminal_cap_not_duplicated_and_far_cap_restored": (
            int(seam["terminal_cap_duplicate_triangle_count"]) == 0
            and int(seam["far_cap_triangle_count"]) == 27
        ),
        "float64_and_float32_quality_strictly_above_1e_16": (
            int(quality["double_subthreshold_triangle_count"]) == 0
            and int(quality["float32_subthreshold_triangle_count"]) == 0
        ),
        "topology_passes_at_1e_8_and_1e_7_with_genus_zero": all(
            atlas._topology_passes(value) and int(value["genus"]) == 0
            for value in topology.values()
        ),
        "mesh64_NoError_one_component_genus_zero": (
            mesh64["status"] == "NoError"
            and int(mesh64["component_count"]) == 1
            and mesh64["component_genera"] == [0]
        ),
        "rail_spans_at_least_32_remote_X_chunks": (
            int(locality["remote_rail_x_chunk_count"]) >= 32
        ),
        "post_import_rail_provenance_is_8669_faces": (
            bool(provenance["passed"])
            and int(
                provenance["triangle_counts_by_original_id"][
                    str(stitched.rail_original_id)
                ]
            )
            == 8669
        ),
        "source_and_material_lineage_preserved": bool(
            diagnostics["source_material_lineage"]["passed"]
        ),
        "B_two_ring_AABB_disjoint_from_rail_join": bool(
            locality["b_two_ring_aabb_disjoint_from_rail_join"]
        ),
        "paired_and_young_modes_not_executed": True,
        "production_files_untouched": True,
    }
    failed = [name for name, passed in hard_gates.items() if not passed]
    _require(
        not failed,
        "stitched mature validation gates failed: " + ", ".join(failed),
    )
    return {
        "schema": "forge_v2_incremental_publication_atlas_stitched_mature_validation",
        "schema_version": 1,
        "outcome": "pass",
        "proof_passed": True,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_stitched_mature_fixture_validation",
        "production_files_touched": False,
        "production_ready": False,
        "paired_mode_wired": False,
        "young_or_paired_proof_executed": False,
        "script": {
            "path": str(script_path),
            "sha256": script_sha256,
        },
        "engine": {
            "name": "manifold3d",
            "version": exact.MANIFOLD_VERSION,
            "module_path": str(Path(manifold3d.__file__).resolve()),
            "isolated_target": str(exact.ISOLATED_SITE),
        },
        "source_ids": {
            "stroke_a": stitched.a_original_id,
            "reserved_stroke_b": stitched.b_original_id,
            "stitched_rail": stitched.rail_original_id,
        },
        **diagnostics,
        "hard_gates": hard_gates,
        "validation_wall_ms": (time.perf_counter_ns() - started) / 1.0e6,
        "limitations": [
            "This validates only the stitched mature fixture; it does not run the paired B transaction.",
            "The procedural rail is tools-only and is not wired into production or Godot.",
        ],
    }


def _prepare_stitched_publication_prestate() -> StitchedPublicationPrestate:
    """Build only the direct authorities/publications needed for B-local audit."""
    fixture, fixture_sha256 = exact._load_fixture()
    fixture_transport = exact._validate_fixture_hashes(fixture)
    first_original_id = int(manifold3d.Manifold.reserve_ids(3))
    source_ids = (
        first_original_id,
        first_original_id + 1,
        first_original_id + 2,
    )
    a_original_id, b_original_id, rail_original_id = source_ids
    stroke_a = exact._make_packet_solid(
        "stroke_a", fixture["packets"]["stroke_a"], a_original_id
    )
    stroke_b = exact._make_packet_solid(
        "stroke_b", fixture["packets"]["stroke_b"], b_original_id
    )
    stitched = _build_stitched_mature_fixture(
        fixture=fixture,
        fixture_sha256=fixture_sha256,
        fixture_transport=fixture_transport,
        source_ids=source_ids,
        stroke_a=stroke_a,
    )
    _require(
        (
            stroke_a.original_id,
            stroke_b.original_id,
            stitched.rail_original_id,
        )
        == source_ids
        and stitched.a_original_id == stroke_a.original_id
        and stitched.b_original_id == stroke_b.original_id,
        "young and stitched authorities do not share one exact source reservation",
    )
    selected_space = frozenset(
        exact._coordinates_for_bounds(stroke_b.manifold.bounding_box(), HALO_RINGS)
    )
    conditioned_a_records, a_conditioning = _condition_authority(
        stroke_a.manifold, stitched.property_lookup
    )
    imported_a_records = _records_from_solid(stroke_a.manifold)
    _require(
        atlas._records_digest(conditioned_a_records)
        == atlas._records_digest(imported_a_records),
        "young A conditioner is not identity during prestate bootstrap",
    )
    young_publication, young_publication_build = _build_publication_state(
        conditioned_a_records,
        stitched.property_lookup,
        revision=0,
    )
    retained_conditioned_a = [
        record
        for record in conditioned_a_records
        if not (
            int(record[0]) == a_original_id
            and 1419 <= int(record[1]) <= 1445
        )
    ]
    rail_records = [
        record
        for record in stitched.records
        if int(record[0]) == rail_original_id
    ]
    _require(
        len(retained_conditioned_a) == 1419 and len(rail_records) == 8669,
        "direct mature publication bootstrap source counts drifted",
    )
    mature_bootstrap_records = atlas._sorted_records(
        [*retained_conditioned_a, *rail_records]
    )
    mature_bootstrap_digest = atlas._records_digest(mature_bootstrap_records)
    stitched_authority_digest = atlas._records_digest(stitched.records)
    _require(
        mature_bootstrap_digest == stitched_authority_digest,
        "direct mature publication records differ from stitched authority",
    )
    mature_publication, mature_publication_build = _build_publication_state(
        mature_bootstrap_records,
        stitched.property_lookup,
        revision=0,
    )
    b_edit_cells = frozenset(
        _cells_for_bounds(
            tuple(float(value) for value in stroke_b.manifold.bounding_box())
        )
    )
    halo_manifests = {
        "young": _publication_jurisdiction_manifest(
            young_publication, selected_space
        ),
        "mature": _publication_jurisdiction_manifest(
            mature_publication, selected_space
        ),
    }
    edit_manifests = {
        "young": _publication_jurisdiction_manifest(
            young_publication, b_edit_cells
        ),
        "mature": _publication_jurisdiction_manifest(
            mature_publication, b_edit_cells
        ),
    }
    return StitchedPublicationPrestate(
        fixture_sha256=fixture_sha256,
        stitched=stitched,
        stroke_a=stroke_a,
        stroke_b=stroke_b,
        young_publication=young_publication,
        mature_publication=mature_publication,
        selected_space=selected_space,
        b_edit_cells=b_edit_cells,
        conditioned_a_records=tuple(conditioned_a_records),
        mature_bootstrap_records=tuple(mature_bootstrap_records),
        a_conditioning=a_conditioning,
        young_publication_build=young_publication_build,
        mature_publication_build=mature_publication_build,
        halo_manifests=halo_manifests,
        edit_manifests=edit_manifests,
        halo_comparison=_jurisdiction_manifest_comparison(
            halo_manifests["young"], halo_manifests["mature"]
        ),
        edit_comparison=_jurisdiction_manifest_comparison(
            edit_manifests["young"], edit_manifests["mature"]
        ),
    )


def _diagnose_stitched_prestate_manifest() -> dict[str, Any]:
    """Explain young/stitched publication locality without claiming a proof."""
    started = time.perf_counter_ns()
    script_path = Path(__file__).resolve()
    script_sha256 = hashlib.sha256(script_path.read_bytes()).hexdigest()
    prestate = _prepare_stitched_publication_prestate()
    stitched = prestate.stitched
    halo = prestate.halo_comparison
    edit = prestate.edit_comparison
    return {
        "schema": "forge_v2_stitched_prestate_manifest_diagnostic",
        "schema_version": 1,
        "outcome": "diagnostic_complete",
        "diagnostic_only": True,
        "proof_passed": False,
        "production_ready": False,
        "production_files_touched": False,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_stitched_prestate_publication_manifest",
        "script": {
            "path": str(script_path),
            "sha256": script_sha256,
        },
        "fixture_sha256": prestate.fixture_sha256,
        "source_ids": {
            "stroke_a": stitched.a_original_id,
            "reserved_stroke_b": stitched.b_original_id,
            "stitched_rail": stitched.rail_original_id,
            "one_shared_contiguous_reservation": (
                stitched.b_original_id == stitched.a_original_id + 1
                and stitched.rail_original_id == stitched.a_original_id + 2
            ),
        },
        "construction": {
            "B_transaction_count": 0,
            "extension_incremental_add_count": 0,
            "storage_split_count": 0,
            "publication_authority_audit_count": 0,
            "mature_bootstrap_boolean_count": 0,
            "mature_bootstrap_global_conditioner_count": 0,
            "young_record_count": len(prestate.conditioned_a_records),
            "mature_record_count": len(prestate.mature_bootstrap_records),
            "young_record_sha256": atlas._records_digest(
                prestate.conditioned_a_records
            ),
            "mature_record_sha256": atlas._records_digest(
                prestate.mature_bootstrap_records
            ),
            "stitched_authority_record_sha256": atlas._records_digest(
                stitched.records
            ),
            "young_publication_build": prestate.young_publication_build,
            "mature_publication_build": prestate.mature_publication_build,
        },
        "B_halo": {
            "cells": [list(value) for value in sorted(prestate.selected_space)],
            "young_manifest_counts": {
                "direct_atoms": prestate.halo_manifests["young"][
                    "direct_atom_count"
                ],
                "frontier_atoms": prestate.halo_manifests["young"][
                    "neighbor_frontier_atom_count"
                ],
                "accessed_atoms": prestate.halo_manifests["young"][
                    "accessed_atom_count"
                ],
                "accessed_pages": prestate.halo_manifests["young"][
                    "accessed_page_count"
                ],
            },
            "mature_manifest_counts": {
                "direct_atoms": prestate.halo_manifests["mature"][
                    "direct_atom_count"
                ],
                "frontier_atoms": prestate.halo_manifests["mature"][
                    "neighbor_frontier_atom_count"
                ],
                "accessed_atoms": prestate.halo_manifests["mature"][
                    "accessed_atom_count"
                ],
                "accessed_pages": prestate.halo_manifests["mature"][
                    "accessed_page_count"
                ],
            },
            "comparison": halo,
        },
        "B_edit_cells": {
            "cells": [list(value) for value in sorted(prestate.b_edit_cells)],
            "young_manifest_counts": {
                "direct_atoms": prestate.edit_manifests["young"][
                    "direct_atom_count"
                ],
                "frontier_atoms": prestate.edit_manifests["young"][
                    "neighbor_frontier_atom_count"
                ],
                "accessed_atoms": prestate.edit_manifests["young"][
                    "accessed_atom_count"
                ],
                "accessed_pages": prestate.edit_manifests["young"][
                    "accessed_page_count"
                ],
            },
            "mature_manifest_counts": {
                "direct_atoms": prestate.edit_manifests["mature"][
                    "direct_atom_count"
                ],
                "frontier_atoms": prestate.edit_manifests["mature"][
                    "neighbor_frontier_atom_count"
                ],
                "accessed_atoms": prestate.edit_manifests["mature"][
                    "accessed_atom_count"
                ],
                "accessed_pages": prestate.edit_manifests["mature"][
                    "accessed_page_count"
                ],
            },
            "comparison": edit,
        },
        "observations": {
            "halo_components_equal": bool(halo["all_components_equal"]),
            "edit_components_equal": bool(edit["all_components_equal"]),
            "no_equality_claim": True,
            "page_policy_changed": False,
            "publication_objects_grafted": False,
        },
        "diagnostic_wall_ms": (time.perf_counter_ns() - started) / 1.0e6,
    }


def _build_stitched_frozen_prestate() -> StitchedFrozenPrestate:
    """Bootstrap young A and stitched mature states without a mature Boolean."""
    publication_prestate = _prepare_stitched_publication_prestate()
    stitched = publication_prestate.stitched
    stroke_a = publication_prestate.stroke_a
    stroke_b = publication_prestate.stroke_b
    young_publication = publication_prestate.young_publication
    direct_mature_publication = publication_prestate.mature_publication
    selected_space = publication_prestate.selected_space
    b_edit_cells = publication_prestate.b_edit_cells
    conditioned_a_records = publication_prestate.conditioned_a_records
    mature_bootstrap_records = publication_prestate.mature_bootstrap_records
    a_conditioning = publication_prestate.a_conditioning
    young_publication_build = publication_prestate.young_publication_build
    mature_publication_build = publication_prestate.mature_publication_build
    b_halo_manifest_young = publication_prestate.halo_manifests["young"]
    b_halo_manifest_mature = publication_prestate.halo_manifests["mature"]
    b_edit_manifest_young = publication_prestate.edit_manifests["young"]
    b_edit_manifest_mature = publication_prestate.edit_manifests["mature"]
    _require(
        bool(publication_prestate.edit_comparison["all_components_equal"])
        and bool(
            publication_prestate.edit_comparison[
                "whole_semantic_sha256_equal"
            ]
        ),
        "stitched mature B edit-cell publication manifests differ",
    )
    halo_page_leakage = _classify_halo_page_leakage(
        young_publication,
        direct_mature_publication,
        b_halo_manifest_young,
        b_halo_manifest_mature,
        publication_prestate.halo_comparison,
        stitched.a_original_id,
        stitched.rail_original_id,
    )
    _require(
        bool(halo_page_leakage["passed"]),
        "full-halo publication differences are not page-only rail/join leakage",
    )
    _require(
        int(b_halo_manifest_young["direct_atom_count"]) > 0
        and int(b_halo_manifest_young["accessed_page_count"]) > 0,
        "B read-jurisdiction manifest is empty",
    )
    mature_publication, edit_publication_graft = (
        _graft_exact_edit_publication_objects(
            young_publication,
            direct_mature_publication,
            b_edit_cells,
            b_edit_manifest_young,
            b_edit_manifest_mature,
            publication_prestate.edit_comparison,
            stitched.rail_original_id,
        )
    )
    grafted_edit_page_ids = {
        row["page_id"] for row in b_edit_manifest_young["pages"]
    }
    ungrafted_differing_page_ids = set(
        halo_page_leakage["classified_differing_page_ids"]
    )
    _require(
        grafted_edit_page_ids.isdisjoint(ungrafted_differing_page_ids),
        "B edit object graft captured a differing full-halo page",
    )

    a_original_id = stitched.a_original_id
    b_original_id = stitched.b_original_id
    rail_original_id = stitched.rail_original_id
    organic_ids = frozenset((a_original_id, rail_original_id))
    young_storage = exact.WorkpieceState(
        exact._split_to_chunks(stroke_a.manifold), revision=0
    )
    independent_mature_storage = exact.WorkpieceState(
        exact._split_to_chunks(stitched.manifold), revision=0
    )
    mature_storage, local_fragment_reuse = _reuse_verified_b_local_fragments(
        young_storage,
        independent_mature_storage,
        selected_space,
        organic_ids,
    )
    young_fragment_manifest = _selected_fragment_identity_manifest(
        young_storage, selected_space
    )
    mature_fragment_manifest = _selected_fragment_identity_manifest(
        mature_storage, selected_space
    )
    _require(
        young_fragment_manifest == mature_fragment_manifest,
        "grafted mature B-halo fragment manifest differs from young",
    )
    young_perimeter = exact._perimeter_cap_signature(
        young_storage.fragments, set(selected_space), set(organic_ids)
    )
    mature_perimeter = exact._perimeter_cap_signature(
        mature_storage.fragments, set(selected_space), set(organic_ids)
    )
    _require(
        young_perimeter == mature_perimeter,
        "grafted mature B-halo perimeter caps differ from young",
    )

    (
        mature_emitted_records,
        mature_decoded_pages,
        _mature_publication_solid,
        mature_publication_audit,
    ) = _publication_authority_audit(
        mature_publication,
        stitched.manifold,
        stitched.property_lookup,
        {a_original_id: 1446, rail_original_id: 8669},
        {a_original_id: "stroke_a", rail_original_id: "stitched_rail"},
        organic_ids,
    )
    _require(
        bool(mature_publication_audit["passed"]),
        "direct mature page publication differs from stitched authority",
    )
    mature_storage_solid, mature_storage_assembly = (
        exact._assemble_region_from_fragments(
            mature_storage.fragments, set(organic_ids)
        )
    )
    mature_storage_comparison = exact._compare_solids(
        mature_storage_solid, stitched.manifold
    )
    _require(
        all(exact._comparison_gate_summary(mature_storage_comparison).values()),
        "grafted mature storage differs from stitched authority",
    )
    independent_caps = exact._paired_cap_analysis(
        independent_mature_storage.fragments, set(organic_ids)
    )
    mature_caps = exact._paired_cap_analysis(
        mature_storage.fragments, set(organic_ids)
    )
    _require(
        _caps_are_paired(independent_caps) and _caps_are_paired(mature_caps),
        "stitched mature storage compiler caps are not paired/oriented",
    )

    rail_atoms = [
        atom
        for atom in mature_publication.atoms.values()
        if atom.source_id == rail_original_id
    ]
    rail_page_ids = {
        mature_publication.atom_to_page[atom.lineage_id] for atom in rail_atoms
    }
    remote_rail_atoms = [
        atom
        for atom in rail_atoms
        if set(atom.overlap_cells).isdisjoint(selected_space)
    ]
    remote_rail_pages = [
        mature_publication.pages[page_id]
        for page_id in sorted(rail_page_ids)
        if set(mature_publication.pages[page_id].overlap_cells).isdisjoint(
            selected_space
        )
    ]
    remote_rail_page_ids = {page.page_id for page in remote_rail_pages}
    leaking_rail_page_ids = set(rail_page_ids) - remote_rail_page_ids
    _require(
        bool(rail_atoms)
        and len(remote_rail_atoms) == len(rail_atoms)
        and bool(rail_page_ids)
        and bool(remote_rail_pages)
        and leaking_rail_page_ids <= ungrafted_differing_page_ids,
        "stitched rail remote/page-leakage classification failed",
    )
    remote_rail_atom_manifest = [
        (
            atom.lineage_id,
            atom.version_id,
            atom.payload_sha256,
            mature_publication.atom_to_page[atom.lineage_id],
        )
        for atom in sorted(rail_atoms, key=lambda value: value.lineage_id)
    ]
    remote_rail_page_manifest = [
        (
            page.page_id,
            page.payload_sha256,
            page.atom_ids,
        )
        for page in sorted(remote_rail_pages, key=lambda value: value.page_id)
    ]
    mature_bootstrap_digest = atlas._records_digest(mature_bootstrap_records)
    stitched_authority_digest = atlas._records_digest(stitched.records)

    diagnostics: dict[str, Any] = {
        "construction": {
            "authority": "validated_stitched_manifold",
            "old_extension_used": False,
            "extension_incremental_add_count": 0,
            "mature_bootstrap_boolean_count": 0,
            "mature_bootstrap_global_conditioner_count": 0,
            "mature_bootstrap": (
                "conditioned_A_minus_terminal_cap_faces_1419_1445_plus_raw_stitched_rail"
            ),
            "shared_reserved_source_ids": {
                "young_a": stroke_a.original_id,
                "young_b": stroke_b.original_id,
                "stitched_a": stitched.a_original_id,
                "stitched_rail": stitched.rail_original_id,
            },
            "mature_bootstrap_record_sha256": mature_bootstrap_digest,
            "stitched_authority_record_sha256": stitched_authority_digest,
            "mature_bootstrap_record_count": len(mature_bootstrap_records),
        },
        "young_A_conditioning": a_conditioning,
        "young_publication_build": young_publication_build,
        "mature_publication_build": mature_publication_build,
        "storage": {
            "young_fragment_count": len(young_storage.fragments),
            "independently_split_mature_fragment_count": len(
                independent_mature_storage.fragments
            ),
            "grafted_mature_fragment_count": len(mature_storage.fragments),
            "local_fragment_reuse": local_fragment_reuse,
            "young_B_halo_fragment_manifest": young_fragment_manifest,
            "mature_B_halo_fragment_manifest": mature_fragment_manifest,
            "B_halo_perimeter_signature_equal": young_perimeter
            == mature_perimeter,
            "independent_caps": independent_caps,
            "grafted_caps": mature_caps,
            "assembly": mature_storage_assembly,
            "comparison_to_authority": mature_storage_comparison,
        },
        "publication": {
            "emitted_triangle_count": len(mature_emitted_records),
            "decoded_page_count": len(mature_decoded_pages),
            "audit": mature_publication_audit,
            "young_atom_count": len(young_publication.atoms),
            "young_page_count": len(young_publication.pages),
            "mature_atom_count": len(mature_publication.atoms),
            "mature_page_count": len(mature_publication.pages),
        },
        "B_read_jurisdiction": {
            "selected_halo_cells": [list(value) for value in sorted(selected_space)],
            "edit_cells": [list(value) for value in sorted(b_edit_cells)],
            "young_halo_manifest": b_halo_manifest_young,
            "mature_halo_manifest": b_halo_manifest_mature,
            "young_edit_manifest": b_edit_manifest_young,
            "mature_edit_manifest": b_edit_manifest_mature,
            "halo_comparison": publication_prestate.halo_comparison,
            "edit_comparison": publication_prestate.edit_comparison,
            "halo_page_leakage": halo_page_leakage,
            "edit_publication_object_graft": edit_publication_graft,
            "ungrafted_differing_page_ids": sorted(
                ungrafted_differing_page_ids
            ),
            "differing_halo_pages_ungrafted": (
                grafted_edit_page_ids.isdisjoint(
                    ungrafted_differing_page_ids
                )
            ),
            "halo_semantic_manifests_equal": bool(
                publication_prestate.halo_comparison[
                    "whole_semantic_sha256_equal"
                ]
            ),
            "edit_semantic_manifests_equal": bool(
                publication_prestate.edit_comparison[
                    "whole_semantic_sha256_equal"
                ]
            ),
            "paired_traced_read_contract": (
                "future paired B read/work signatures must fail if any "
                "accessed/rebuilt page ID intersects ungrafted_differing_page_ids"
            ),
            "paired_B_transaction_executed": False,
        },
        "remote_rail": {
            "atom_count": len(rail_atoms),
            "page_count": len(rail_page_ids),
            "remote_page_count": len(remote_rail_pages),
            "leaking_page_count": len(leaking_rail_page_ids),
            "leaking_page_ids": sorted(leaking_rail_page_ids),
            "all_atom_footprints_disjoint_from_B_halo": True,
            "all_page_footprints_disjoint_from_B_halo": not leaking_rail_page_ids,
            "leaking_pages_are_classified_ungrafted_join_pages": (
                leaking_rail_page_ids <= ungrafted_differing_page_ids
            ),
            "atom_manifest_sha256": _sha256_json(remote_rail_atom_manifest),
            "page_manifest_sha256": _sha256_json(remote_rail_page_manifest),
        },
    }
    return StitchedFrozenPrestate(
        stitched=stitched,
        stroke_a=stroke_a,
        stroke_b=stroke_b,
        young_storage=young_storage,
        mature_storage=mature_storage,
        young_publication=young_publication,
        mature_publication=mature_publication,
        selected_space=selected_space,
        edit_cells=b_edit_cells,
        ungrafted_differing_page_ids=frozenset(
            ungrafted_differing_page_ids
        ),
        property_lookup=stitched.property_lookup,
        diagnostics=diagnostics,
    )


def _validate_stitched_prestate() -> dict[str, Any]:
    """Validate frozen young/mature bootstrap only; never execute B."""
    started = time.perf_counter_ns()
    script_path = Path(__file__).resolve()
    script_sha256 = hashlib.sha256(script_path.read_bytes()).hexdigest()
    prestate = _build_stitched_frozen_prestate()
    diagnostics = dict(prestate.diagnostics)
    construction = diagnostics["construction"]
    storage = diagnostics["storage"]
    publication = diagnostics["publication"]
    jurisdiction = diagnostics["B_read_jurisdiction"]
    remote_rail = diagnostics["remote_rail"]
    shared_ids = construction["shared_reserved_source_ids"]
    publication_audit = publication["audit"]
    hard_gates = {
        "young_and_stitched_share_exact_reserved_A_ID": (
            int(shared_ids["young_a"]) == int(shared_ids["stitched_a"])
        ),
        "young_B_and_stitched_rail_share_one_reserved_ID_tuple": (
            int(shared_ids["young_b"]) == int(shared_ids["young_a"]) + 1
            and int(shared_ids["stitched_rail"])
            == int(shared_ids["young_a"]) + 2
        ),
        "mature_authority_is_validated_stitched_manifold": (
            construction["authority"] == "validated_stitched_manifold"
            and not bool(construction["old_extension_used"])
            and int(construction["extension_incremental_add_count"]) == 0
        ),
        "mature_publication_bootstrap_used_zero_Boolean_or_global_conditioner": (
            int(construction["mature_bootstrap_boolean_count"]) == 0
            and int(construction["mature_bootstrap_global_conditioner_count"])
            == 0
        ),
        "mature_bootstrap_records_exactly_equal_stitched_authority": (
            construction["mature_bootstrap_record_sha256"]
            == construction["stitched_authority_record_sha256"]
            and int(construction["mature_bootstrap_record_count"]) == 10088
        ),
        "B_halo_fragment_geometry_and_caps_verified_before_object_graft": (
            bool(storage["local_fragment_reuse"]["geometry_equivalence"]["passed"])
            and bool(
                storage["local_fragment_reuse"][
                    "compiler_cap_signatures_equal"
                ]
            )
        ),
        "mature_B_halo_uses_exact_young_Fragment_objects": (
            int(storage["local_fragment_reuse"]["selected_coordinate_count"])
            == int(
                storage["local_fragment_reuse"][
                    "reused_identical_object_count"
                ]
            )
            and storage["young_B_halo_fragment_manifest"]
            == storage["mature_B_halo_fragment_manifest"]
        ),
        "grafted_mature_storage_matches_stitched_authority": all(
            exact._comparison_gate_summary(
                storage["comparison_to_authority"]
            ).values()
        ),
        "independent_and_grafted_storage_caps_are_paired_oriented": (
            _caps_are_paired(storage["independent_caps"])
            and _caps_are_paired(storage["grafted_caps"])
            and bool(storage["B_halo_perimeter_signature_equal"])
        ),
        "direct_page_publication_matches_stitched_authority": bool(
            publication_audit["passed"]
        ),
        "publication_source_material_cap_topology_fidelity_gates_pass": (
            bool(publication_audit["provenance"]["passed"])
            and int(
                publication_audit["provenance"][
                    "compiler_cap_triangle_count"
                ]
            )
            == 0
            and bool(publication_audit["source_material_lineage"]["passed"])
            and all(
                atlas._topology_passes(value)
                and int(value["genus"]) == 0
                for value in publication_audit["topology"].values()
            )
            and float(
                publication_audit["comparison_to_authority"][
                    "sampled_bidirectional_maximum_m"
                ]
            )
            <= MAX_SAMPLED_SURFACE_DISTANCE_METERS
            and float(
                publication_audit["comparison_to_authority"][
                    "symmetric_difference_volume_m3"
                ]
            )
            <= MAX_SYMMETRIC_DIFFERENCE_VOLUME_M3
        ),
        "B_halo_atom_geometry_and_adjacency_are_exact": (
            bool(
                jurisdiction["halo_page_leakage"][
                    "invariant_components_equal"
                ]
            )
            and bool(jurisdiction["halo_page_leakage"]["passed"])
        ),
        "B_halo_cell_page_leakage_is_only_classified_cap_to_rail_join": (
            bool(
                jurisdiction["halo_page_leakage"][
                    "page_differences_classified"
                ]
            )
            and bool(
                jurisdiction["halo_page_leakage"]["cells_are_page_only"]
            )
        ),
        "B_edit_complete_six_component_manifest_is_exact": (
            bool(jurisdiction["edit_semantic_manifests_equal"])
            and jurisdiction["young_edit_manifest"]["semantic_sha256"]
            == jurisdiction["mature_edit_manifest"]["semantic_sha256"]
            and bool(
                jurisdiction["edit_comparison"]["all_components_equal"]
            )
        ),
        "B_edit_atoms_and_pages_are_exact_young_objects": (
            int(
                jurisdiction["edit_publication_object_graft"][
                    "grafted_atom_count"
                ]
            )
            == int(
                jurisdiction["edit_publication_object_graft"][
                    "identical_atom_object_count"
                ]
            )
            and int(
                jurisdiction["edit_publication_object_graft"][
                    "grafted_page_count"
                ]
            )
            == int(
                jurisdiction["edit_publication_object_graft"][
                    "identical_page_object_count"
                ]
            )
        ),
        "B_edit_graft_payloads_indexes_exact_and_contains_no_rail": (
            bool(
                jurisdiction["edit_publication_object_graft"][
                    "atom_payloads_exact_before_graft"
                ]
            )
            and bool(
                jurisdiction["edit_publication_object_graft"][
                    "page_payloads_exact_before_graft"
                ]
            )
            and bool(
                jurisdiction["edit_publication_object_graft"][
                    "all_indexes_exact_before_graft"
                ]
            )
            and int(
                jurisdiction["edit_publication_object_graft"][
                    "rail_atom_count_in_grafted_pages"
                ]
            )
            == 0
            and bool(
                jurisdiction["edit_publication_object_graft"][
                    "post_graft_edit_semantics_equal"
                ]
            )
        ),
        "differing_halo_pages_remain_ungrafted_for_future_trace_gate": (
            bool(jurisdiction["differing_halo_pages_ungrafted"])
            and not bool(jurisdiction["paired_B_transaction_executed"])
        ),
        "rail_atoms_are_outside_B_halo_and_remote_pages_are_nonempty": (
            int(remote_rail["atom_count"]) > 0
            and int(remote_rail["page_count"]) > 0
            and int(remote_rail["remote_page_count"]) > 0
            and bool(
                remote_rail["all_atom_footprints_disjoint_from_B_halo"]
            )
            and bool(
                remote_rail[
                    "leaking_pages_are_classified_ungrafted_join_pages"
                ]
            )
        ),
        "B_transaction_and_paired_mode_not_executed": True,
        "production_files_untouched": True,
    }
    failed = [name for name, passed in hard_gates.items() if not passed]
    _require(
        not failed,
        "stitched frozen-prestate gates failed: " + ", ".join(failed),
    )
    return {
        "schema": "forge_v2_incremental_publication_atlas_stitched_prestate_validation",
        "schema_version": 1,
        "outcome": "pass",
        "proof_passed": True,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_stitched_frozen_prestate_validation",
        "production_files_touched": False,
        "production_ready": False,
        "B_transaction_executed": False,
        "paired_mode_wired": False,
        "script": {"path": str(script_path), "sha256": script_sha256},
        "stitched_fixture_validation": prestate.stitched.diagnostics,
        **diagnostics,
        "hard_gates": hard_gates,
        "validation_wall_ms": (time.perf_counter_ns() - started) / 1.0e6,
        "limitations": [
            "This validates frozen young/mature prestates only; it does not execute B.",
            "The stitched authority remains tools-only and is not wired into production.",
            "A future paired proof must fail its traced read/work signature if B accesses or rebuilds any ungrafted differing halo page.",
        ],
    }


def _accepted_stitched_prestate_signature(
    artifact: Mapping[str, Any],
) -> dict[str, Any]:
    def semantic_fragments(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
        return [
            {
                "coordinate": list(row["coordinate"]),
                "mesh_sha256": str(row["mesh_sha256"]),
            }
            for row in rows
        ]

    construction = artifact["construction"]
    storage = artifact["storage"]
    jurisdiction = artifact["B_read_jurisdiction"]
    publication = artifact["publication"]
    remote = artifact["remote_rail"]
    return {
        "fixture_sha256": artifact["stitched_fixture_validation"][
            "fixture_sha256"
        ],
        "shared_source_ids": construction["shared_reserved_source_ids"],
        "mature_bootstrap_record_sha256": construction[
            "mature_bootstrap_record_sha256"
        ],
        "stitched_authority_record_sha256": construction[
            "stitched_authority_record_sha256"
        ],
        "mature_bootstrap_record_count": construction[
            "mature_bootstrap_record_count"
        ],
        "young_selected_fragments": semantic_fragments(
            storage["young_B_halo_fragment_manifest"]
        ),
        "mature_selected_fragments": semantic_fragments(
            storage["mature_B_halo_fragment_manifest"]
        ),
        "young_halo_semantic_sha256": jurisdiction["young_halo_manifest"][
            "semantic_sha256"
        ],
        "mature_halo_semantic_sha256": jurisdiction["mature_halo_manifest"][
            "semantic_sha256"
        ],
        "young_edit_semantic_sha256": jurisdiction["young_edit_manifest"][
            "semantic_sha256"
        ],
        "mature_edit_semantic_sha256": jurisdiction["mature_edit_manifest"][
            "semantic_sha256"
        ],
        "ungrafted_differing_page_ids": jurisdiction[
            "ungrafted_differing_page_ids"
        ],
        "young_atom_count": publication["young_atom_count"],
        "young_page_count": publication["young_page_count"],
        "mature_atom_count": publication["mature_atom_count"],
        "mature_page_count": publication["mature_page_count"],
        "remote_rail_atom_count": remote["atom_count"],
        "remote_rail_page_count": remote["page_count"],
        "remote_rail_atom_manifest_sha256": remote["atom_manifest_sha256"],
        "remote_rail_page_manifest_sha256": remote["page_manifest_sha256"],
    }


def _accepted_pair_fragment_diagnostic_binding() -> dict[str, Any]:
    """Load the frozen allocator-label diagnosis without treating it as proof."""
    artifact_bytes = OUTPUT_STITCHED_PAIR_FRAGMENT_DIAGNOSTIC_JSON.read_bytes()
    artifact_sha256 = hashlib.sha256(artifact_bytes).hexdigest()
    _require(
        artifact_sha256
        == ACCEPTED_STITCHED_PAIR_FRAGMENT_DIAGNOSTIC_SHA256,
        "accepted stitched pair fragment diagnostic SHA changed",
    )
    artifact = json.loads(artifact_bytes.decode("utf-8"))
    raw_coordinates = sorted(
        tuple(int(value) for value in coordinate)
        for coordinate in artifact["raw_digest_differing_coordinates"]
    )
    cap_label_coordinates = sorted(
        tuple(int(value) for value in coordinate)
        for coordinate in artifact[
            "raw_cap_label_mapping_differing_coordinates"
        ]
    )
    execution_scope = artifact["execution_scope"]
    accepted = (
        artifact.get("schema")
        == "forge_v2_stitched_pair_fragment_diagnostic"
        and int(artifact.get("schema_version", -1)) == 2
        and artifact.get("outcome") == "diagnostic_complete"
        and artifact.get("scope")
        == "tools_only_sequential_full_pair_fragment_diagnostic"
        and bool(artifact.get("diagnostic_only"))
        and artifact.get("proof_passed") is False
        and artifact.get("accepted_prestate_artifact_sha256")
        == ACCEPTED_STITCHED_PRESTATE_SHA256
        and execution_scope.get("sequence")
        == [
            "full_young_incremental_add",
            "full_mature_incremental_add",
            "deferred_comparison_after_both_complete",
        ]
        and bool(
            execution_scope.get(
                "no_inspection_or_extra_manifold_call_between_transactions"
            )
        )
        and int(execution_scope.get("zero_move_count", -1)) == 2
        and int(execution_scope.get("publication_overlay_count", -1)) == 2
        and int(execution_scope.get("post_oracle_count", -1)) == 0
        and int(execution_scope.get("paired_validation_gate_count", -1)) == 0
        and bool(artifact["primary_bit_exact_comparison"]["passed"])
        and bool(
            artifact["corroboration"][
                "semantic_and_tolerance_helpers_are_not_primary"
            ]
        )
        and bool(
            artifact[
                "raw_cap_label_differences_exactly_explain_raw_digest_differences"
            ]
        )
        and bool(
            artifact["diagnostic_conclusion"][
                "raw_digest_difference_is_only_raw_compiler_cap_labels"
            ]
        )
        and len(raw_coordinates) == 16
        and raw_coordinates == cap_label_coordinates
    )
    _require(
        accepted,
        "accepted stitched pair fragment diagnostic contract failed",
    )
    return {
        "path": str(OUTPUT_STITCHED_PAIR_FRAGMENT_DIAGNOSTIC_JSON),
        "sha256": artifact_sha256,
        "script_sha256": str(artifact["script"]["sha256"]),
        "diagnostic_only": True,
        "proof_passed": False,
        "raw_digest_differing_coordinate_count": len(raw_coordinates),
        "raw_digest_differing_coordinates": [
            list(coordinate) for coordinate in raw_coordinates
        ],
        "raw_differences_exactly_explained_by_cap_labels": True,
        "primary_bit_exact_comparison_passed": True,
    }


def _build_stitched_pair_inputs() -> StitchedPairInputs:
    """Prepare accepted local prestates; skip exhaustive authority oracles."""
    artifact_bytes = OUTPUT_STITCHED_PRESTATE_VALIDATION_JSON.read_bytes()
    artifact_sha256 = hashlib.sha256(artifact_bytes).hexdigest()
    _require(
        artifact_sha256 == ACCEPTED_STITCHED_PRESTATE_SHA256,
        "accepted stitched prestate artifact SHA changed",
    )
    accepted = json.loads(artifact_bytes.decode("utf-8"))
    _require(
        accepted.get("outcome") == "pass"
        and bool(accepted.get("proof_passed"))
        and all(bool(value) for value in accepted["hard_gates"].values()),
        "accepted stitched prestate artifact is not a fully gated pass",
    )
    publication_prestate = _prepare_stitched_publication_prestate()
    stitched = publication_prestate.stitched
    young_publication = publication_prestate.young_publication
    direct_mature_publication = publication_prestate.mature_publication
    selected_space = publication_prestate.selected_space
    edit_cells = publication_prestate.b_edit_cells
    _require(
        bool(publication_prestate.edit_comparison["all_components_equal"])
        and bool(
            publication_prestate.edit_comparison[
                "whole_semantic_sha256_equal"
            ]
        ),
        "stitched pair edit-cell publication manifests differ",
    )
    halo_leakage = _classify_halo_page_leakage(
        young_publication,
        direct_mature_publication,
        publication_prestate.halo_manifests["young"],
        publication_prestate.halo_manifests["mature"],
        publication_prestate.halo_comparison,
        stitched.a_original_id,
        stitched.rail_original_id,
    )
    _require(
        bool(halo_leakage["passed"]),
        "stitched pair halo leakage is not page-only cap-to-rail",
    )
    mature_publication, edit_graft = _graft_exact_edit_publication_objects(
        young_publication,
        direct_mature_publication,
        edit_cells,
        publication_prestate.edit_manifests["young"],
        publication_prestate.edit_manifests["mature"],
        publication_prestate.edit_comparison,
        stitched.rail_original_id,
    )
    ungrafted_page_ids = frozenset(
        str(value) for value in halo_leakage["classified_differing_page_ids"]
    )
    grafted_page_ids = {
        str(row["page_id"])
        for row in publication_prestate.edit_manifests["young"]["pages"]
    }
    _require(
        grafted_page_ids.isdisjoint(ungrafted_page_ids),
        "stitched pair edit graft captured an ungrafted differing page",
    )

    young_storage = exact.WorkpieceState(
        exact._split_to_chunks(publication_prestate.stroke_a.manifold),
        revision=0,
    )
    independent_mature_storage = exact.WorkpieceState(
        exact._split_to_chunks(stitched.manifold), revision=0
    )
    pre_b_organic_ids = frozenset(
        (stitched.a_original_id, stitched.rail_original_id)
    )
    mature_storage, fragment_reuse = _reuse_verified_b_local_fragments(
        young_storage,
        independent_mature_storage,
        selected_space,
        pre_b_organic_ids,
    )
    young_fragment_manifest = _semantic_fragment_manifest(
        young_storage, selected_space
    )
    mature_fragment_manifest = _semantic_fragment_manifest(
        mature_storage, selected_space
    )
    _require(
        young_fragment_manifest == mature_fragment_manifest
        and int(fragment_reuse["selected_coordinate_count"])
        == int(fragment_reuse["reused_identical_object_count"]),
        "stitched pair selected storage fragments are not exact shared objects",
    )
    young_perimeter = exact._perimeter_cap_signature(
        young_storage.fragments, set(selected_space), set(pre_b_organic_ids)
    )
    mature_perimeter = exact._perimeter_cap_signature(
        mature_storage.fragments, set(selected_space), set(pre_b_organic_ids)
    )
    _require(
        young_perimeter == mature_perimeter,
        "stitched pair local compiler-cap perimeter differs",
    )

    rail_atoms = sorted(
        (
            atom
            for atom in mature_publication.atoms.values()
            if int(atom.source_id) == stitched.rail_original_id
        ),
        key=lambda atom: atom.lineage_id,
    )
    rail_page_ids = {
        mature_publication.atom_to_page[atom.lineage_id] for atom in rail_atoms
    }
    remote_rail_pages = sorted(
        (
            mature_publication.pages[page_id]
            for page_id in rail_page_ids
            if set(mature_publication.pages[page_id].overlap_cells).isdisjoint(
                selected_space
            )
        ),
        key=lambda page: page.page_id,
    )
    remote_atom_manifest = [
        (
            atom.lineage_id,
            atom.version_id,
            atom.payload_sha256,
            mature_publication.atom_to_page[atom.lineage_id],
        )
        for atom in rail_atoms
    ]
    remote_page_manifest = [
        (page.page_id, page.payload_sha256, page.atom_ids)
        for page in remote_rail_pages
    ]
    current_signature = {
        "fixture_sha256": publication_prestate.fixture_sha256,
        "shared_source_ids": {
            "young_a": publication_prestate.stroke_a.original_id,
            "young_b": publication_prestate.stroke_b.original_id,
            "stitched_a": stitched.a_original_id,
            "stitched_rail": stitched.rail_original_id,
        },
        "mature_bootstrap_record_sha256": atlas._records_digest(
            publication_prestate.mature_bootstrap_records
        ),
        "stitched_authority_record_sha256": atlas._records_digest(
            stitched.records
        ),
        "mature_bootstrap_record_count": len(
            publication_prestate.mature_bootstrap_records
        ),
        "young_selected_fragments": young_fragment_manifest,
        "mature_selected_fragments": mature_fragment_manifest,
        "young_halo_semantic_sha256": publication_prestate.halo_manifests[
            "young"
        ]["semantic_sha256"],
        "mature_halo_semantic_sha256": publication_prestate.halo_manifests[
            "mature"
        ]["semantic_sha256"],
        "young_edit_semantic_sha256": publication_prestate.edit_manifests[
            "young"
        ]["semantic_sha256"],
        "mature_edit_semantic_sha256": publication_prestate.edit_manifests[
            "mature"
        ]["semantic_sha256"],
        "ungrafted_differing_page_ids": sorted(ungrafted_page_ids),
        "young_atom_count": len(young_publication.atoms),
        "young_page_count": len(young_publication.pages),
        "mature_atom_count": len(mature_publication.atoms),
        "mature_page_count": len(mature_publication.pages),
        "remote_rail_atom_count": len(rail_atoms),
        "remote_rail_page_count": len(rail_page_ids),
        "remote_rail_atom_manifest_sha256": _sha256_json(
            remote_atom_manifest
        ),
        "remote_rail_page_manifest_sha256": _sha256_json(
            remote_page_manifest
        ),
    }
    accepted_signature = _accepted_stitched_prestate_signature(accepted)
    _require(
        current_signature == accepted_signature,
        "lightweight stitched pair prestate differs from accepted prestate artifact",
    )
    organic_ids = frozenset(
        (
            stitched.a_original_id,
            stitched.b_original_id,
            stitched.rail_original_id,
        )
    )
    source_face_counts = {
        stitched.a_original_id: 1446,
        stitched.b_original_id: int(publication_prestate.stroke_b.triangle_count),
        stitched.rail_original_id: 8669,
    }
    source_tags = {
        stitched.a_original_id: "stroke_a",
        stitched.b_original_id: "stroke_b",
        stitched.rail_original_id: "stitched_rail",
    }
    diagnostics = {
        "accepted_prestate_artifact": {
            "path": str(OUTPUT_STITCHED_PRESTATE_VALIDATION_JSON),
            "sha256": artifact_sha256,
            "signature": accepted_signature,
            "current_signature": current_signature,
            "deterministic_signature_equal": True,
        },
        "construction": {
            "lightweight_mode": True,
            "global_prestate_publication_authority_audit_count": 0,
            "global_prestate_storage_authority_audit_count": 0,
            "mature_setup_boolean_count": 0,
            "local_fragment_geometry_and_cap_equivalence": fragment_reuse,
            "selected_fragment_manifest": young_fragment_manifest,
            "local_perimeter_signature_equal": True,
            "edit_publication_object_graft": edit_graft,
            "halo_page_leakage": halo_leakage,
            "ungrafted_differing_page_ids": sorted(ungrafted_page_ids),
        },
    }
    return StitchedPairInputs(
        stitched=stitched,
        stroke_a=publication_prestate.stroke_a,
        stroke_b=publication_prestate.stroke_b,
        young_storage=young_storage,
        mature_storage=mature_storage,
        young_publication=young_publication,
        mature_publication=mature_publication,
        selected_space=selected_space,
        edit_cells=edit_cells,
        organic_ids=organic_ids,
        property_lookup=stitched.property_lookup,
        source_face_counts=source_face_counts,
        source_tags=source_tags,
        ungrafted_differing_page_ids=ungrafted_page_ids,
        accepted_prestate_sha256=artifact_sha256,
        diagnostics=diagnostics,
    )


def _storage_path_through_split_back(
    storage: exact.WorkpieceState,
    operand: Any,
    selected_space: frozenset[Coordinate],
    organic_ids: frozenset[int],
) -> tuple[
    dict[Coordinate, exact.Fragment],
    Any,
    Mapping[str, Any],
    Any,
    dict[Coordinate, exact.Fragment],
]:
    """Execute only select, capped assembly, one Boolean, and split-back."""
    selected = {
        coordinate: storage.fragments[coordinate]
        for coordinate in sorted(selected_space)
        if coordinate in storage.fragments
    }
    _require(bool(selected), "fragment diagnostic selected no storage")
    assembled, assembly = exact._assemble_region_from_fragments(
        selected, set(organic_ids)
    )
    _require(
        exact._is_ok(assembled) and not assembled.is_empty(),
        "fragment diagnostic assembly failed",
    )
    region_result = assembled + operand
    _require(
        exact._is_ok(region_result)
        and not region_result.is_empty()
        and len(region_result.decompose()) == 1,
        "fragment diagnostic local Boolean failed",
    )
    changed = exact._split_to_chunks(region_result)
    _require(
        set(changed) <= set(selected_space),
        "fragment diagnostic split-back escaped jurisdiction",
    )
    return selected, assembled, assembly, region_result, changed


def _fragment_cap_provenance(
    fragment: exact.Fragment,
    organic_ids: frozenset[int],
) -> dict[str, Any]:
    vertices, triangles, source_ids, face_ids = exact._triangle_records(
        fragment.manifold
    )
    cap_indices = [
        index
        for index, source_id in enumerate(source_ids)
        if int(source_id) not in organic_ids
    ]
    organic_records = atlas._sorted_records(
        (
            int(source_ids[index]),
            int(face_ids[index]),
            vertices[triangle].copy(),
        )
        for index, triangle in enumerate(triangles)
        if int(source_ids[index]) in organic_ids
    )
    cap_records = atlas._sorted_records(
        (
            int(source_ids[index]),
            int(face_ids[index]),
            vertices[triangles[index]].copy(),
        )
        for index in cap_indices
    )
    return {
        "triangle_count": len(triangles),
        "organic_triangle_count": len(organic_records),
        "cap_triangle_count": len(cap_records),
        "organic_records_sha256": atlas._records_digest(organic_records),
        "cap_geometry_sha256_ignoring_source_face": _sha256_json(
            sorted(
                exact._canonical_point(point)
                for _source_id, _face_id, points in cap_records
                for point in np.asarray(points, dtype=np.float64)
            )
        ),
        "raw_cap_source_ids": sorted(
            {int(source_ids[index]) for index in cap_indices}
        ),
        "raw_cap_face_ids": sorted(
            {int(face_ids[index]) for index in cap_indices}
        ),
    }


def _oriented_triangle_hex_key(points: Any) -> tuple[tuple[str, str, str], ...]:
    """Normalize cyclic start only; reversed winding is intentionally distinct."""
    raw = np.asarray(points, dtype=np.float64)
    _require(raw.shape == (3, 3), "triangle points must be 3x3")
    point_keys = [
        tuple(float(value).hex() for value in point) for point in raw
    ]
    return min(
        tuple(point_keys[offset:] + point_keys[:offset]) for offset in range(3)
    )


def _bit_exact_fragment_triangle_manifest(
    fragment: exact.Fragment,
    organic_ids: frozenset[int],
) -> dict[str, Any]:
    vertices, triangles, source_ids, face_ids = exact._triangle_records(
        fragment.manifold
    )
    all_oriented: list[Any] = []
    organic_labelled: list[Any] = []
    cap_oriented: list[Any] = []
    raw_cap_label_mapping: list[Any] = []
    for index, triangle in enumerate(triangles):
        oriented = _oriented_triangle_hex_key(vertices[triangle])
        all_oriented.append(oriented)
        source_id = int(source_ids[index])
        face_id = int(face_ids[index])
        if source_id in organic_ids:
            organic_labelled.append((source_id, face_id, oriented))
        else:
            cap_oriented.append(oriented)
            raw_cap_label_mapping.append((oriented, source_id, face_id))
    all_oriented.sort()
    organic_labelled.sort()
    cap_oriented.sort()
    raw_cap_label_mapping.sort()
    return {
        "triangle_count": len(all_oriented),
        "organic_triangle_count": len(organic_labelled),
        "compiler_cap_triangle_count": len(cap_oriented),
        "all_oriented_triangle_multiset": all_oriented,
        "all_oriented_triangle_multiset_sha256": _sha256_json(all_oriented),
        "organic_source_face_oriented_triangle_multiset": organic_labelled,
        "organic_source_face_oriented_triangle_multiset_sha256": _sha256_json(
            organic_labelled
        ),
        "compiler_cap_oriented_triangle_multiset": cap_oriented,
        "compiler_cap_oriented_triangle_multiset_sha256": _sha256_json(
            cap_oriented
        ),
        "raw_compiler_cap_label_mapping": raw_cap_label_mapping,
        "raw_compiler_cap_label_mapping_sha256": _sha256_json(
            raw_cap_label_mapping
        ),
        "raw_compiler_cap_source_ids": sorted(
            {int(value[1]) for value in raw_cap_label_mapping}
        ),
        "raw_compiler_cap_face_ids": sorted(
            {int(value[2]) for value in raw_cap_label_mapping}
        ),
        "orientation_law": (
            "float.hex vertices; cyclic start normalized; reverse winding never normalized"
        ),
    }


def _diagnose_stitched_pair_fragments_storage_only_reference() -> dict[str, Any]:
    """Diagnose paired split-back identity without entering publication work."""
    started = time.perf_counter_ns()
    script_path = Path(__file__).resolve()
    script_sha256 = hashlib.sha256(script_path.read_bytes()).hexdigest()
    pair = _build_stitched_pair_inputs()
    (
        young_selected,
        _young_assembled,
        young_assembly,
        young_region,
        young_changed,
    ) = _storage_path_through_split_back(
        pair.young_storage,
        pair.stroke_b.manifold,
        pair.selected_space,
        pair.organic_ids,
    )
    (
        mature_selected,
        _mature_assembled,
        mature_assembly,
        mature_region,
        mature_changed,
    ) = _storage_path_through_split_back(
        pair.mature_storage,
        pair.stroke_b.manifold,
        pair.selected_space,
        pair.organic_ids,
    )
    selected_coordinates_equal = set(young_selected) == set(mature_selected)
    pre_rows: list[dict[str, Any]] = []
    for coordinate in sorted(set(young_selected) | set(mature_selected)):
        young_fragment = young_selected.get(coordinate)
        mature_fragment = mature_selected.get(coordinate)
        pre_rows.append(
            {
                "coordinate": list(coordinate),
                "young_object_id": (
                    None if young_fragment is None else id(young_fragment)
                ),
                "mature_object_id": (
                    None if mature_fragment is None else id(mature_fragment)
                ),
                "same_object": young_fragment is mature_fragment,
                "young_raw_digest": (
                    None if young_fragment is None else young_fragment.digest
                ),
                "mature_raw_digest": (
                    None if mature_fragment is None else mature_fragment.digest
                ),
                "young_semantic_digest": (
                    None
                    if young_fragment is None
                    else exact._semantic_mesh_digest(
                        young_fragment.manifold, set(pair.organic_ids)
                    )
                ),
                "mature_semantic_digest": (
                    None
                    if mature_fragment is None
                    else exact._semantic_mesh_digest(
                        mature_fragment.manifold, set(pair.organic_ids)
                    )
                ),
            }
        )
    young_unsplit_records = _records_from_solid(young_region)
    mature_unsplit_records = _records_from_solid(mature_region)
    young_unsplit_sha256 = atlas._records_digest(young_unsplit_records)
    mature_unsplit_sha256 = atlas._records_digest(mature_unsplit_records)
    changed_coordinates_equal = set(young_changed) == set(mature_changed)
    post_rows: list[dict[str, Any]] = []
    raw_differing_coordinates: list[list[int]] = []
    semantic_equal = True
    organic_equal = True
    cap_geometry_equal = True
    solid_equivalent = True
    topology_equal_and_closed = True
    for coordinate in sorted(set(young_changed) | set(mature_changed)):
        young_fragment = young_changed.get(coordinate)
        mature_fragment = mature_changed.get(coordinate)
        if young_fragment is None or mature_fragment is None:
            semantic_equal = False
            organic_equal = False
            cap_geometry_equal = False
            solid_equivalent = False
            topology_equal_and_closed = False
            post_rows.append(
                {
                    "coordinate": list(coordinate),
                    "young_present": young_fragment is not None,
                    "mature_present": mature_fragment is not None,
                }
            )
            continue
        young_raw = young_fragment.digest
        mature_raw = mature_fragment.digest
        if young_raw != mature_raw:
            raw_differing_coordinates.append(list(coordinate))
        young_semantic = exact._semantic_mesh_digest(
            young_fragment.manifold, set(pair.organic_ids)
        )
        mature_semantic = exact._semantic_mesh_digest(
            mature_fragment.manifold, set(pair.organic_ids)
        )
        young_provenance = _fragment_cap_provenance(
            young_fragment, pair.organic_ids
        )
        mature_provenance = _fragment_cap_provenance(
            mature_fragment, pair.organic_ids
        )
        young_cap_signature = exact._cap_geometry_signature(
            {coordinate: young_fragment}, set(pair.organic_ids)
        )
        mature_cap_signature = exact._cap_geometry_signature(
            {coordinate: mature_fragment}, set(pair.organic_ids)
        )
        comparison = exact._compare_solids(
            young_fragment.manifold, mature_fragment.manifold
        )
        comparison_passes = all(
            exact._comparison_gate_summary(comparison).values()
        )
        young_records = _records_from_solid(young_fragment.manifold)
        mature_records = _records_from_solid(mature_fragment.manifold)
        young_topology = {
            str(quantum): atlas._topology_for_records(young_records, quantum)
            for quantum in TOPOLOGY_QUANTA_METERS
        }
        mature_topology = {
            str(quantum): atlas._topology_for_records(mature_records, quantum)
            for quantum in TOPOLOGY_QUANTA_METERS
        }
        topology_passes = (
            young_topology == mature_topology
            and all(
                atlas._topology_passes(value) and int(value["genus"]) == 0
                for value in young_topology.values()
            )
        )
        semantic_matches = young_semantic == mature_semantic
        organic_matches = (
            young_provenance["organic_records_sha256"]
            == mature_provenance["organic_records_sha256"]
        )
        cap_matches = (
            young_provenance["cap_triangle_count"]
            == mature_provenance["cap_triangle_count"]
            and young_provenance["cap_geometry_sha256_ignoring_source_face"]
            == mature_provenance[
                "cap_geometry_sha256_ignoring_source_face"
            ]
            and young_cap_signature == mature_cap_signature
        )
        semantic_equal = semantic_equal and semantic_matches
        organic_equal = organic_equal and organic_matches
        cap_geometry_equal = cap_geometry_equal and cap_matches
        solid_equivalent = solid_equivalent and comparison_passes
        topology_equal_and_closed = (
            topology_equal_and_closed and topology_passes
        )
        post_rows.append(
            {
                "coordinate": list(coordinate),
                "young_raw_digest": young_raw,
                "mature_raw_digest": mature_raw,
                "raw_digest_equal": young_raw == mature_raw,
                "young_semantic_digest": young_semantic,
                "mature_semantic_digest": mature_semantic,
                "semantic_digest_equal": semantic_matches,
                "young_organic_and_cap_provenance": young_provenance,
                "mature_organic_and_cap_provenance": mature_provenance,
                "organic_records_equal": organic_matches,
                "young_cap_geometry_orientation_signature": young_cap_signature,
                "mature_cap_geometry_orientation_signature": mature_cap_signature,
                "cap_geometry_orientation_and_count_equal": cap_matches,
                "solid_comparison": comparison,
                "solid_comparison_passes": comparison_passes,
                "young_summary": exact._solid_summary(
                    young_fragment.manifold
                ),
                "mature_summary": exact._solid_summary(
                    mature_fragment.manifold
                ),
                "young_topology": young_topology,
                "mature_topology": mature_topology,
                "topology_equal_closed_genus_zero": topology_passes,
            }
        )
    pre_exact = (
        selected_coordinates_equal
        and bool(pre_rows)
        and all(
            bool(row["same_object"])
            and row["young_raw_digest"] == row["mature_raw_digest"]
            and row["young_semantic_digest"] == row["mature_semantic_digest"]
            for row in pre_rows
        )
    )
    raw_differs = bool(raw_differing_coordinates)
    diagnostic_conclusion = (
        pre_exact
        and changed_coordinates_equal
        and young_unsplit_sha256 == mature_unsplit_sha256
        and raw_differs
        and semantic_equal
        and organic_equal
        and cap_geometry_equal
        and solid_equivalent
        and topology_equal_and_closed
    )
    return {
        "schema": "forge_v2_stitched_pair_fragment_diagnostic",
        "schema_version": 1,
        "outcome": "diagnostic_complete",
        "diagnostic_only": True,
        "proof_passed": False,
        "production_ready": False,
        "production_files_touched": False,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_stitched_pair_storage_through_split_back",
        "script": {"path": str(script_path), "sha256": script_sha256},
        "fixture_sha256": pair.stitched.diagnostics["fixture_sha256"],
        "accepted_prestate_artifact_sha256": pair.accepted_prestate_sha256,
        "execution_scope": {
            "young_storage_path_count": 1,
            "mature_storage_path_count": 1,
            "per_path_phases": [
                "select",
                "assemble_capped_fragments",
                "single_local_boolean",
                "split_back",
            ],
            "zero_move_count": 0,
            "publication_transaction_count": 0,
            "paired_validation_mode_count": 0,
        },
        "coordinates": {
            "selected_space": [
                list(value) for value in sorted(pair.selected_space)
            ],
            "young_selected_populated": [
                list(value) for value in sorted(young_selected)
            ],
            "mature_selected_populated": [
                list(value) for value in sorted(mature_selected)
            ],
            "selected_coordinate_sets_equal": selected_coordinates_equal,
            "young_changed": [list(value) for value in sorted(young_changed)],
            "mature_changed": [
                list(value) for value in sorted(mature_changed)
            ],
            "changed_coordinate_sets_equal": changed_coordinates_equal,
        },
        "pre_selected_fragments": pre_rows,
        "pre_selected_objects_raw_and_semantic_identical": pre_exact,
        "young_assembly": young_assembly,
        "mature_assembly": mature_assembly,
        "unsplit": {
            "young_triangle_count": len(young_unsplit_records),
            "mature_triangle_count": len(mature_unsplit_records),
            "young_canonical_records_sha256": young_unsplit_sha256,
            "mature_canonical_records_sha256": mature_unsplit_sha256,
            "canonical_records_equal": (
                young_unsplit_sha256 == mature_unsplit_sha256
            ),
            "solid_comparison": exact._compare_solids(
                young_region, mature_region
            ),
        },
        "post_split_fragments": post_rows,
        "raw_digest_differing_coordinate_count": len(
            raw_differing_coordinates
        ),
        "raw_digest_differing_coordinates": raw_differing_coordinates,
        "semantic_digests_all_equal": semantic_equal,
        "organic_records_all_equal": organic_equal,
        "cap_geometry_orientation_and_counts_all_equal": cap_geometry_equal,
        "per_fragment_solids_all_equivalent": solid_equivalent,
        "per_fragment_topology_all_equal_closed_genus_zero": (
            topology_equal_and_closed
        ),
        "diagnostic_conclusion": {
            "raw_differs_while_semantic_organic_cap_geometry_equal": (
                diagnostic_conclusion
            ),
            "conclusion_true_only_if_raw_differs": raw_differs,
            "conclusion_law": (
                "true only when at least one raw Fragment.digest differs while "
                "every semantic digest, organic record hash, cap geometry/orientation/"
                "count, solid equivalence, and topology comparison remains exact"
            ),
        },
        "diagnostic_wall_ms": (time.perf_counter_ns() - started) / 1.0e6,
    }


def _diagnose_stitched_pair_fragments() -> dict[str, Any]:
    """Reproduce the sequential pair and diagnose split-back bit identity."""
    started = time.perf_counter_ns()
    script_path = Path(__file__).resolve()
    script_sha256 = hashlib.sha256(script_path.read_bytes()).hexdigest()
    pair = _build_stitched_pair_inputs()

    # Allocator-sensitive sequence: do not inspect either outcome or invoke any
    # other Manifold operation between these two complete transactions.
    young_edit = _incremental_add(
        pair.young_storage,
        pair.young_publication,
        pair.stroke_b.manifold,
        pair.organic_ids,
        pair.stroke_b.original_id,
        pair.property_lookup,
        pair.source_tags,
        "stitched_pair_young_b",
    )
    mature_edit = _incremental_add(
        pair.mature_storage,
        pair.mature_publication,
        pair.stroke_b.manifold,
        pair.organic_ids,
        pair.stroke_b.original_id,
        pair.property_lookup,
        pair.source_tags,
        "stitched_pair_mature_b",
    )

    selected_coordinates = sorted(pair.selected_space)
    young_selected = {
        coordinate: pair.young_storage.fragments[coordinate]
        for coordinate in selected_coordinates
        if coordinate in pair.young_storage.fragments
    }
    mature_selected = {
        coordinate: pair.mature_storage.fragments[coordinate]
        for coordinate in selected_coordinates
        if coordinate in pair.mature_storage.fragments
    }
    selected_coordinates_equal = set(young_selected) == set(mature_selected)
    pre_rows: list[dict[str, Any]] = []
    for coordinate in sorted(set(young_selected) | set(mature_selected)):
        young_fragment = young_selected.get(coordinate)
        mature_fragment = mature_selected.get(coordinate)
        pre_rows.append(
            {
                "coordinate": list(coordinate),
                "young_object_id": (
                    None if young_fragment is None else id(young_fragment)
                ),
                "mature_object_id": (
                    None if mature_fragment is None else id(mature_fragment)
                ),
                "same_object": young_fragment is mature_fragment,
                "young_raw_digest": (
                    None if young_fragment is None else young_fragment.digest
                ),
                "mature_raw_digest": (
                    None if mature_fragment is None else mature_fragment.digest
                ),
                "young_semantic_digest": (
                    None
                    if young_fragment is None
                    else exact._semantic_mesh_digest(
                        young_fragment.manifold, set(pair.organic_ids)
                    )
                ),
                "mature_semantic_digest": (
                    None
                    if mature_fragment is None
                    else exact._semantic_mesh_digest(
                        mature_fragment.manifold, set(pair.organic_ids)
                    )
                ),
            }
        )
    pre_exact = (
        selected_coordinates_equal
        and bool(pre_rows)
        and all(
            bool(row["same_object"])
            and row["young_raw_digest"] == row["mature_raw_digest"]
            and row["young_semantic_digest"] == row["mature_semantic_digest"]
            for row in pre_rows
        )
    )

    young_changed_coordinates = {
        coordinate
        for coordinate in set(pair.young_storage.fragments)
        | set(young_edit.storage.fragments)
        if pair.young_storage.fragments.get(coordinate)
        is not young_edit.storage.fragments.get(coordinate)
    }
    mature_changed_coordinates = {
        coordinate
        for coordinate in set(pair.mature_storage.fragments)
        | set(mature_edit.storage.fragments)
        if pair.mature_storage.fragments.get(coordinate)
        is not mature_edit.storage.fragments.get(coordinate)
    }
    changed_coordinates_equal = (
        young_changed_coordinates == mature_changed_coordinates
    )
    young_unsplit_records = tuple(young_edit.unsplit_region_records)
    mature_unsplit_records = tuple(mature_edit.unsplit_region_records)
    young_unsplit_sha256 = atlas._records_digest(young_unsplit_records)
    mature_unsplit_sha256 = atlas._records_digest(mature_unsplit_records)

    post_rows: list[dict[str, Any]] = []
    raw_digest_differences: list[list[int]] = []
    raw_cap_mapping_differences: list[list[int]] = []
    primary_all_geometry_equal = True
    primary_organic_labelled_equal = True
    primary_cap_geometry_winding_equal = True
    semantic_digest_equal = True
    cap_signature_equal = True
    tolerance_solid_equivalent = True
    topology_all_equal = True
    strict_fragment_topology_all_pass = True
    post_coordinates = sorted(
        young_changed_coordinates | mature_changed_coordinates
    )
    for coordinate in post_coordinates:
        young_fragment = young_edit.storage.fragments.get(coordinate)
        mature_fragment = mature_edit.storage.fragments.get(coordinate)
        if young_fragment is None or mature_fragment is None:
            primary_all_geometry_equal = False
            primary_organic_labelled_equal = False
            primary_cap_geometry_winding_equal = False
            semantic_digest_equal = False
            cap_signature_equal = False
            tolerance_solid_equivalent = False
            topology_all_equal = False
            strict_fragment_topology_all_pass = False
            post_rows.append(
                {
                    "coordinate": list(coordinate),
                    "young_present": young_fragment is not None,
                    "mature_present": mature_fragment is not None,
                }
            )
            continue
        young_bits = _bit_exact_fragment_triangle_manifest(
            young_fragment, pair.organic_ids
        )
        mature_bits = _bit_exact_fragment_triangle_manifest(
            mature_fragment, pair.organic_ids
        )
        all_geometry_equal = (
            young_bits["all_oriented_triangle_multiset"]
            == mature_bits["all_oriented_triangle_multiset"]
        )
        organic_labelled_equal = (
            young_bits["organic_source_face_oriented_triangle_multiset"]
            == mature_bits["organic_source_face_oriented_triangle_multiset"]
        )
        cap_geometry_winding_equal = (
            young_bits["compiler_cap_oriented_triangle_multiset"]
            == mature_bits["compiler_cap_oriented_triangle_multiset"]
        )
        raw_cap_mapping_equal = (
            young_bits["raw_compiler_cap_label_mapping"]
            == mature_bits["raw_compiler_cap_label_mapping"]
        )
        if not raw_cap_mapping_equal:
            raw_cap_mapping_differences.append(list(coordinate))
        raw_digest_equal = young_fragment.digest == mature_fragment.digest
        if not raw_digest_equal:
            raw_digest_differences.append(list(coordinate))
        young_semantic = exact._semantic_mesh_digest(
            young_fragment.manifold, set(pair.organic_ids)
        )
        mature_semantic = exact._semantic_mesh_digest(
            mature_fragment.manifold, set(pair.organic_ids)
        )
        semantic_equal = young_semantic == mature_semantic
        young_cap_signature = exact._cap_geometry_signature(
            {coordinate: young_fragment}, set(pair.organic_ids)
        )
        mature_cap_signature = exact._cap_geometry_signature(
            {coordinate: mature_fragment}, set(pair.organic_ids)
        )
        cap_signatures_match = young_cap_signature == mature_cap_signature
        comparison = exact._compare_solids(
            young_fragment.manifold, mature_fragment.manifold
        )
        comparison_passes = all(
            exact._comparison_gate_summary(comparison).values()
        )
        young_records = _records_from_solid(young_fragment.manifold)
        mature_records = _records_from_solid(mature_fragment.manifold)
        young_topology = {
            str(quantum): atlas._topology_for_records(young_records, quantum)
            for quantum in TOPOLOGY_QUANTA_METERS
        }
        mature_topology = {
            str(quantum): atlas._topology_for_records(mature_records, quantum)
            for quantum in TOPOLOGY_QUANTA_METERS
        }
        topology_equal = young_topology == mature_topology
        strict_fragment_topology_passes = all(
            atlas._topology_passes(value) and int(value["genus"]) == 0
            for value in young_topology.values()
        )
        primary_all_geometry_equal = (
            primary_all_geometry_equal and all_geometry_equal
        )
        primary_organic_labelled_equal = (
            primary_organic_labelled_equal and organic_labelled_equal
        )
        primary_cap_geometry_winding_equal = (
            primary_cap_geometry_winding_equal
            and cap_geometry_winding_equal
        )
        semantic_digest_equal = semantic_digest_equal and semantic_equal
        cap_signature_equal = cap_signature_equal and cap_signatures_match
        tolerance_solid_equivalent = (
            tolerance_solid_equivalent and comparison_passes
        )
        topology_all_equal = topology_all_equal and topology_equal
        strict_fragment_topology_all_pass = (
            strict_fragment_topology_all_pass
            and strict_fragment_topology_passes
        )
        post_rows.append(
            {
                "coordinate": list(coordinate),
                "young_raw_digest": young_fragment.digest,
                "mature_raw_digest": mature_fragment.digest,
                "raw_digest_equal": raw_digest_equal,
                "bit_exact_all_oriented_geometry_equal": all_geometry_equal,
                "bit_exact_organic_source_face_geometry_equal": (
                    organic_labelled_equal
                ),
                "bit_exact_cap_geometry_winding_multiplicity_equal": (
                    cap_geometry_winding_equal
                ),
                "raw_cap_label_mapping_equal": raw_cap_mapping_equal,
                "young_bit_exact_manifest": young_bits,
                "mature_bit_exact_manifest": mature_bits,
                "young_semantic_digest": young_semantic,
                "mature_semantic_digest": mature_semantic,
                "semantic_digest_equal": semantic_equal,
                "young_cap_geometry_orientation_signature": young_cap_signature,
                "mature_cap_geometry_orientation_signature": mature_cap_signature,
                "cap_signature_equal": cap_signatures_match,
                "tolerance_solid_comparison": comparison,
                "tolerance_solid_comparison_passes": comparison_passes,
                "young_solid_summary": exact._solid_summary(
                    young_fragment.manifold
                ),
                "mature_solid_summary": exact._solid_summary(
                    mature_fragment.manifold
                ),
                "young_topology": young_topology,
                "mature_topology": mature_topology,
                "topology_equal": topology_equal,
                "fragment_closed_one_component_genus_zero": (
                    strict_fragment_topology_passes
                ),
            }
        )

    raw_differs = bool(raw_digest_differences)
    raw_cap_labels_explain_raw_differences = (
        sorted(raw_digest_differences)
        == sorted(raw_cap_mapping_differences)
    )
    primary_bit_exact_pass = (
        changed_coordinates_equal
        and primary_all_geometry_equal
        and primary_organic_labelled_equal
        and primary_cap_geometry_winding_equal
    )
    diagnostic_conclusion = (
        pre_exact
        and young_unsplit_sha256 == mature_unsplit_sha256
        and raw_differs
        and primary_bit_exact_pass
        and raw_cap_labels_explain_raw_differences
        and semantic_digest_equal
        and cap_signature_equal
    )
    return {
        "schema": "forge_v2_stitched_pair_fragment_diagnostic",
        "schema_version": 2,
        "outcome": "diagnostic_complete",
        "diagnostic_only": True,
        "proof_passed": False,
        "production_ready": False,
        "production_files_touched": False,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_sequential_full_pair_fragment_diagnostic",
        "script": {"path": str(script_path), "sha256": script_sha256},
        "fixture_sha256": pair.stitched.diagnostics["fixture_sha256"],
        "accepted_prestate_artifact_sha256": pair.accepted_prestate_sha256,
        "execution_scope": {
            "sequence": [
                "full_young_incremental_add",
                "full_mature_incremental_add",
                "deferred_comparison_after_both_complete",
            ],
            "no_inspection_or_extra_manifold_call_between_transactions": True,
            "zero_move_count": 2,
            "publication_overlay_count": 2,
            "post_oracle_count": 0,
            "paired_validation_gate_count": 0,
        },
        "organic_ids": sorted(pair.organic_ids),
        "coordinates": {
            "selected_space": [list(value) for value in selected_coordinates],
            "young_selected_populated": [
                list(value) for value in sorted(young_selected)
            ],
            "mature_selected_populated": [
                list(value) for value in sorted(mature_selected)
            ],
            "selected_coordinate_sets_equal": selected_coordinates_equal,
            "young_changed": [
                list(value) for value in sorted(young_changed_coordinates)
            ],
            "mature_changed": [
                list(value) for value in sorted(mature_changed_coordinates)
            ],
            "changed_coordinate_sets_equal": changed_coordinates_equal,
        },
        "pre_selected_fragments": pre_rows,
        "pre_selected_objects_raw_and_semantic_identical": pre_exact,
        "transactions": {
            "young_phase_ms": young_edit.metrics["phase_ms"],
            "mature_phase_ms": mature_edit.metrics["phase_ms"],
            "young_changed_fragment_count": young_edit.metrics[
                "changed_storage_fragment_count"
            ],
            "mature_changed_fragment_count": mature_edit.metrics[
                "changed_storage_fragment_count"
            ],
            "young_unsplit_triangle_count": young_edit.metrics[
                "unsplit_region_triangle_count"
            ],
            "mature_unsplit_triangle_count": mature_edit.metrics[
                "unsplit_region_triangle_count"
            ],
        },
        "unsplit": {
            "young_canonical_records_sha256": young_unsplit_sha256,
            "mature_canonical_records_sha256": mature_unsplit_sha256,
            "canonical_records_equal": (
                young_unsplit_sha256 == mature_unsplit_sha256
            ),
        },
        "post_split_fragments": post_rows,
        "primary_bit_exact_comparison": {
            "passed": primary_bit_exact_pass,
            "float_encoding": "float.hex",
            "cyclic_start_normalized": True,
            "reverse_winding_normalized": False,
            "all_oriented_triangle_multisets_equal": (
                primary_all_geometry_equal
            ),
            "organic_source_face_oriented_multisets_equal": (
                primary_organic_labelled_equal
            ),
            "compiler_cap_geometry_winding_multiplicity_equal": (
                primary_cap_geometry_winding_equal
            ),
        },
        "raw_digest_differing_coordinates": raw_digest_differences,
        "raw_cap_label_mapping_differing_coordinates": (
            raw_cap_mapping_differences
        ),
        "raw_cap_label_differences_exactly_explain_raw_digest_differences": (
            raw_cap_labels_explain_raw_differences
        ),
        "corroboration": {
            "semantic_digests_all_equal": semantic_digest_equal,
            "cap_geometry_orientation_signatures_all_equal": (
                cap_signature_equal
            ),
            "tolerance_solid_comparisons_all_pass": (
                tolerance_solid_equivalent
            ),
            "topology_records_all_equal": topology_all_equal,
            "every_fragment_closed_one_component_genus_zero": (
                strict_fragment_topology_all_pass
            ),
            "semantic_and_tolerance_helpers_are_not_primary": True,
        },
        "diagnostic_conclusion": {
            "raw_digest_difference_is_only_raw_compiler_cap_labels": (
                diagnostic_conclusion
            ),
            "conclusion_law": (
                "true only if prestate objects and unsplit records are exact, at "
                "least one raw digest differs, all bit-exact oriented geometry and "
                "organic provenance match, all cap geometry/winding/multiplicity "
                "matches, and the raw cap-label difference coordinates exactly equal "
                "the raw digest difference coordinates"
            ),
        },
        "diagnostic_wall_ms": (time.perf_counter_ns() - started) / 1.0e6,
    }


def _post_publication_topology_quality_audit(
    publication: PublicationState,
    property_lookup: Mapping[tuple[int, int], tuple[int, int]],
    source_face_counts: Mapping[int, int],
    source_tags: Mapping[int, str],
    expected_sources: frozenset[int],
) -> dict[str, Any]:
    """Audit actual emitted arrays without constructing a monolithic oracle."""
    records, pages, roundtrip = _roundtrip_publication_state(
        publication, property_lookup
    )
    quality = atlas._quality_summary(records)
    topology = {
        str(quantum): atlas._topology_for_records(records, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    _solid, mesh64 = atlas._make_publication_solid(records)
    provenance = atlas._provenance_summary(records, source_face_counts)
    source_material_lineage = _source_material_lineage_audit(
        records,
        property_lookup,
        source_tags,
        expected_sources,
    )
    passed = (
        int(quality["double_subthreshold_triangle_count"]) == 0
        and int(quality["float32_subthreshold_triangle_count"]) == 0
        and all(
            atlas._topology_passes(value) and int(value["genus"]) == 0
            for value in topology.values()
        )
        and mesh64["status"] == "NoError"
        and int(mesh64["component_count"]) == 1
        and mesh64["component_genera"] == [0]
        and bool(roundtrip["page_exact_array_hashes_verified"])
        and bool(roundtrip["atom_exact_array_hashes_verified"])
        and bool(roundtrip["combined_geometry_matches_pre_emission"])
        and bool(roundtrip["stable_lineage_ids_verified"])
        and bool(roundtrip["content_addressed_version_ids_verified"])
        and bool(provenance["passed"])
        and int(provenance["compiler_cap_triangle_count"]) == 0
        and bool(source_material_lineage["passed"])
    )
    return {
        "passed": passed,
        "triangle_count": len(records),
        "page_count": len(pages),
        "combined_geometry_sha256": atlas._records_digest(records),
        "quality": quality,
        "topology": topology,
        "mesh64": mesh64,
        "page_roundtrip": roundtrip,
        "provenance": provenance,
        "source_material_lineage": source_material_lineage,
        "monolithic_authority_constructed_or_compared": False,
    }


def _guard_instrumentation_clean(metrics: Mapping[str, Any]) -> bool:
    counters = metrics["access_counters"]
    return bool(metrics["no_global_fragment_atom_page_scan"]) and all(
        int(counters[name]) == 0
        for name in (
            "global_fragment_iterations",
            "global_atom_iterations",
            "global_page_iterations",
            "forbidden_fragment_items_calls",
            "forbidden_fragment_values_calls",
            "forbidden_atom_items_calls",
            "forbidden_atom_values_calls",
            "forbidden_page_items_calls",
            "forbidden_page_values_calls",
        )
    )


def _validate_stitched_pair_transaction() -> dict[str, Any]:
    """Run one identical traced B edit on accepted young/stitched prestates."""
    started = time.perf_counter_ns()
    script_path = Path(__file__).resolve()
    script_sha256 = hashlib.sha256(script_path.read_bytes()).hexdigest()
    pair = _build_stitched_pair_inputs()
    _require(
        bool(pair.ungrafted_differing_page_ids),
        "stitched pair has no classified ungrafted page sentinel set",
    )
    young_pre_fragments = _semantic_fragment_manifest(
        pair.young_storage, pair.selected_space
    )
    mature_pre_fragments = _semantic_fragment_manifest(
        pair.mature_storage, pair.selected_space
    )
    young_pre_atoms = _indexed_atom_manifest(
        pair.young_publication, pair.edit_cells
    )
    mature_pre_atoms = _indexed_atom_manifest(
        pair.mature_publication, pair.edit_cells
    )
    _require(
        young_pre_fragments == mature_pre_fragments
        and young_pre_atoms == mature_pre_atoms,
        "stitched paired B local prestates differ before transaction",
    )
    young_before_perimeter = exact._perimeter_cap_signature(
        pair.young_storage.fragments,
        set(pair.selected_space),
        set(pair.organic_ids),
    )
    mature_before_perimeter = exact._perimeter_cap_signature(
        pair.mature_storage.fragments,
        set(pair.selected_space),
        set(pair.organic_ids),
    )
    _require(
        young_before_perimeter == mature_before_perimeter,
        "stitched paired B local perimeter differs before transaction",
    )

    young_edit = _incremental_add(
        pair.young_storage,
        pair.young_publication,
        pair.stroke_b.manifold,
        pair.organic_ids,
        pair.stroke_b.original_id,
        pair.property_lookup,
        pair.source_tags,
        "stitched_pair_young_b",
    )
    mature_edit = _incremental_add(
        pair.mature_storage,
        pair.mature_publication,
        pair.stroke_b.manifold,
        pair.organic_ids,
        pair.stroke_b.original_id,
        pair.property_lookup,
        pair.source_tags,
        "stitched_pair_mature_b",
    )
    oracle_started = time.perf_counter_ns()
    accepted_fragment_diagnostic = (
        _accepted_pair_fragment_diagnostic_binding()
    )
    young_raw_changed_fragments = _changed_fragment_manifest(
        pair.young_storage, young_edit.storage
    )
    mature_raw_changed_fragments = _changed_fragment_manifest(
        pair.mature_storage, mature_edit.storage
    )
    young_raw_by_coordinate = {
        tuple(int(value) for value in row["coordinate"]): row
        for row in young_raw_changed_fragments
    }
    mature_raw_by_coordinate = {
        tuple(int(value) for value in row["coordinate"]): row
        for row in mature_raw_changed_fragments
    }
    raw_coordinate_sets_equal = (
        set(young_raw_by_coordinate) == set(mature_raw_by_coordinate)
    )
    raw_before_digest_differences = sorted(
        coordinate
        for coordinate in set(young_raw_by_coordinate)
        & set(mature_raw_by_coordinate)
        if young_raw_by_coordinate[coordinate]["before_sha256"]
        != mature_raw_by_coordinate[coordinate]["before_sha256"]
    )
    raw_after_digest_differences = sorted(
        coordinate
        for coordinate in set(young_raw_by_coordinate)
        & set(mature_raw_by_coordinate)
        if young_raw_by_coordinate[coordinate]["after_sha256"]
        != mature_raw_by_coordinate[coordinate]["after_sha256"]
    )
    accepted_raw_difference_coordinates = sorted(
        tuple(int(value) for value in coordinate)
        for coordinate in accepted_fragment_diagnostic[
            "raw_digest_differing_coordinates"
        ]
    )
    young_work = _paired_non_time_work_signature(
        pair.young_storage, young_edit, pair.organic_ids
    )
    mature_work = _paired_non_time_work_signature(
        pair.mature_storage, mature_edit, pair.organic_ids
    )
    young_trace = young_edit.metrics["access_trace"]
    mature_trace = mature_edit.metrics["access_trace"]
    young_trace_audit = _traced_page_and_rail_read_audit(
        young_trace,
        pair.young_publication,
        young_edit.rebuilt_page_ids,
        pair.stitched.rail_original_id,
        pair.ungrafted_differing_page_ids,
    )
    mature_trace_audit = _traced_page_and_rail_read_audit(
        mature_trace,
        pair.mature_publication,
        mature_edit.rebuilt_page_ids,
        pair.stitched.rail_original_id,
        pair.ungrafted_differing_page_ids,
    )
    young_post = _post_publication_topology_quality_audit(
        young_edit.publication,
        pair.property_lookup,
        pair.source_face_counts,
        pair.source_tags,
        frozenset(
            (pair.stitched.a_original_id, pair.stitched.b_original_id)
        ),
    )
    mature_post = _post_publication_topology_quality_audit(
        mature_edit.publication,
        pair.property_lookup,
        pair.source_face_counts,
        pair.source_tags,
        pair.organic_ids,
    )
    young_post_caps = exact._paired_cap_analysis(
        young_edit.storage.fragments, set(pair.organic_ids)
    )
    mature_post_caps = exact._paired_cap_analysis(
        mature_edit.storage.fragments, set(pair.organic_ids)
    )
    young_after_perimeter = exact._perimeter_cap_signature(
        young_edit.storage.fragments,
        set(pair.selected_space),
        set(pair.organic_ids),
    )
    mature_after_perimeter = exact._perimeter_cap_signature(
        mature_edit.storage.fragments,
        set(pair.selected_space),
        set(pair.organic_ids),
    )
    remote_rail = _symmetric_remote_rail_identity_audit(
        pair.mature_storage,
        mature_edit.storage,
        pair.mature_publication,
        mature_edit.publication,
        pair.selected_space,
        pair.stitched.rail_original_id,
        mature_edit,
    )
    young_replacement = _replacement_atom_manifest(young_edit)
    mature_replacement = _replacement_atom_manifest(mature_edit)
    young_pages = _rebuilt_page_manifest(young_edit)
    mature_pages = _rebuilt_page_manifest(mature_edit)
    young_retained = _retained_local_atom_manifest(
        pair.young_publication,
        young_edit.publication,
        young_edit.removed_atom_ids,
        pair.edit_cells,
    )
    mature_retained = _retained_local_atom_manifest(
        pair.mature_publication,
        mature_edit.publication,
        mature_edit.removed_atom_ids,
        pair.edit_cells,
    )
    young_closure = young_edit.metrics["replacement_interface_closure"]
    mature_closure = mature_edit.metrics["replacement_interface_closure"]
    young_overlay = young_edit.metrics["overlay"]
    mature_overlay = mature_edit.metrics["overlay"]
    exact_work = young_work == mature_work
    hard_gates = {
        "accepted_prestate_artifact_and_deterministic_manifests_bound": bool(
            pair.diagnostics["accepted_prestate_artifact"][
                "deterministic_signature_equal"
            ]
        ),
        "accepted_fragment_allocator_diagnostic_is_sha_bound": (
            accepted_fragment_diagnostic["sha256"]
            == ACCEPTED_STITCHED_PAIR_FRAGMENT_DIAGNOSTIC_SHA256
            and bool(
                accepted_fragment_diagnostic[
                    "raw_differences_exactly_explained_by_cap_labels"
                ]
            )
            and bool(
                accepted_fragment_diagnostic[
                    "primary_bit_exact_comparison_passed"
                ]
            )
        ),
        "lightweight_setup_skipped_exhaustive_prestate_authority_audits": (
            int(
                pair.diagnostics["construction"][
                    "global_prestate_publication_authority_audit_count"
                ]
            )
            == 0
            and int(
                pair.diagnostics["construction"][
                    "global_prestate_storage_authority_audit_count"
                ]
            )
            == 0
        ),
        "full_two_ring_storage_fragments_are_exact_shared_objects": (
            young_pre_fragments == mature_pre_fragments
        ),
        "edit_cell_atoms_pages_and_indexes_are_exact_grafted_objects": (
            young_pre_atoms == mature_pre_atoms
            and bool(
                pair.diagnostics["construction"][
                    "edit_publication_object_graft"
                ]["post_graft_edit_semantics_equal"]
            )
        ),
        "paired_non_time_work_signatures_are_exact": exact_work,
        "semantic_and_bit_exact_changed_fragment_work_is_exact": (
            young_work["semantic_changed_fragment_work_manifest"]
            == mature_work["semantic_changed_fragment_work_manifest"]
        ),
        "raw_changed_fragment_coordinate_sets_are_exact": (
            raw_coordinate_sets_equal
            and len(young_raw_changed_fragments)
            == len(mature_raw_changed_fragments)
            == int(
                young_edit.metrics["changed_storage_fragment_count"]
            )
            == int(
                mature_edit.metrics["changed_storage_fragment_count"]
            )
        ),
        "access_counters_are_exact": (
            young_edit.metrics["access_counters"]
            == mature_edit.metrics["access_counters"]
        ),
        "ordered_canonical_access_traces_are_exact": (
            young_trace == mature_trace
        ),
        "young_trace_reaches_no_ungrafted_page_or_rail_geometry": bool(
            young_trace_audit["passed"]
        ),
        "mature_trace_reaches_no_ungrafted_page_or_rail_geometry": bool(
            mature_trace_audit["passed"]
        ),
        "both_accessed_or_rebuilt_page_intersections_are_empty": (
            not young_trace_audit["forbidden_reached_page_ids"]
            and not mature_trace_audit["forbidden_reached_page_ids"]
        ),
        "remote_triangle_claim_comes_from_trace_not_inert_counter": (
            bool(
                young_edit.metrics[
                    "remote_triangle_counter_is_inert_and_not_used_as_proof"
                ]
            )
            and bool(
                mature_edit.metrics[
                    "remote_triangle_counter_is_inert_and_not_used_as_proof"
                ]
            )
            and int(young_trace_audit["remote_triangle_read_count"]) == 0
            and int(mature_trace_audit["remote_triangle_read_count"]) == 0
        ),
        "both_guarded_transactions_have_no_forbidden_global_scan": (
            _guard_instrumentation_clean(young_edit.metrics)
            and _guard_instrumentation_clean(mature_edit.metrics)
        ),
        "selected_candidate_changed_fragment_work_is_exact": all(
            young_work[key] == mature_work[key]
            for key in (
                "candidate_coordinate_count",
                "selected_fragment_count",
                "changed_storage_fragment_count",
                "semantic_changed_fragment_work_manifest",
            )
        ),
        "unsplit_organic_cap_counts_and_local_geometry_are_exact": all(
            young_work[key] == mature_work[key]
            for key in (
                "unsplit_region_triangle_count",
                "unsplit_region_organic_triangle_count",
                "unsplit_region_storage_cap_triangle_count",
                "unsplit_region_geometry_sha256",
            )
        ),
        "zero_move_cleanup_selection_and_collapse_sequence_are_exact": all(
            young_work[key] == mature_work[key]
            for key in (
                "zero_move_retriangulation",
                "dirty_selection",
                "dirty_conditioner",
            )
        ),
        "closure_changed_labels_and_atom_manifests_are_exact": (
            young_closure == mature_closure
            and young_edit.metrics["changed_source_faces"]
            == mature_edit.metrics["changed_source_faces"]
            and young_edit.removed_atom_ids == mature_edit.removed_atom_ids
            and young_replacement == mature_replacement
            and young_retained == mature_retained
        ),
        "overlay_page_load_rebuild_remove_index_and_payload_work_is_exact": (
            young_overlay == mature_overlay
            and young_edit.rebuilt_page_ids == mature_edit.rebuilt_page_ids
            and young_pages == mature_pages
        ),
        "both_interface_closures_converge_without_perimeter_touch": (
            bool(young_closure["converged"])
            and bool(mature_closure["converged"])
            and bool(
                young_closure[
                    "every_interface_edge_has_two_opposite_incidences"
                ]
            )
            and bool(
                mature_closure[
                    "every_interface_edge_has_two_opposite_incidences"
                ]
            )
            and not bool(young_closure["jurisdiction_perimeter_touched"])
            and not bool(mature_closure["jurisdiction_perimeter_touched"])
            and int(young_closure["removed_atom_perimeter_touch_count"]) == 0
            and int(young_closure["replacement_atom_perimeter_touch_count"])
            == 0
            and int(mature_closure["removed_atom_perimeter_touch_count"])
            == 0
            and int(
                mature_closure["replacement_atom_perimeter_touch_count"]
            )
            == 0
        ),
        "young_actual_emitted_topology_quality_mesh64_lineage_pass": bool(
            young_post["passed"]
        ),
        "mature_actual_emitted_topology_quality_mesh64_lineage_pass": bool(
            mature_post["passed"]
        ),
        "storage_caps_and_local_perimeter_signatures_pass": (
            _caps_are_paired(young_post_caps)
            and _caps_are_paired(mature_post_caps)
            and young_before_perimeter == young_after_perimeter
            and mature_before_perimeter == mature_after_perimeter
            and young_after_perimeter == mature_after_perimeter
        ),
        "remote_rail_atom_page_fragment_identity_is_symmetric_nonempty": bool(
            remote_rail["passed"]
        ),
        "no_global_post_edit_monolithic_authority_audit": True,
        "production_files_untouched": True,
    }
    failed = [name for name, passed in hard_gates.items() if not passed]
    _require(
        not failed,
        "stitched paired transaction gates failed: " + ", ".join(failed),
    )
    oracle_ms = (time.perf_counter_ns() - oracle_started) / 1.0e6
    return {
        "schema": "forge_v2_stitched_pair_transaction_validation",
        "schema_version": 2,
        "outcome": "pass",
        "proof_passed": True,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_stitched_paired_transaction",
        "production_files_touched": False,
        "production_ready": False,
        "script": {"path": str(script_path), "sha256": script_sha256},
        "fixture_sha256": pair.stitched.diagnostics["fixture_sha256"],
        "accepted_prestate_artifact": {
            "path": str(OUTPUT_STITCHED_PRESTATE_VALIDATION_JSON),
            "sha256": pair.accepted_prestate_sha256,
        },
        "accepted_fragment_allocator_diagnostic": (
            accepted_fragment_diagnostic
        ),
        "prestate": pair.diagnostics,
        "paired_transactions": {
            "statistics_law": "one observation only; no p50/p95 claim",
            "timing_law": "instrumentation-inclusive; timing excluded from work equality",
            "young_transaction_ms": young_edit.metrics["phase_ms"][
                "instrumented_transaction_ms"
            ],
            "mature_transaction_ms": mature_edit.metrics["phase_ms"][
                "instrumented_transaction_ms"
            ],
            "young_phase_ms": young_edit.metrics["phase_ms"],
            "mature_phase_ms": mature_edit.metrics["phase_ms"],
            "young_non_time_work_signature": young_work,
            "mature_non_time_work_signature": mature_work,
            "raw_changed_fragment_diagnostic": {
                "comparison_role": (
                    "diagnostic evidence only; compiler-cap allocator source/face "
                    "IDs are intentionally excluded from work equality"
                ),
                "young_manifest": young_raw_changed_fragments,
                "mature_manifest": mature_raw_changed_fragments,
                "coordinate_sets_equal": raw_coordinate_sets_equal,
                "raw_manifests_equal": (
                    young_raw_changed_fragments
                    == mature_raw_changed_fragments
                ),
                "before_digest_differing_coordinates": [
                    list(coordinate)
                    for coordinate in raw_before_digest_differences
                ],
                "after_digest_differing_coordinates": [
                    list(coordinate)
                    for coordinate in raw_after_digest_differences
                ],
                "expected_after_digest_differing_coordinates": [
                    list(coordinate)
                    for coordinate in accepted_raw_difference_coordinates
                ],
                "actual_matches_historical_diagnostic": (
                    not raw_before_digest_differences
                    and raw_after_digest_differences
                    == accepted_raw_difference_coordinates
                ),
                "expected_difference_law": (
                    "the SHA-bound diagnostic proved these raw differences are "
                    "exactly compiler-cap allocator labels while bit-exact "
                    "geometry, winding, multiplicity, and organic provenance match"
                ),
                "raw_cap_allocator_ids_required_equal": False,
                "raw_digest_values_participate_in_hard_work_equality": False,
            },
            "young_trace_audit": young_trace_audit,
            "mature_trace_audit": mature_trace_audit,
            "young_replacement_atom_manifest": young_replacement,
            "mature_replacement_atom_manifest": mature_replacement,
            "young_rebuilt_page_manifest": young_pages,
            "mature_rebuilt_page_manifest": mature_pages,
            "young_retained_local_atom_manifest": young_retained,
            "mature_retained_local_atom_manifest": mature_retained,
        },
        "young_post_publication": young_post,
        "mature_post_publication": mature_post,
        "storage": {
            "young_post_caps": young_post_caps,
            "mature_post_caps": mature_post_caps,
            "young_perimeter_before": young_before_perimeter,
            "young_perimeter_after": young_after_perimeter,
            "mature_perimeter_before": mature_before_perimeter,
            "mature_perimeter_after": mature_after_perimeter,
            "remote_rail_identity": remote_rail,
        },
        "hard_gates": hard_gates,
        "post_transaction_oracle_ms": oracle_ms,
        "total_wall_ms": (time.perf_counter_ns() - started) / 1.0e6,
        "limitations": [
            "This is one traced paired transaction observation; no timing distribution is claimed.",
            "No global post-edit monolithic authority was constructed or compared.",
            "The stitched fixture and transaction remain tools-only; production and Godot are untouched.",
        ],
    }


def _run_young_optimized_regression() -> tuple[dict[str, Any], dict[str, Any]]:
    """Young-only regression mode; mature setup is structurally unreachable."""
    started = time.perf_counter_ns()
    baseline = _load_accepted_young_baseline()
    frozen = _prepare_frozen_inputs()
    source_tags = {
        frozen.stroke_a.original_id: "stroke_a",
        frozen.stroke_b.original_id: "stroke_b",
        frozen.extension.original_id: "mature_extension",
    }
    conditioned_a, conditioning = _condition_authority(
        frozen.stroke_a.manifold, frozen.property_lookup
    )
    initial_publication, initial_atlas = _build_publication_state(
        conditioned_a, frozen.property_lookup, revision=0
    )
    initial_caps = exact._paired_cap_analysis(
        frozen.young_storage.fragments, set(frozen.organic_ids)
    )
    before_perimeter = exact._perimeter_cap_signature(
        frozen.young_storage.fragments,
        set(frozen.selected_space),
        set(frozen.organic_ids),
    )
    _cleanup_heartbeat("young_optimized_transaction_start")
    edit = _incremental_add(
        frozen.young_storage,
        initial_publication,
        frozen.stroke_b.manifold,
        frozen.organic_ids,
        frozen.stroke_b.original_id,
        frozen.property_lookup,
        source_tags,
        "young_optimized_b",
    )
    _cleanup_heartbeat("young_optimized_transaction_complete")
    authority = frozen.stroke_a.manifold + frozen.stroke_b.manifold
    _require(
        exact._is_ok(authority)
        and not authority.is_empty()
        and len(authority.decompose()) == 1,
        "young optimized monolithic authority is invalid",
    )
    emitted, decoded_pages, _solid, publication_audit = (
        _publication_authority_audit(
            edit.publication,
            authority,
            frozen.property_lookup,
            frozen.source_face_counts,
            source_tags,
            frozenset(
                (frozen.stroke_a.original_id, frozen.stroke_b.original_id)
            ),
        )
    )
    reconstructed, storage_assembly = exact._assemble_region_from_fragments(
        edit.storage.fragments, set(frozen.organic_ids)
    )
    storage_comparison = exact._compare_solids(reconstructed, authority)
    post_caps = exact._paired_cap_analysis(
        edit.storage.fragments, set(frozen.organic_ids)
    )
    after_perimeter = exact._perimeter_cap_signature(
        edit.storage.fragments,
        set(frozen.selected_space),
        set(frozen.organic_ids),
    )
    closure = edit.metrics["replacement_interface_closure"]
    cleanup = edit.metrics["dirty_conditioner"]
    current_geometry_digest = atlas._records_digest(emitted)
    current_page_hashes = publication_audit["page_roundtrip"]["page_hashes"]
    current_closure = {
        key: closure[key]
        for key in (
            "iteration_count",
            "transitive_neighbor_expansion_count",
            "final_interface_edge_count",
            "every_interface_edge_has_two_opposite_incidences",
            "jurisdiction_perimeter_touched",
        )
    }
    current_cleanup_edge_digests = [
        row["edge_digest"] for row in cleanup["collapses"]
    ]
    counters = edit.metrics["access_counters"]
    forbidden_clean = all(
        int(counters[name]) == 0
        for name in (
            "global_fragment_iterations",
            "global_atom_iterations",
            "global_page_iterations",
            "forbidden_fragment_items_calls",
            "forbidden_fragment_values_calls",
            "forbidden_atom_items_calls",
            "forbidden_atom_values_calls",
            "forbidden_page_items_calls",
            "forbidden_page_values_calls",
        )
    )
    baseline_comparison = {
        "combined_geometry_sha256_equal": (
            current_geometry_digest == baseline["combined_geometry_sha256"]
        ),
        "page_hash_sequence_equal": current_page_hashes == baseline["page_hashes"],
        "closure_signature_equal": current_closure == baseline["closure"],
        "cleanup_edge_sequence_equal": (
            current_cleanup_edge_digests == baseline["cleanup_edge_digests"]
        ),
        "cleanup_changed_source_faces_equal": (
            cleanup["changed_source_faces"]
            == baseline["cleanup_changed_source_faces"]
        ),
        "cleanup_collapse_count_equal": (
            int(cleanup["collapse_count"])
            == int(baseline["cleanup_collapse_count"])
        ),
        "cleanup_maximum_displacement_equal": (
            float(cleanup["maximum_actual_cumulative_vertex_displacement_m"])
            == float(baseline["cleanup_maximum_displacement_m"])
        ),
        "topology_equal": publication_audit["topology"] == baseline["topology"],
        "publication_fidelity_equal": (
            publication_audit["comparison_to_authority"]
            == baseline["publication_comparison"]
        ),
    }
    hard_gates = {
        "mature_setup_structurally_bypassed": True,
        "optimized_publication_passes_all_existing_gates": bool(
            publication_audit["passed"]
        ),
        "optimized_storage_matches_monolithic": all(
            exact._comparison_gate_summary(storage_comparison).values()
        ),
        "optimized_storage_caps_paired": (
            _caps_are_paired(initial_caps) and _caps_are_paired(post_caps)
        ),
        "optimized_perimeter_signature_unchanged": (
            before_perimeter == after_perimeter
        ),
        "optimized_closure_perimeter_counts_zero": (
            not bool(closure["jurisdiction_perimeter_touched"])
            and int(closure["removed_atom_perimeter_touch_count"]) == 0
            and int(closure["replacement_atom_perimeter_touch_count"]) == 0
        ),
        "optimized_cleanup_keeps_two_full_topology_audits": (
            int(cleanup["full_topology_audit_count"]) == 2
            and not bool(cleanup["validation_reduction"])
        ),
        "guarded_path_has_zero_forbidden_scans": forbidden_clean,
        "accepted_young_geometry_and_behavior_exactly_reproduced": all(
            baseline_comparison.values()
        ),
    }
    failed = [name for name, passed in hard_gates.items() if not passed]
    _require(
        not failed,
        "optimized young regression gates failed: " + ", ".join(failed),
    )
    result = {
        "schema": "forge_v2_incremental_publication_atlas_young_optimized_regression",
        "schema_version": 1,
        "outcome": "pass",
        "proof_passed": True,
        "scope": "tools_only_young_optimized_regression_no_mature_setup",
        "production_files_touched": False,
        "production_ready": False,
        "baseline": baseline,
        "baseline_comparison": baseline_comparison,
        "setup": {
            "conditioning": conditioning,
            "initial_atlas": initial_atlas,
        },
        "transaction": edit.metrics,
        "publication_audit": publication_audit,
        "storage": {
            "comparison": storage_comparison,
            "assembly": storage_assembly,
            "caps": post_caps,
            "perimeter_signature_unchanged": before_perimeter == after_perimeter,
        },
        "hard_gates": hard_gates,
        "proof_total_ms": (time.perf_counter_ns() - started) / 1.0e6,
    }
    packets = {
        "schema": "forge_v2_incremental_publication_atlas_young_optimized_packets",
        "schema_version": 1,
        "outcome": "pass",
        "combined_geometry_sha256": current_geometry_digest,
        "page_count": len(decoded_pages),
        "triangle_count": len(emitted),
        "page_roundtrip": publication_audit["page_roundtrip"],
        "pages": decoded_pages,
    }
    return result, packets


def _run_proof() -> tuple[dict[str, Any], dict[str, Any]]:
    """Prove one identical B edit against valid young and mature atlases."""
    proof_started = time.perf_counter_ns()
    frozen = _prepare_frozen_inputs()
    source_tags = {
        frozen.stroke_a.original_id: "stroke_a",
        frozen.stroke_b.original_id: "stroke_b",
        frozen.extension.original_id: "mature_extension",
    }
    expected_young_sources = frozenset(
        (frozen.stroke_a.original_id, frozen.stroke_b.original_id)
    )

    conditioned_a, conditioning = _condition_authority(
        frozen.stroke_a.manifold, frozen.property_lookup
    )
    initial_publication, initial_atlas = _build_publication_state(
        conditioned_a, frozen.property_lookup, revision=0
    )
    initial_caps = exact._paired_cap_analysis(
        frozen.young_storage.fragments, set(frozen.organic_ids)
    )
    before_perimeter = exact._perimeter_cap_signature(
        frozen.young_storage.fragments,
        set(frozen.selected_space),
        set(frozen.organic_ids),
    )

    # Mature setup is an explicit untimed edit of frozen A, not a union of two
    # independently published overlapping surfaces.  Its time is reported
    # separately and never mixed into the paired B transaction comparison.
    extension_setup_started = time.perf_counter_ns()
    extension_edit = _incremental_add(
        frozen.young_storage,
        initial_publication,
        frozen.extension.manifold,
        frozen.organic_ids,
        frozen.extension.original_id,
        frozen.property_lookup,
        source_tags,
        "mature_extension_setup",
    )
    mature_storage, local_fragment_reuse = _reuse_verified_b_local_fragments(
        frozen.young_storage,
        extension_edit.storage,
        frozen.selected_space,
        frozen.organic_ids,
    )
    mature_publication = extension_edit.publication
    mature_pre_authority = frozen.stroke_a.manifold + frozen.extension.manifold
    _require(
        exact._is_ok(mature_pre_authority)
        and not mature_pre_authority.is_empty()
        and len(mature_pre_authority.decompose()) == 1,
        "mature A+extension setup authority is not one valid solid",
    )
    (
        mature_pre_records,
        mature_pre_pages,
        _mature_pre_publication_solid,
        mature_pre_publication_audit,
    ) = _publication_authority_audit(
        mature_publication,
        mature_pre_authority,
        frozen.property_lookup,
        frozen.source_face_counts,
        source_tags,
        frozenset(
            (frozen.stroke_a.original_id, frozen.extension.original_id)
        ),
    )
    mature_pre_storage_solid, mature_pre_storage_assembly = (
        exact._assemble_region_from_fragments(
            mature_storage.fragments, set(frozen.organic_ids)
        )
    )
    mature_pre_storage_comparison = exact._compare_solids(
        mature_pre_storage_solid, mature_pre_authority
    )
    mature_pre_caps = exact._paired_cap_analysis(
        mature_storage.fragments, set(frozen.organic_ids)
    )
    extension_counters = extension_edit.metrics["access_counters"]
    extension_instrumentation_clean = all(
        int(extension_counters[name]) == 0
        for name in (
            "global_fragment_iterations",
            "global_atom_iterations",
            "global_page_iterations",
            "forbidden_fragment_items_calls",
            "forbidden_fragment_values_calls",
            "forbidden_atom_items_calls",
            "forbidden_atom_values_calls",
            "forbidden_page_items_calls",
            "forbidden_page_values_calls",
        )
    )
    extension_closure = extension_edit.metrics[
        "replacement_interface_closure"
    ]

    b_edit_cells = _cells_for_bounds(
        tuple(float(value) for value in frozen.stroke_b.manifold.bounding_box())
    )
    young_selected_fragments = _selected_fragment_identity_manifest(
        frozen.young_storage, frozen.selected_space
    )
    mature_selected_fragments = _selected_fragment_identity_manifest(
        mature_storage, frozen.selected_space
    )
    young_pre_local_atoms = _indexed_atom_manifest(
        initial_publication, b_edit_cells
    )
    mature_pre_local_atoms = _indexed_atom_manifest(
        mature_publication, b_edit_cells
    )
    pre_pair_gates = {
        "mature_constructed_by_regional_extension_transaction": (
            int(extension_edit.metrics["one_local_boolean_count"]) == 1
        ),
        "mature_pre_publication_matches_monolithic_a_plus_extension": bool(
            mature_pre_publication_audit["passed"]
        ),
        "mature_pre_storage_matches_monolithic_a_plus_extension": all(
            exact._comparison_gate_summary(
                mature_pre_storage_comparison
            ).values()
        ),
        "mature_pre_storage_caps_are_closed_paired_oriented": _caps_are_paired(
            mature_pre_caps
        ),
        "extension_setup_guarded_indexes_have_no_forbidden_scan": (
            extension_instrumentation_clean
            and bool(
                extension_edit.metrics[
                    "no_global_fragment_atom_page_scan"
                ]
            )
        ),
        "extension_setup_closure_did_not_touch_perimeter": (
            not bool(extension_closure["jurisdiction_perimeter_touched"])
            and int(extension_closure["removed_atom_perimeter_touch_count"])
            == 0
            and int(
                extension_closure["replacement_atom_perimeter_touch_count"]
            )
            == 0
        ),
        "young_mature_b_selected_fragment_coords_objects_identical": (
            young_selected_fragments == mature_selected_fragments
        ),
        "young_mature_pre_b_local_atom_version_manifests_identical": (
            young_pre_local_atoms == mature_pre_local_atoms
        ),
    }
    failed_pre_pair = [
        name for name, passed in pre_pair_gates.items() if not passed
    ]
    _require(
        not failed_pre_pair,
        "mature pre-state gates failed: " + ", ".join(failed_pre_pair),
    )
    extension_setup_ms = (
        time.perf_counter_ns() - extension_setup_started
    ) / 1.0e6

    edit = _incremental_add(
        frozen.young_storage,
        initial_publication,
        frozen.stroke_b.manifold,
        frozen.organic_ids,
        frozen.stroke_b.original_id,
        frozen.property_lookup,
        source_tags,
        "paired_young_b",
    )
    mature_edit = _incremental_add(
        mature_storage,
        mature_publication,
        frozen.stroke_b.manifold,
        frozen.organic_ids,
        frozen.stroke_b.original_id,
        frozen.property_lookup,
        source_tags,
        "paired_mature_b",
    )

    # All exhaustive work below is deliberately outside transaction timing.
    oracle_started = time.perf_counter_ns()
    emitted_records, decoded_pages, page_roundtrip = _roundtrip_publication_state(
        edit.publication, frozen.property_lookup
    )
    emitted_quality = atlas._quality_summary(emitted_records)
    emitted_topologies = {
        str(quantum): atlas._topology_for_records(emitted_records, quantum)
        for quantum in TOPOLOGY_QUANTA_METERS
    }
    publication_solid, mesh64 = atlas._make_publication_solid(emitted_records)

    monolithic = frozen.stroke_a.manifold + frozen.stroke_b.manifold
    _require(exact._is_ok(monolithic), "young monolithic A+B oracle failed")
    _require(
        not monolithic.is_empty() and len(monolithic.decompose()) == 1,
        "young monolithic A+B oracle is not one solid",
    )
    monolithic_records = _records_from_solid(monolithic)
    publication_comparison = atlas._surface_and_volume_comparison(
        publication_solid,
        monolithic,
        emitted_records,
        monolithic_records,
    )
    publication_bounds_delta = atlas._bounds_delta(
        atlas._records_bounds(emitted_records),
        atlas._records_bounds(monolithic_records),
    )

    reconstructed_storage, storage_assembly = exact._assemble_region_from_fragments(
        edit.storage.fragments, set(frozen.organic_ids)
    )
    storage_comparison = exact._compare_solids(reconstructed_storage, monolithic)
    post_caps = exact._paired_cap_analysis(
        edit.storage.fragments, set(frozen.organic_ids)
    )
    after_perimeter = exact._perimeter_cap_signature(
        edit.storage.fragments,
        set(frozen.selected_space),
        set(frozen.organic_ids),
    )
    remote_storage_identity = exact._exhaustive_remote_identity_audit(
        frozen.young_storage, edit.storage, set(frozen.selected_space)
    )

    provenance = atlas._provenance_summary(
        emitted_records, frozen.source_face_counts
    )
    material_lineage = _source_material_lineage_audit(
        emitted_records,
        frozen.property_lookup,
        source_tags,
        expected_young_sources,
    )
    unchanged_atom_identity = all(
        edit.publication.atoms[lineage_id] is atom
        for lineage_id, atom in initial_publication.atoms.items()
        if lineage_id not in edit.removed_atom_ids
    )
    all_versions_content_addressed = all(
        atom.version_id == f"av:{atom.payload_sha256}"
        for atom in edit.publication.atoms.values()
    )
    counters = edit.metrics["access_counters"]
    instrumentation_clean = all(
        int(counters[name]) == 0
        for name in (
            "global_fragment_iterations",
            "global_atom_iterations",
            "global_page_iterations",
            "forbidden_fragment_items_calls",
            "forbidden_fragment_values_calls",
            "forbidden_atom_items_calls",
            "forbidden_atom_values_calls",
            "forbidden_page_items_calls",
            "forbidden_page_values_calls",
        )
    )
    closure = edit.metrics["replacement_interface_closure"]
    overlay = edit.metrics["overlay"]

    mature_post_authority = mature_pre_authority + frozen.stroke_b.manifold
    _require(
        exact._is_ok(mature_post_authority)
        and not mature_post_authority.is_empty()
        and len(mature_post_authority.decompose()) == 1,
        "mature monolithic A+extension+B oracle is not one valid solid",
    )
    (
        mature_emitted_records,
        mature_decoded_pages,
        _mature_publication_solid,
        mature_publication_audit,
    ) = _publication_authority_audit(
        mature_edit.publication,
        mature_post_authority,
        frozen.property_lookup,
        frozen.source_face_counts,
        source_tags,
        frozen.organic_ids,
    )
    mature_reconstructed_storage, mature_storage_assembly = (
        exact._assemble_region_from_fragments(
            mature_edit.storage.fragments, set(frozen.organic_ids)
        )
    )
    mature_storage_comparison = exact._compare_solids(
        mature_reconstructed_storage, mature_post_authority
    )
    mature_post_caps = exact._paired_cap_analysis(
        mature_edit.storage.fragments, set(frozen.organic_ids)
    )
    mature_before_perimeter = exact._perimeter_cap_signature(
        mature_storage.fragments,
        set(frozen.selected_space),
        set(frozen.organic_ids),
    )
    mature_after_perimeter = exact._perimeter_cap_signature(
        mature_edit.storage.fragments,
        set(frozen.selected_space),
        set(frozen.organic_ids),
    )
    mature_remote_storage_identity = exact._exhaustive_remote_identity_audit(
        mature_storage, mature_edit.storage, set(frozen.selected_space)
    )
    mature_remote_publication_identity = _remote_publication_identity_audit(
        mature_publication, mature_edit.publication, frozen.selected_space
    )
    young_replacement_manifest = _replacement_atom_manifest(edit)
    mature_replacement_manifest = _replacement_atom_manifest(mature_edit)
    young_rebuilt_page_manifest = _rebuilt_page_manifest(edit)
    mature_rebuilt_page_manifest = _rebuilt_page_manifest(mature_edit)
    young_retained_local_manifest = _retained_local_atom_manifest(
        initial_publication,
        edit.publication,
        edit.removed_atom_ids,
        b_edit_cells,
    )
    mature_retained_local_manifest = _retained_local_atom_manifest(
        mature_publication,
        mature_edit.publication,
        mature_edit.removed_atom_ids,
        b_edit_cells,
    )
    young_expected_retained_local_ids = {
        str(row["lineage_id"]) for row in young_pre_local_atoms
    } - set(edit.removed_atom_ids)
    mature_expected_retained_local_ids = {
        str(row["lineage_id"]) for row in mature_pre_local_atoms
    } - set(mature_edit.removed_atom_ids)
    mature_closure = mature_edit.metrics["replacement_interface_closure"]
    mature_counters = mature_edit.metrics["access_counters"]
    mature_instrumentation_clean = all(
        int(mature_counters[name]) == 0
        for name in (
            "global_fragment_iterations",
            "global_atom_iterations",
            "global_page_iterations",
            "forbidden_fragment_items_calls",
            "forbidden_fragment_values_calls",
            "forbidden_atom_items_calls",
            "forbidden_atom_values_calls",
            "forbidden_page_items_calls",
            "forbidden_page_values_calls",
        )
    )
    paired_transaction_gates = {
        "changed_source_face_labels_identical": (
            edit.metrics["changed_source_faces"]
            == mature_edit.metrics["changed_source_faces"]
        ),
        "transitive_closure_diagnostics_identical": closure == mature_closure,
        "removed_lineage_sets_identical": (
            edit.removed_atom_ids == mature_edit.removed_atom_ids
        ),
        "replacement_lineage_version_payload_manifests_identical": (
            young_replacement_manifest == mature_replacement_manifest
        ),
        "rebuilt_local_page_payload_sets_identical": (
            young_rebuilt_page_manifest == mature_rebuilt_page_manifest
        ),
        "retained_local_lineage_version_manifests_identical": (
            young_retained_local_manifest == mature_retained_local_manifest
            and {
                str(row["lineage_id"])
                for row in young_retained_local_manifest
            }
            == young_expected_retained_local_ids
            and {
                str(row["lineage_id"])
                for row in mature_retained_local_manifest
            }
            == mature_expected_retained_local_ids
        ),
        "young_removed_and_replacement_perimeter_touch_counts_zero": (
            int(closure["removed_atom_perimeter_touch_count"]) == 0
            and int(closure["replacement_atom_perimeter_touch_count"]) == 0
        ),
        "mature_removed_and_replacement_perimeter_touch_counts_zero": (
            int(mature_closure["removed_atom_perimeter_touch_count"]) == 0
            and int(
                mature_closure["replacement_atom_perimeter_touch_count"]
            )
            == 0
        ),
        "mature_remote_atom_page_objects_and_payload_hashes_unchanged": bool(
            mature_remote_publication_identity["passed"]
        ),
        "mature_remote_storage_objects_and_hashes_unchanged": bool(
            mature_remote_storage_identity["passed"]
        ),
        "mature_guarded_b_path_has_no_forbidden_scan": (
            mature_instrumentation_clean
            and bool(
                mature_edit.metrics[
                    "no_global_fragment_atom_page_scan"
                ]
            )
        ),
        "mature_post_publication_matches_monolithic_a_extension_b": bool(
            mature_publication_audit["passed"]
        ),
        "mature_post_storage_matches_monolithic_a_extension_b": all(
            exact._comparison_gate_summary(mature_storage_comparison).values()
        ),
        "mature_post_storage_caps_are_closed_paired_oriented": _caps_are_paired(
            mature_post_caps
        ),
        "mature_b_region_perimeter_signature_unchanged": (
            mature_before_perimeter == mature_after_perimeter
        ),
        "mature_post_source_and_material_lineage_preserved": bool(
            mature_publication_audit["source_material_lineage"]["passed"]
        ),
    }
    oracle_ms = (time.perf_counter_ns() - oracle_started) / 1.0e6

    hard_gates = {
        **pre_pair_gates,
        **paired_transaction_gates,
        "transitive_interface_closure_converged": bool(closure["converged"]),
        "every_interface_edge_has_exactly_two_opposite_incidences": bool(
            closure["every_interface_edge_has_two_opposite_incidences"]
        ),
        "closure_did_not_reach_regional_perimeter": not bool(
            closure["jurisdiction_perimeter_touched"]
        ) and int(closure["removed_atom_perimeter_touch_count"]) == 0
        and int(closure["replacement_atom_perimeter_touch_count"]) == 0,
        "actual_emitted_topology_passes_at_1e_8": atlas._topology_passes(
            emitted_topologies[str(1.0e-8)]
        ),
        "actual_emitted_topology_passes_at_1e_7": atlas._topology_passes(
            emitted_topologies[str(1.0e-7)]
        ),
        "actual_emitted_double_quality_strictly_above_1e_16": (
            int(emitted_quality["double_subthreshold_triangle_count"]) == 0
        ),
        "actual_emitted_float32_quality_strictly_above_1e_16": (
            int(emitted_quality["float32_subthreshold_triangle_count"]) == 0
        ),
        "actual_emitted_mesh64_noerror_one_component_genus_zero": (
            mesh64["status"] == "NoError"
            and int(mesh64["component_count"]) == 1
            and mesh64["component_genera"] == [0]
        ),
        "exact_page_arrays_roundtrip_and_hash": (
            bool(page_roundtrip["page_exact_array_hashes_verified"])
            and bool(page_roundtrip["atom_exact_array_hashes_verified"])
            and bool(page_roundtrip["combined_geometry_matches_pre_emission"])
        ),
        "stable_lineage_and_content_addressed_atom_versions": (
            bool(page_roundtrip["stable_lineage_ids_verified"])
            and bool(page_roundtrip["content_addressed_version_ids_verified"])
            and all_versions_content_addressed
        ),
        "full_atlas_matches_monolithic_a_plus_b": (
            float(publication_comparison["sampled_bidirectional_maximum_m"])
            <= MAX_SAMPLED_SURFACE_DISTANCE_METERS
            and float(publication_comparison["symmetric_difference_volume_m3"])
            <= MAX_SYMMETRIC_DIFFERENCE_VOLUME_M3
            and publication_bounds_delta <= atlas.SAME_BOUNDS_TOLERANCE_METERS
        ),
        "closed_storage_matches_monolithic_a_plus_b": all(
            exact._comparison_gate_summary(storage_comparison).values()
        ),
        "initial_and_post_storage_caps_are_paired": (
            _caps_are_paired(initial_caps) and _caps_are_paired(post_caps)
        ),
        "regional_perimeter_cap_signature_unchanged": (
            before_perimeter == after_perimeter
        ),
        "compiler_caps_absent_from_publication": (
            bool(provenance["passed"])
            and int(provenance["compiler_cap_triangle_count"]) == 0
            and set(
                int(value)
                for value in provenance["triangle_counts_by_original_id"]
            ) == set(expected_young_sources)
        ),
        "source_tag_and_material_lineage_preserved": bool(
            material_lineage["passed"]
        ),
        "guarded_timed_path_has_no_global_or_forbidden_mapping_scan": (
            instrumentation_clean
            and bool(
                edit.metrics[
                    "no_global_fragment_atom_page_scan"
                ]
            )
        ),
        "page_closure_constrains_rebuild_set": bool(
            overlay["page_closure_constrained_rebuild"]
        ),
        "unaffected_atom_objects_are_reused": unchanged_atom_identity,
        "remote_storage_fragment_objects_are_reused": bool(
            remote_storage_identity["passed"]
        ),
    }
    failed = [name for name, passed in hard_gates.items() if not passed]
    _require(
        not failed,
        "incremental paired young/mature hard gates failed: "
        + ", ".join(failed),
    )

    result: dict[str, Any] = {
        "schema": "forge_v2_incremental_publication_atlas_prototype_result",
        "schema_version": 1,
        "outcome": "pass",
        "proof_passed": True,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_incremental_paired_young_mature_geometry_gate",
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
            "file_sha256": frozen.fixture_sha256,
            "canonical_sha256_matches": bool(
                frozen.fixture_transport["top_level"]["matches"]
            ),
        },
        "setup": {
            "case": "paired_young_A_and_mature_A_extension_incremental_add_B",
            "chunk_size_m": CHUNK_SIZE_METERS,
            "halo_rings": HALO_RINGS,
            "young_fragment_count": len(frozen.young_storage.fragments),
            "selected_populated_fragment_count": len(frozen.local_coordinates),
            "initial_publication": initial_atlas,
            "initial_conditioning": conditioning,
        },
        "mature_extension_setup": {
            "construction": "untimed regional extension transaction on frozen A",
            "separate_from_b_transaction_timing": True,
            "setup_wall_ms": extension_setup_ms,
            "transaction": extension_edit.metrics,
            "local_fragment_reuse_after_equivalence": local_fragment_reuse,
            "pre_pair_gates": pre_pair_gates,
            "publication_audit": mature_pre_publication_audit,
            "publication_triangle_count": len(mature_pre_records),
            "publication_page_count": len(mature_pre_pages),
            "closed_storage_comparison": mature_pre_storage_comparison,
            "closed_storage_assembly": mature_pre_storage_assembly,
            "storage_caps": mature_pre_caps,
        },
        "paired_b_transactions": {
            "statistics_law": "one paired observation; no p50/p95 claim",
            "b_indexed_edit_cells": [list(value) for value in b_edit_cells],
            "young_pre_selected_fragment_manifest": young_selected_fragments,
            "mature_pre_selected_fragment_manifest": mature_selected_fragments,
            "young_pre_local_atom_manifest": young_pre_local_atoms,
            "mature_pre_local_atom_manifest": mature_pre_local_atoms,
            "young": edit.metrics,
            "mature": mature_edit.metrics,
            "young_transaction_ms": edit.metrics["phase_ms"][
                "instrumented_transaction_ms"
            ],
            "mature_transaction_ms": mature_edit.metrics["phase_ms"][
                "instrumented_transaction_ms"
            ],
            "paired_gates": paired_transaction_gates,
            "young_replacement_atom_manifest": young_replacement_manifest,
            "mature_replacement_atom_manifest": mature_replacement_manifest,
            "young_rebuilt_page_manifest": young_rebuilt_page_manifest,
            "mature_rebuilt_page_manifest": mature_rebuilt_page_manifest,
            "young_retained_local_atom_manifest": young_retained_local_manifest,
            "mature_retained_local_atom_manifest": mature_retained_local_manifest,
            "mature_remote_publication_identity": mature_remote_publication_identity,
        },
        "young_actual_post_overlay_publication": {
            "revision": edit.publication.revision,
            "atom_count": len(edit.publication.atoms),
            "page_count": len(edit.publication.pages),
            "triangle_count": len(emitted_records),
            "quality": emitted_quality,
            "topology": emitted_topologies,
            "mesh64": mesh64,
            "page_roundtrip": page_roundtrip,
            "provenance": provenance,
            "source_material_lineage": material_lineage,
            "unchanged_atom_object_identity_preserved": unchanged_atom_identity,
        },
        "mature_actual_post_overlay_publication": {
            "revision": mature_edit.publication.revision,
            "atom_count": len(mature_edit.publication.atoms),
            "page_count": len(mature_edit.publication.pages),
            **mature_publication_audit,
        },
        "monolithic_a_plus_b": {
            "summary": exact._solid_summary(monolithic),
            "publication_comparison": publication_comparison,
            "publication_bounds_max_delta_m": publication_bounds_delta,
            "closed_storage_comparison": storage_comparison,
        },
        "monolithic_a_extension_plus_b": {
            "summary": exact._solid_summary(mature_post_authority),
            "publication_comparison": mature_publication_audit[
                "comparison_to_authority"
            ],
            "closed_storage_comparison": mature_storage_comparison,
        },
        "storage_caps_and_perimeter": {
            "initial_caps": initial_caps,
            "post_caps": post_caps,
            "perimeter_signature_unchanged": before_perimeter == after_perimeter,
            "perimeter_signature_before": before_perimeter,
            "perimeter_signature_after": after_perimeter,
            "post_storage_assembly": storage_assembly,
            "remote_storage_identity": remote_storage_identity,
        },
        "mature_storage_caps_and_perimeter": {
            "pre_b_caps": mature_pre_caps,
            "post_b_caps": mature_post_caps,
            "perimeter_signature_unchanged": (
                mature_before_perimeter == mature_after_perimeter
            ),
            "perimeter_signature_before": mature_before_perimeter,
            "perimeter_signature_after": mature_after_perimeter,
            "post_storage_assembly": mature_storage_assembly,
            "remote_storage_identity": mature_remote_storage_identity,
        },
        "hard_gates": hard_gates,
        "exhaustive_oracles_outside_transaction_timing": True,
        "exhaustive_oracle_ms": oracle_ms,
        "proof_total_ms": (time.perf_counter_ns() - proof_started) / 1.0e6,
        "limitations": [
            "This run proves one paired young/mature B edit; timing distributions and long-run scaling remain separate gates.",
            "The Python manifold3d wheel is a tools-only geometry proof, not a runtime subprocess or production backend.",
            "Remove/VOID, multiple materials, undo, persistence, and Godot render/collision publication remain unimplemented here.",
        ],
    }
    packet_artifact: dict[str, Any] = {
        "schema": "forge_v2_incremental_publication_atlas_paired_packets",
        "schema_version": 1,
        "outcome": "pass",
        "source_result_path": str(OUTPUT_PAIRED_JSON),
        "fixture_sha256": frozen.fixture_sha256,
        "young": {
            "publication_revision": edit.publication.revision,
            "atom_count": len(edit.publication.atoms),
            "page_count": len(decoded_pages),
            "triangle_count": len(emitted_records),
            "combined_geometry_sha256": atlas._records_digest(emitted_records),
            "page_roundtrip": page_roundtrip,
            "pages": decoded_pages,
        },
        "mature": {
            "publication_revision": mature_edit.publication.revision,
            "atom_count": len(mature_edit.publication.atoms),
            "page_count": len(mature_decoded_pages),
            "triangle_count": len(mature_emitted_records),
            "combined_geometry_sha256": atlas._records_digest(
                mature_emitted_records
            ),
            "page_roundtrip": mature_publication_audit["page_roundtrip"],
            "pages": mature_decoded_pages,
        },
    }
    return result, packet_artifact


def _failure_result(error: BaseException) -> dict[str, Any]:
    return {
        "schema": "forge_v2_incremental_publication_atlas_prototype_result",
        "schema_version": 1,
        "outcome": "fail",
        "proof_passed": False,
        "generated_at_unix_seconds": time.time(),
        "scope": "tools_only_incremental_geometry_gate",
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
    young_only = "--young-only" in sys.argv[1:]
    validate_stitched_mature = "--validate-stitched-mature" in sys.argv[1:]
    validate_stitched_prestate = "--validate-stitched-prestate" in sys.argv[1:]
    diagnose_stitched_prestate_manifest = (
        "--diagnose-stitched-prestate-manifest" in sys.argv[1:]
    )
    validate_stitched_pair_transaction = (
        "--validate-stitched-pair-transaction" in sys.argv[1:]
    )
    diagnose_stitched_pair_fragments = (
        "--diagnose-stitched-pair-fragments" in sys.argv[1:]
    )
    allowed_arguments = {
        "--young-only",
        "--validate-stitched-mature",
        "--validate-stitched-prestate",
        "--diagnose-stitched-prestate-manifest",
        "--validate-stitched-pair-transaction",
        "--diagnose-stitched-pair-fragments",
    }
    unknown_arguments = [
        value for value in sys.argv[1:] if value not in allowed_arguments
    ]
    if unknown_arguments:
        print(
            "unknown arguments: " + ", ".join(unknown_arguments),
            file=sys.stderr,
        )
        return 2
    selected_modes = sum(
        (
            young_only,
            validate_stitched_mature,
            validate_stitched_prestate,
            diagnose_stitched_prestate_manifest,
            validate_stitched_pair_transaction,
            diagnose_stitched_pair_fragments,
        )
    )
    if selected_modes > 1:
        print("choose only one validation mode", file=sys.stderr)
        return 2
    if diagnose_stitched_pair_fragments:
        try:
            result = _diagnose_stitched_pair_fragments()
            exit_code = 0
        except Exception as error:
            result = _failure_result(error)
            result["scope"] = (
                "tools_only_sequential_full_pair_fragment_diagnostic"
            )
            result["diagnostic_only"] = True
            exit_code = 1
        exact._atomic_write_text(
            OUTPUT_STITCHED_PAIR_FRAGMENT_DIAGNOSTIC_JSON,
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
            print("INCREMENTAL PUBLICATION ATLAS STITCHED PAIR FRAGMENT DIAGNOSTIC COMPLETE")
        else:
            print(
                "INCREMENTAL PUBLICATION ATLAS STITCHED PAIR FRAGMENT "
                "DIAGNOSTIC FAIL: %s: %s"
                % (result["failure_type"], result["failure_reason"]),
                file=sys.stderr,
            )
        return exit_code
    if validate_stitched_pair_transaction:
        try:
            result = _validate_stitched_pair_transaction()
            exit_code = 0
        except Exception as error:
            result = _failure_result(error)
            result["scope"] = "tools_only_stitched_paired_transaction"
            exit_code = 1
        exact._atomic_write_text(
            OUTPUT_STITCHED_PAIR_TRANSACTION_JSON,
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
            print("INCREMENTAL PUBLICATION ATLAS STITCHED PAIR TRANSACTION PASS")
        else:
            print(
                "INCREMENTAL PUBLICATION ATLAS STITCHED PAIR TRANSACTION "
                "FAIL: %s: %s"
                % (result["failure_type"], result["failure_reason"]),
                file=sys.stderr,
            )
        return exit_code
    if diagnose_stitched_prestate_manifest:
        try:
            result = _diagnose_stitched_prestate_manifest()
            exit_code = 0
        except Exception as error:
            result = _failure_result(error)
            result["scope"] = (
                "tools_only_stitched_prestate_publication_manifest"
            )
            result["diagnostic_only"] = True
            exit_code = 1
        exact._atomic_write_text(
            OUTPUT_STITCHED_PRESTATE_MANIFEST_DIAGNOSTIC_JSON,
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
            print("INCREMENTAL PUBLICATION ATLAS PRESTATE MANIFEST DIAGNOSTIC COMPLETE")
        else:
            print(
                "INCREMENTAL PUBLICATION ATLAS PRESTATE MANIFEST DIAGNOSTIC "
                "FAIL: %s: %s"
                % (result["failure_type"], result["failure_reason"]),
                file=sys.stderr,
            )
        return exit_code
    if validate_stitched_prestate:
        try:
            result = _validate_stitched_prestate()
            exit_code = 0
        except Exception as error:
            result = _failure_result(error)
            result["scope"] = "tools_only_stitched_frozen_prestate_validation"
            exit_code = 1
        exact._atomic_write_text(
            OUTPUT_STITCHED_PRESTATE_VALIDATION_JSON,
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
            print("INCREMENTAL PUBLICATION ATLAS STITCHED PRESTATE VALIDATION PASS")
        else:
            print(
                "INCREMENTAL PUBLICATION ATLAS STITCHED PRESTATE VALIDATION "
                "FAIL: %s: %s"
                % (result["failure_type"], result["failure_reason"]),
                file=sys.stderr,
            )
        return exit_code
    if validate_stitched_mature:
        try:
            result = _validate_stitched_mature()
            exit_code = 0
        except Exception as error:
            result = _failure_result(error)
            result["scope"] = "tools_only_stitched_mature_fixture_validation"
            exit_code = 1
        exact._atomic_write_text(
            OUTPUT_STITCHED_MATURE_VALIDATION_JSON,
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
            print("INCREMENTAL PUBLICATION ATLAS STITCHED MATURE VALIDATION PASS")
        else:
            print(
                "INCREMENTAL PUBLICATION ATLAS STITCHED MATURE VALIDATION FAIL: %s: %s"
                % (result["failure_type"], result["failure_reason"]),
                file=sys.stderr,
            )
        return exit_code
    output_json = OUTPUT_YOUNG_OPTIMIZED_JSON if young_only else OUTPUT_PAIRED_JSON
    output_packets_json = (
        OUTPUT_YOUNG_OPTIMIZED_PACKETS_JSON
        if young_only
        else OUTPUT_PAIRED_PACKETS_JSON
    )
    try:
        if young_only:
            result, packet_artifact = _run_young_optimized_regression()
        else:
            result, packet_artifact = _run_proof()
        exit_code = 0
    except Exception as error:
        result = _failure_result(error)
        packet_artifact = {
            "schema": "forge_v2_incremental_publication_atlas_packets",
            "schema_version": 1,
            "outcome": "not_emitted",
            "failure_reason": str(error),
        }
        exit_code = 1
    exact._atomic_write_text(
        output_json,
        json.dumps(result, sort_keys=True, ensure_ascii=True, allow_nan=False,
                   separators=(",", ":")) + "\n",
    )
    exact._atomic_write_text(
        output_packets_json,
        json.dumps(packet_artifact, sort_keys=True, ensure_ascii=True,
                   allow_nan=False, separators=(",", ":")) + "\n",
    )
    if exit_code == 0:
        mode = "YOUNG OPTIMIZED" if young_only else "PAIRED"
        print(f"INCREMENTAL PUBLICATION ATLAS {mode} PASS")
    else:
        print(
            "INCREMENTAL PUBLICATION ATLAS FAIL: %s: %s"
            % (result["failure_type"], result["failure_reason"]),
            file=sys.stderr,
        )
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
