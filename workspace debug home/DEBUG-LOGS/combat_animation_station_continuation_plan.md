# Combat Animation Station → Motion Node Skill Crafter Continuation Plan
## Updated 2026-04-12 — Incorporates SKILL_SYSTEM_CONSOLIDATED_REFERENCE

## Sources Cross-Referenced

### GDD Documents (all read verbatim, every section)
1. **GDD Doc 1**: `GDD-and Text Resources/Runtime Weapon-Owned Melee Skill Crafter 1.md` (~950 lines, 21 sections)
2. **GDD Doc 2**: `GDD-and Text Resources/Runtime Weapon-Owned Melee Skill Crafter-2.md` (~600 lines, 21 sections) — stricter CODEX rewrite + reusable playback + runtime presentation
3. **GDD Doc 3**: `GDD-and Text Resources/Runtime Melee Combat Editor Visual-System.md` (~400 lines, 20 sections) — Bézier workflow, speed-state coloring, Stage 1 integration, hit segmentation
4. **GDD Doc 4**: `GDD-and Text Resources/Runtime Combat Editor Visual and System Addendum.md` (~400 lines, 14 sections) — Bézier identity, skill-slot law, mass/weapon-feel, material effects
5. **Consolidated Reference**: `GDD-and Text Resources/UPLOADED/SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md` (~900 lines) — **superseding authority** for motion-node model, control hierarchy, input law, slot ids

### Existing Source Files (all read in full)
- `scripts/core/models/combat_animation_station_state.gd` (127 lines)
- `scripts/core/models/combat_animation_draft.gd` (129 lines)
- `scripts/core/models/combat_animation_point.gd` (53 lines) — **TO BE REPLACED** by CombatAnimationMotionNode
- `scripts/runtime/combat/combat_animation_station.gd` (28 lines)
- `scripts/runtime/combat/combat_animation_station_preview_presenter.gd` (~310 lines)
- `scripts/runtime/combat/combat_animation_station_ui.gd` (~960 lines)

### Project Laws (all read in full)
- `NAMING_LAW.md`
- `AGENT_GUARDRAILS.md`
- `CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md` (2000+ lines)
- `/memories/repo/the-will-workspace.md`
- `project-aligned workaround.md` (GDScript strict typing rules)

### Godot API Documentation (all researched)
- **Curve3D**: Bézier curve resource — add_point(pos, in, out), get_baked_points(), sample_baked(), sample_baked_with_rotation(), get_closest_point/offset(), tessellate_even_length()
- **Path3D**: Node3D that holds Curve3D, emits curve_changed signal
- **PathFollow3D**: Follows Path3D via progress/progress_ratio, rotation_mode (NONE/Y/XY/XYZ/ORIENTED)
- **ImmediateMesh**: Manual geometry surface_begin/add_vertex/end, already used for trajectory + control lines
- **InputMap**: Singleton — add_action(), action_add_event(), has_action(), erase_action()
- **Tween**: create_tween() → tween_property()/tween_method()/tween_callback(), parallel(), chain(), set_loops()
- **Plane**: intersects_ray(from, dir), project(point), distance_to(point), Plane(normal, point) constructor
- **Basis**: from_euler(euler), rotated(axis, angle), get_euler(), slerp(to, weight), looking_at(target, up), orthonormalized()

### BakedProfile Fields Available for Combat Station (from existing code)
- `center_of_mass: Vector3` — density-weighted center
- `total_mass: float` — density-weighted total
- `reach: float` — max grip-to-geometry extent
- `primary_grip_offset: Vector3` — grip position
- `primary_grip_contact_position: Vector3` — hand contact point
- `primary_grip_span_start: Vector3` / `primary_grip_span_end: Vector3` — grip endcap positions
- `primary_grip_span_length_voxels: int` — grip length
- `primary_grip_slide_axis: Vector3` — grip axis direction vector
- `primary_grip_com_side_position: Vector3` / `primary_grip_far_side_position: Vector3` — extremities along grip axis
- `primary_grip_two_hand_eligible: bool` — two-hand flags
- `primary_grip_two_hand_negative_limit: float` / `primary_grip_two_hand_positive_limit: float`
- `front_heavy_score: float`, `balance_score: float` — weapon feel

---

## Section 1: Full Cross-Reference — Existing Code vs Consolidated Reference Requirements

> **Authority**: `SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md` supersedes all prior GDD docs.
> All prior "point" concepts are replaced by "motion node" (§3.12-3.13).
> All prior "commit" concepts are removed. Space cycles tip↔pommel focus (§3.13.13).

### FULLY IMPLEMENTED ✅ (9 items — survive motion-node rewrite)

| # | Requirement | Ref Sections | Existing Implementation |
|---|------------|-------------|------------------------|
| 1 | Weapon ownership — every skill draft belongs to one weapon | §1.1, §2.1, §3.1 | `CombatAnimationStationState` stored on weapon WIP via `PlayerForgeWipLibraryState`. Drafts array on station state ties to weapon. |
| 2 | 3-step menu flow (weapon → authoring mode → draft) | §2.1, §3.2 | `combat_animation_station_ui.gd` weapon WIP list → idle/skill selector → draft list |
| 3 | Default baseline generation (new weapons) | §3.8 | `ensure_default_baseline_content()` generates melee_baseline_a/b or weapon_baseline_a. **Needs update**: baselines must produce 2-motion-node chains instead of 2-point chains. |
| 4 | Auto-save draft on exit | §3.7 | UI calls `_auto_save_to_wip_library()` on every change via `_persist_station_state()` |
| 5 | Restore draft on reopen | §3.7 | Weapon selection loads station state from WIP library; `selected_skill_id` persists |
| 6 | 3D preview with actor + weapon | §3.5, §3.14 | Preview presenter creates SubViewport with own_world_3d, PlayerHumanoidRig actor, equipped weapon, 2 lights, camera, floor |
| 7 | Bézier trajectory visualization (partial) | §3.4, §3.13 | Single Curve3D → ImmediateMesh line strip exists. **Needs expansion**: two curves (tip + pommel) with distinct colors. |
| 8 | Grip axis from BakedProfile (verified) | §3.13.1-3.13.3 | Full chain: `_calculate_slice_center()` → `_build_grip_span_from_candidate_chain()` → `build_primary_grip_anchor()` → `apply_primary_grip_profile()` → BakedProfile fields. See Section 10 for detail. |
| 9 | Canonical skill slot ids | §2.2.1, §3.9.1 | `CombatAnimationDraft.legal_slot_id` field exists. Slots: skill_slot_1 through skill_slot_12. |

### NEEDS REFACTORING 🔄 (8 items — existing code must change for motion-node model)

| # | Requirement | Ref Sections | What Exists | What Must Change |
|---|------------|-------------|-------------|-----------------|
| 10 | Motion-node chain (replaces point chain) | §3.12-3.13 | `CombatAnimationDraft.point_chain: Array[Resource]` of `CombatAnimationPoint` | Replace with `motion_node_chain: Array[Resource]` of new `CombatAnimationMotionNode`. Full data model rewrite (see Section 3). |
| 11 | Two Curve3D instances per draft (tip + pommel) | §3.4, §3.13.5-3.13.8 | Single Curve3D with single in/out handle per point | Two Curve3D instances. 4 handles per node: tip_in, tip_out, pommel_in, pommel_out. |
| 12 | Trajectory plane as first-class authored control | §3.13.5 | `CombatAnimationPoint` has active_plane_origin/normal/axis_u/axis_v (flat data) | Motion node owns trajectory_plane_orientation (Basis). Plane default = world ZX. Supports tilt, roll (along origin→tip axis), vertical displacement. Persists position. |
| 13 | Tip position on trajectory plane | §3.13.6 | `CombatAnimationPoint.local_target_position` (single position) | `tip_position_local: Vector3` — constrained to trajectory plane surface |
| 14 | Pommel position on sphere around tip | §3.13.7 | Does not exist | `pommel_position_local: Vector3` — constrained to sphere of radius = `weapon_total_length_calculated`, centered on tip |
| 15 | Weapon roll ±120° | §3.13.4 | Does not exist | `weapon_roll_degrees: float` — independent axis rotation around grip axis |
| 16 | Space cycles tip↔pommel focus | §3.13.13 | Space was commit key | Space now toggles editor focus between tip editing and pommel editing. No commit concept. |
| 17 | R copies current node at same coords | §3.13.13 (derived from user decision) | R was "add point after" with positional offset | R duplicates current motion node at identical coordinates, increments index, in-place editing always. |

### NOT YET IMPLEMENTED ❌ (14 items)

| # | Requirement | Ref Sections | Notes |
|---|------------|-------------|-------|
| 18 | **InputMap actions** | §3.3: Q=prev, E=next (editor context) | Register on station open, unregister on close. Also R=copy-node, T=delete-node, Space=cycle-focus, F=preview. |
| 19 | **Onion skin display** (tip + pommel markers) | §3.5 | ±1/±2 neighbor ghost positions. Both tip AND pommel markers visible. Both curves visible with transparency. Editor-only, not in gameplay. |
| 20 | **3D drag editing on trajectory plane** | §3.13.5-3.13.6 | Mouse ray → Plane.intersects_ray() → tip position update. Plane visualization (ImmediateMesh quad). Plane tilt/roll/displacement UI. |
| 21 | **Pommel sphere constraint editing** | §3.13.7-3.13.8 | Mouse ray → sphere surface intersection → pommel position update. Sphere visualization (wireframe). |
| 22 | **Axial reposition** | §3.13.9 | Per-node offset along grip axis. Shifts weapon position without changing tip/pommel curves. |
| 23 | **Grip-seat slide** | §3.13.10 | Per-node offset along grip axis shifting hand contact point. Different from axial reposition (moves hand, not weapon). |
| 24 | **Preview playback** (F key) | §3.6, §3.14 | One-shot. Tip and pommel move simultaneously along respective curves. IK body follows. Material weight/mass affects acceleration/deceleration. |
| 25 | **Reusable chain playback** (CombatAnimationChainPlayer) | §3.6, §3.14 | Standalone RefCounted. Both editor preview and future runtime/presentation contexts use it. Needed immediately for testing. |
| 26 | **Speed-state trajectory coloring** | §3.5 | Red=armed/fast, green=reset/slow. Per-vertex color from sampled speed. Placeholder first-pass acceptable. |
| 27 | **Validation layer** | §3.9 | Slot law, minimum node count, protected first node, degenerate handle check. |
| 28 | **Session state separation** | §3.7 (derived) | Current weapon, current draft, current node index, current focus (tip vs pommel), active plane state, playback state. |
| 29 | **Stage 1 data integration** | §3.13.1-3.13.3 | Wire BakedProfile grip axis, COM, mass data into preview and node constraint system. |
| 30 | **weapon_total_length_calculated** | §3.13.2 | **RESOLVED** — full derivation algorithm in Section 10. New function in ProfilePrimaryGripResolver + 5 new BakedProfile fields. |
| 31 | **Hit economy / segment rules** | §3.11 | First node = startup (non-hit). Later segments = hit phases. Driven by node transition durations and curve speed. |

---

## Section 2: Resolved Decisions (formerly NEEDS_DECISION)

> All decisions resolved via user discussion. No open items remain.

| Decision | Resolution | Source |
|----------|-----------|--------|
| **Data model** | Full rewrite to CombatAnimationMotionNode. No parallel old code. Delete CombatAnimationPoint. | User explicit |
| **Bézier curves** | Both tip AND pommel as separate Curve3D instances per draft. 4 handles per node: tip_in, tip_out, pommel_in, pommel_out. | User explicit |
| **Commit concept** | **Removed entirely.** No commit. R copies current node at same coordinates (in-place editing always). Space cycles tip↔pommel focus. | User explicit |
| **Trajectory plane** | 2 points form the system: player shoulder-center + tip. Plane is manipulable (tilt, roll along origin→tip axis, vertical displacement). Default spawn = world ZX. Plane persists position across edits. | User explicit |
| **Pommel constraint** | Orbits tip on sphere. Radius = `weapon_total_length_calculated` (derivation PENDING — user will re-explain). | User explicit |
| **Grip axis source** | Read cached BakedProfile from WIP library. Verified: existing grip resolver chain provides span_start/end, slide_axis, com_side/far_side, contact_position (see Section 10). | User explicit + code verified |
| **Rolls** | Two separate independent rolls: trajectory plane roll AND weapon roll (±120°). | User explicit |
| **Naming** | Rename to `motion_node` in code now. File/class names: `CombatAnimationMotionNode`, `motion_node_chain`, `motion_node_index`. | User explicit |
| **Onion skin** | Tip + pommel markers at ±1/±2 neighbor positions with both curves visible. Semi-transparent. Editor-only, not in gameplay. | User explicit |
| **Playback** | Build CombatAnimationChainPlayer now (needed for testing). Tip and pommel move simultaneously. IK body follows. Material weight/mass affects acceleration/deceleration curves. | User explicit |
| **Speed coloring** | Placeholder first-pass acceptable. Normalized segment length / transition_duration as approximate speed proxy. | User explicit |
| **Transition duration** | Per-node `transition_duration_seconds: float`, preserved from old model. | User explicit |
| **weapon_total_length_calculated** | **RESOLVED.** Full algorithm documented in Section 10. Derives from: furthest-apart grip endcap centers → grip axis → project all cells → perpendicular extremity planes → axis distance = total length. Hand position determines tip vs pommel (longer side = tip). 5 new BakedProfile fields. | User explained |

---

## Section 3: New Data Model — CombatAnimationMotionNode

> Replaces `CombatAnimationPoint` entirely. Per consolidated ref §3.12-3.13.

```
CombatAnimationMotionNode (Resource)
├── node_id: String                          # unique identifier
├── node_index: int                          # position in chain (0-based)
│
├── # Trajectory Plane (§3.13.5)
├── trajectory_plane_orientation: Vector3     # euler angles (degrees) for plane Basis
├── trajectory_plane_vertical_offset: float   # vertical displacement from default
│
├── # Tip Control (§3.13.6) — position lives on trajectory plane
├── tip_position_local: Vector3              # position on plane surface
├── tip_curve_in_handle: Vector3             # Bézier in-handle for tip curve
├── tip_curve_out_handle: Vector3            # Bézier out-handle for tip curve
│
├── # Pommel Control (§3.13.7-3.13.8) — orbits tip on sphere
├── pommel_position_local: Vector3           # position on sphere (radius = weapon_total_length)
├── pommel_curve_in_handle: Vector3          # Bézier in-handle for pommel curve
├── pommel_curve_out_handle: Vector3         # Bézier out-handle for pommel curve
│
├── # Weapon Orientation (§3.13.4)
├── weapon_roll_degrees: float               # ±120° roll around grip axis
│
├── # Grip Adjustments (§3.13.9-3.13.10)
├── axial_reposition_offset: float           # shift weapon along grip axis
├── grip_seat_slide_offset: float            # shift hand contact along grip axis
│
├── # Timing
├── transition_duration_seconds: float       # time to reach this node from previous
│
├── # Body
├── body_support_blend: float                # 0.0 = no IK influence, 1.0 = full IK follow
├── two_hand_state: int                      # 0=one-hand, 1=two-hand, 2=auto
├── grip_style_mode: int                     # grip style enum
│
└── # Meta
    └── draft_notes: String                  # author notes for this node
```

### CombatAnimationDraft Changes

```
CombatAnimationDraft
├── motion_node_chain: Array[Resource]       # was: point_chain
├── tip_curve_bake_interval: float = 0.015   # shared across tip curve
├── pommel_curve_bake_interval: float = 0.015
├── selected_motion_node_index: int          # was: selected_point_index
├── skill_name: String                       # new (§3.13.14)
├── skill_description: String                # new (§3.13.14)
├── ... (existing fields: draft_id, draft_kind, legal_slot_id, etc.)
```

---

## Section 4: Assumptions (standing)

1. **Architecture extends existing flat structure.** New files only when a genuinely new responsibility requires separation. AGENT_GUARDRAILS: "Do not implement extra systems for convenience."
2. **Click-based UI and InputMap controls coexist.** Existing button UI remains valid; keyboard shortcuts add on top.
3. **GDScript strict-typing rules apply** (`project-aligned workaround.md`): explicit types everywhere, no `:=` with Variant RHS, typed array locals, typed helpers (maxf/clampf), immediate casts on lookups.
4. **Architecture law applies**: defs/atoms → models → resolvers → services → runtime controllers → scenes/ui.
5. **Output law applies**: plan → assumptions → NEEDS_DECISION → files → code.
6. **First-pass speed-state coloring uses placeholder thresholds.** Full BakedProfile-driven speed profiles wired later.
7. **Onion skin uses semi-transparent markers** (tip + pommel SphereMesh at neighbor positions + both curve lines at reduced alpha). Not full-rig duplicate actors.

---

## Section 5: Implementation Plan — Ordered Milestones

### Milestone 0: Data Model Rewrite
**Goal**: Replace CombatAnimationPoint with CombatAnimationMotionNode, update draft and state models

**Files to create**:
- NEW: `scripts/core/models/combat_animation_motion_node.gd` — Resource with all fields from Section 3 data model

**Files to edit**:
- EDIT: `scripts/core/models/combat_animation_draft.gd` — `point_chain` → `motion_node_chain`, add `tip_curve_bake_interval`, `pommel_curve_bake_interval`, `selected_motion_node_index`, `skill_name`, `skill_description`. Update `create_default_skill_baseline()` to produce 2-motion-node chain. Update `ensure_minimum_baseline_points()` → `ensure_minimum_baseline_nodes()`. Update `normalize()`.
- EDIT: `scripts/core/models/combat_animation_station_state.gd` — Update dynamic script load from point to motion_node. Update `ensure_default_baseline_content()` baseline generation to produce motion-node chains.

**Files to delete**:
- DELETE: `scripts/core/models/combat_animation_point.gd` — fully replaced

**Scope**: Data layer only. No UI, no preview, no input. All downstream consumers will break until updated in subsequent milestones.

### Milestone 1: UI Refactor for Motion Nodes
**Goal**: Update the full UI controller to work with motion nodes instead of points

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_ui.gd` — Major refactor:
  - All `point` references → `motion_node`
  - Detail editor panel: replace position/rotation/handles with motion-node fields:
    - **Trajectory plane**: orientation euler XYZ, vertical offset
    - **Tip**: position XYZ (on plane), in/out handle XYZ
    - **Pommel**: position XYZ (on sphere), in/out handle XYZ
    - **Weapon**: roll degrees slider (±120°)
    - **Grip adjustments**: axial reposition, grip-seat slide
    - **Timing**: transition_duration_seconds (preserved)
    - **Body**: body_support_blend, two_hand_state, grip_style_mode (preserved)
  - Focus state tracking: `_current_focus: StringName` = `&"tip"` or `&"pommel"`
  - Space key cycles focus (not commit)
  - R duplicates current node at same coords
  - Add/remove buttons update for motion_node_chain

### Milestone 2: Preview Presenter Refactor
**Goal**: Two-curve rendering, motion-node markers, trajectory plane visualization

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_preview_presenter.gd` — Major refactor:
  - **Two Curve3D instances**: `_tip_curve: Curve3D`, `_pommel_curve: Curve3D`
  - **Two ImmediateMesh line strips**: tip curve in one color, pommel curve in another
  - **Motion-node markers**: each node renders TWO sphere markers (tip position + pommel position). Active node highlighted, inactive dimmed.
  - **Handle markers**: 4 BoxMesh markers per active node (tip_in, tip_out, pommel_in, pommel_out)
  - **Trajectory plane visualization**: ImmediateMesh quad at current node's plane orientation
  - **Pommel sphere wireframe**: Low-poly wireframe sphere at tip position with radius = weapon_total_length_calculated (when available)
  - **Focus indication**: Active focus target (tip or pommel) rendered larger/brighter
  - `_rebuild_curves_from_chain()` iterates motion_node_chain, populates both Curve3D instances from tip/pommel positions + handles

### Milestone 3: InputMap + Keyboard Controls
**Goal**: Wire Q/E/R/T/Space/F as InputMap actions

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_ui.gd` — add InputMap registration, `_unhandled_input()` handler

**Specifics**:
- Register 6 actions on open: `skill_crafter_prev_node` (Q), `skill_crafter_next_node` (E), `skill_crafter_copy_node` (R), `skill_crafter_delete_node` (T), `skill_crafter_cycle_focus` (Space), `skill_crafter_play_preview` (F)
- Unregister on close via `InputMap.erase_action()`
- Q/E: navigate motion_node_chain index
- R: duplicate current node at same coords, insert after, select new
- T: delete current node, auto-select backward
- Space: toggle `_current_focus` between `&"tip"` and `&"pommel"`, refresh detail panel + preview markers
- F: trigger preview playback

**Godot systems used**: `InputMap.add_action()`, `InputMap.action_add_event()`, `InputEventKey`

### Milestone 4: Session State Separation
**Goal**: Dedicated session state tracking editor-transient data

**Files to create**:
- NEW: `scripts/core/models/combat_animation_session_state.gd` — RefCounted:
  - `current_weapon_wip_id: String`
  - `current_draft_ref: Resource` (CombatAnimationDraft)
  - `current_motion_node_index: int`
  - `current_focus: StringName` — `&"tip"` or `&"pommel"`
  - `active_plane_visualization_enabled: bool`
  - `playback_active: bool`
  - `onion_skin_enabled: bool`

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_ui.gd` — use session state instead of scattered local vars

### Milestone 5: Onion Skin Display
**Goal**: Ghost tip + pommel markers at neighbor node positions with curve transparency

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_preview_presenter.gd` — new `_refresh_onion_skin()`:
  - ±1 neighbors: tip + pommel SphereMesh markers at 50% alpha
  - ±2 neighbors: tip + pommel SphereMesh markers at 25% alpha
  - Both curve lines rendered at reduced alpha for ±1/±2 segments
  - Uses `StandardMaterial3D.transparency = ALPHA`, `.albedo_color.a`
  - Updated on every navigation/edit event

### Milestone 6: 3D Plane + Sphere Editing
**Goal**: Mouse-based drag editing for tip (on plane) and pommel (on sphere)

**Files to create**:
- NEW: `scripts/runtime/combat/combat_animation_motion_node_editor.gd` — RefCounted:
  - Plane mode: ray → `Plane.intersects_ray()` → tip position update (constrained to plane surface)
  - Sphere mode: ray → sphere intersection → pommel position update (constrained to sphere of radius = weapon_total_length_calculated)
  - Plane visualization (ImmediateMesh quad)
  - Sphere visualization (wireframe)
  - Plane manipulation: tilt, roll along origin→tip axis, vertical displacement

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_ui.gd` — forward mouse input to motion node editor
- EDIT: `scripts/runtime/combat/combat_animation_station_preview_presenter.gd` — render active plane + sphere visuals

**Godot systems used**: `Camera3D.project_ray_origin()`, `Camera3D.project_ray_normal()`, `Plane.intersects_ray()`, `Basis.rotated()`

### Milestone 7: Chain Playback (F Preview + Reusable)
**Goal**: Simultaneous tip + pommel curve playback, reusable architecture

**Files to create**:
- NEW: `scripts/runtime/combat/combat_animation_chain_player.gd` — RefCounted:
  - Takes: motion_node_chain + tip Curve3D + pommel Curve3D + target Node3D
  - Drives: tip and pommel positions simultaneously along respective curves
  - Timing: per-node `transition_duration_seconds` drives segment timing
  - Mass effect: accept BakedProfile for acceleration/deceleration weighting (placeholder first-pass)
  - Modes: one-shot (editor F preview), loop (future presentation)
  - Signals: `playback_finished`, `node_reached(index: int)`

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_preview_presenter.gd` — use chain player for F preview, drive actor IK from tip/pommel positions
- EDIT: `scripts/runtime/combat/combat_animation_station_ui.gd` — F key triggers playback, re-press restarts

**Godot systems used**: `Curve3D.sample_baked()`, `Curve3D.sample_baked_with_rotation()`, `Tween.tween_method()`

### Milestone 8: Speed-State Trajectory Coloring
**Goal**: Color-coded trajectory (red=armed/fast, green=reset/slow)

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_preview_presenter.gd` — per-vertex speed-derived color in curve rendering. Approximate speed = segment arc length / transition_duration_seconds. Both tip and pommel curves get independent speed coloring.

**Godot systems used**: `ImmediateMesh.surface_set_color()` per vertex, `Color.lerp()`

### Milestone 9: Validation + Stage 1 Integration
**Goal**: Basic draft validation + BakedProfile data wiring

**Files to create**:
- NEW: `scripts/core/resolvers/combat_animation_draft_validator.gd` — validates: minimum node count, no degenerate zero-handle chains, protected first node. Returns validation results array. Slot law = TODO stub.

**Files to edit**:
- EDIT: `scripts/runtime/combat/combat_animation_station_preview_presenter.gd` — accept BakedProfile, use grip axis for default plane orientation, pass to chain player for mass weighting
- EDIT: `scripts/runtime/combat/combat_animation_station_ui.gd` — pass BakedProfile from weapon WIP, display validation state

---

## Section 6: Milestone Priority Map

```
Phase 1 — Data Foundation (Milestone 0) ✅ COMPLETE
  └─ M0: CombatAnimationMotionNode replaces CombatAnimationPoint ✅

Phase 2 — Core Editor (Milestones 1-3) ✅ COMPLETE
  ├─ M1: UI refactor for motion nodes ✅
  ├─ M2: Preview presenter refactor (two curves, plane viz) ✅
  └─ M3: InputMap + keyboard controls (Q/E/R/T/Space/F) ✅

Phase 3 — Session + Neighborhood (Milestones 4-5) ✅ COMPLETE
  ├─ M4: Session state separation ✅ COMPLETE
  └─ M5: Onion skin display ✅ COMPLETE

Phase 4 — 3D Editing + Playback (Milestones 6-7) ✅ COMPLETE
  ├─ M6: Plane + sphere drag editing ✅ COMPLETE
  └─ M7: Chain playback (F preview + reusable) ✅ COMPLETE

Phase 5 — Polish + Integration (Milestones 8-9) ✅ COMPLETE
  ├─ M8: Speed-state trajectory coloring ✅ COMPLETE
  └─ M9: Validation + Stage 1 data integration ✅ COMPLETE
```

---

## Section 7: Files Summary

### New files to create (5)
1. `scripts/core/models/combat_animation_motion_node.gd` — motion node Resource (M0)
2. `scripts/core/models/combat_animation_session_state.gd` — editor session state (M4)
3. `scripts/runtime/combat/combat_animation_chain_player.gd` — reusable playback driver (M7)
4. `scripts/runtime/combat/combat_animation_motion_node_editor.gd` — plane + sphere interaction (M6)
5. `scripts/core/resolvers/combat_animation_draft_validator.gd` — validation (M9)

### Existing files to edit (4)
1. `scripts/runtime/combat/combat_animation_station_ui.gd` — M1, M3, M4, M6, M7, M9
2. `scripts/runtime/combat/combat_animation_station_preview_presenter.gd` — M2, M5, M6, M7, M8, M9
3. `scripts/core/models/combat_animation_draft.gd` — M0
4. `scripts/core/models/combat_animation_station_state.gd` — M0

### Existing file to delete (1)
1. `scripts/core/models/combat_animation_point.gd` — replaced by motion_node (M0)

### Files NOT created (from GDD's ~40-file architecture)
The GDD proposes ~40 files across browser/, session/, data/, authoring/, preview/, gizmos/ subsystems. The existing structure handles most functionality. New files created only for genuinely separate responsibilities (motion node model, session state, chain player, motion node editor, validator).

---

## Section 8: Acceptance Criteria — Consolidated Reference Mapping

| # | Criterion | Ref Section | Milestone |
|---|-----------|-------------|-----------|
| 1 | Weapon list opens, weapon selectable | §2.1, §3.2 | ✅ DONE |
| 2 | Skill list opens, draft selectable | §2.1, §3.2 | ✅ DONE |
| 3 | Editor opens on correct weapon-owned draft | §3.2 | ✅ DONE |
| 4 | Existing draft restores correctly | §3.7 | ✅ DONE |
| 5 | New melee weapons get default baseline | §3.8 | M0 (update to motion-node baselines) |
| 6 | Motion node chain editable with compound fields | §3.12-3.13 | M0 + M1 |
| 7 | Q/E navigates motion nodes | §3.3 | M3 |
| 8 | R copies current node at same coords | §3.13.13 | M3 |
| 9 | T deletes current node, backward select | §3.3 | M3 |
| 10 | Space cycles tip↔pommel focus | §3.13.13 | M1 + M3 |
| 11 | Two Curve3D trajectories visible (tip + pommel) | §3.4, §3.13 | M2 |
| 12 | Trajectory plane visible and manipulable | §3.13.5 | M2 + M6 |
| 13 | Tip draggable on trajectory plane | §3.13.6 | M6 |
| 14 | Pommel draggable on sphere around tip | §3.13.7-3.13.8 | M6 |
| 15 | Weapon roll editable per node (±120°) | §3.13.4 | M1 |
| 16 | Axial reposition editable per node | §3.13.9 | M1 |
| 17 | Grip-seat slide editable per node | §3.13.10 | M1 |
| 18 | 4 Bézier handles per node (tip_in/out, pommel_in/out) | §3.13.5-3.13.8 | M0 + M2 |
| 19 | Onion skin: tip + pommel markers at neighbors | §3.5 | M5 |
| 20 | F preview: simultaneous tip + pommel playback | §3.6, §3.14 | M7 |
| 21 | Playback reusable outside editor | §3.6, §3.14 | M7 |
| 22 | Speed-state trajectory coloring | §3.5 | M8 |
| 23 | Validation: minimum nodes, protected first, degenerate handles | §3.9 | M9 |
| 24 | BakedProfile grip axis wired into editor | §3.13.1-3.13.3 | M9 |
| 25 | Exit auto-saves draft | §3.7 | ✅ DONE |
| 26 | Canonical skill slot ids (skill_slot_1–12) | §2.2.1, §3.9.1 | Stub exists, full law = TODO |

**Score**: 5 of 26 already done. All 21 remaining addressed by Milestones 0-9.

---

## Section 9: Grip Axis Derivation Chain (Verified Against Existing Code)

> Cross-referenced §3.13.1-3.13.3 against existing resolver code. All verified correct.

### Derivation Steps (existing code → BakedProfile fields)

| Step | Function | File | Line | Output |
|------|----------|------|------|--------|
| 1 | `_calculate_slice_center(slice_cells)` | anchor_resolver.gd | L381 | Averages CellAtom.get_center_position() → grip endcap center Vector3 |
| 2 | `_build_grip_span_from_candidate_chain(chain)` | anchor_resolver.gd | L325 | start_position, end_position from first/last candidate center_position |
| 3 | `build_primary_grip_anchor()` | anchor_resolver.gd | L34 | Sets span_start/end_local_position, local_axis on AnchorAtom |
| 4 | `resolve_primary_grip_contact_position()` | anchor_resolver.gd | L52 | Projects desired position onto grip axis span |
| 5 | `apply_primary_grip_profile()` | profile_primary_grip_resolver.gd | L14 | Copies to BakedProfile: contact_position, span_start/end, slide_axis, com_side/far_side, reach, front_heavy_score, balance_score, two_hand_eligible |

### Mapping: Consolidated Ref → BakedProfile Fields

| Ref Requirement | BakedProfile Field | Status |
|----------------|-------------------|--------|
| Grip axis direction (§3.13.1) | `primary_grip_slide_axis: Vector3` | ✅ Available |
| Grip endcap start (§3.13.1) | `primary_grip_span_start: Vector3` | ✅ Available |
| Grip endcap end (§3.13.1) | `primary_grip_span_end: Vector3` | ✅ Available |
| Dominant hand position (§3.13.3) | `primary_grip_contact_position: Vector3` | ✅ Available |
| COM-side extremity (§3.13.2) | `primary_grip_com_side_position: Vector3` | ✅ Available |
| Far-side extremity (§3.13.2) | `primary_grip_far_side_position: Vector3` | ✅ Available |
| Weapon total length (§3.13.2) | `weapon_total_length_meters: float` | ✅ **RESOLVED** — derivation in Section 10 |
| Weapon tip point (§3.13.2) | `weapon_tip_point: Vector3` | ✅ **NEW** — extremity plane ∩ grip axis, longer-from-hand side |
| Weapon pommel point (§3.13.2) | `weapon_pommel_point: Vector3` | ✅ **NEW** — extremity plane ∩ grip axis, shorter-from-hand side |
| Tip distance from hand (§3.13.2) | `weapon_tip_distance_meters: float` | ✅ **NEW** — hand→tip along grip axis |
| Pommel distance from hand (§3.13.2) | `weapon_pommel_distance_meters: float` | ✅ **NEW** — hand→pommel along grip axis |
| Center of mass (used for weight) | `center_of_mass: Vector3` | ✅ Available |
| Total mass (used for feel) | `total_mass: float` | ✅ Available |
| Front-heavy score | `front_heavy_score: float` | ✅ Available |
| Balance score | `balance_score: float` | ✅ Available |
| Two-hand eligible | `primary_grip_two_hand_eligible: bool` | ✅ Available |

**Result**: 11 of 12 existing fields already available. 5 new fields to add (see Section 10 for derivation algorithm).

---

## Section 10: weapon_total_length_calculated — Full Derivation Algorithm

> Resolved from user explanation (2026-04-12). This is the ONE new derivation needed in ProfilePrimaryGripResolver.

### Algorithm (step by step)

**Step 1 — Establish grip axis from furthest-apart endcap centers**
- Take all valid grip segment endcaps (there may be multiple grip sections)
- For each endcap: use existing `_calculate_slice_center(slice_cells)` → averages CellAtom.get_center_position() → endcap center Vector3
- Find the **two furthest-apart** endcap centers (handles multi-grip-section weapons)
- These two centers define the **grip axis line** and its **direction vector**
- _Already available_: `primary_grip_span_start`, `primary_grip_span_end`, `primary_grip_slide_axis` from existing resolver chain

**Step 2 — Find weapon extremity planes (tangent to model, perpendicular to grip axis)**
- Take ALL cells from the weapon model (Stage 1 crafting station output)
- Project every cell center position onto the grip axis line
- Find the **maximum** projection distance along the axis (one end of weapon)
- Find the **minimum** projection distance along the axis (other end of weapon)
- On each side: construct a `Plane` that is:
  - **Perpendicular** to the grip axis
  - **Tangent** to the furthest geometry the model has on that side
  - The plane "slides" along the grip axis until it touches the last possible point of the weapon
  - `weapon_total_length_plane_1 = Plane(grip_axis_direction, grip_axis_origin + grip_axis_direction * min_proj)`
  - `weapon_total_length_plane_2 = Plane(-grip_axis_direction, grip_axis_origin + grip_axis_direction * max_proj)`
- **Why perpendicular tangent planes**: No two weapons are the same. Geometry can be curved, asymmetric, irregular — millions of possible shapes from the crafting system. The grip axis provides orientation, the tangent planes capture max extent regardless of form. This is fully modular — no hardcoding for specific shapes.

**Step 3 — Calculate weapon_total_length_calculated**
- Distance along grip axis from plane_1 intersection point to plane_2 intersection point
- `weapon_total_length_meters = abs((extremity_max_projection - extremity_min_projection))` (float, meters)
- This is a scalar distance on the grip axis

**Step 4 — Determine tip vs pommel from dominant hand position**
- Take `primary_grip_contact_position` (already resolved — where the dominant hand sits)
- Project it onto the grip axis → `grip_axis_determined_current_dominant_hand_position_plane` (perpendicular plane at hand position)
- Calculate:
  - `distance_to_plane_1 = abs(hand_projection - extremity_1_projection)` (meters along axis)
  - `distance_to_plane_2 = abs(hand_projection - extremity_2_projection)` (meters along axis)
- The **longer** distance side (>=) is the **tip**
- The **shorter** distance side is the **pommel**

**Step 5 — Resolve tip and pommel points**
- `weapon_tip_point`: the intersection of the tip tangent plane with the grip axis line (projected extremity position on the longer side from hand)
- `weapon_pommel_point`: the intersection of the pommel tangent plane with the grip axis line (projected extremity position on the shorter side from hand)
- `weapon_tip_distance_meters`: distance from hand to tip along axis
- `weapon_pommel_distance_meters`: distance from hand to pommel along axis
- These are the two manipulation control points for the motion-node system — derived entirely from geometry, fully modular, adapts to any weapon shape

### New BakedProfile Fields (5)

```
weapon_total_length_meters: float        # plane_1 ↔ plane_2 distance along grip axis
weapon_tip_point: Vector3                # grip axis ∩ tip extremity plane
weapon_pommel_point: Vector3             # grip axis ∩ pommel extremity plane
weapon_tip_distance_meters: float        # hand → tip along grip axis (longer side)
weapon_pommel_distance_meters: float     # hand → pommel along grip axis (shorter side)
```

### Implementation Location

- **New function**: `_calculate_weapon_total_length()` in `profile_primary_grip_resolver.gd`
- **Inputs**: all cell centers (from segment geometry), grip axis (from existing span), hand contact position (from existing resolver)
- **Called from**: `apply_primary_grip_profile()` (after existing grip fields are set)
- **Estimated size**: ~30-40 lines

### Pseudocode

```gdscript
func _calculate_weapon_total_length(
    all_cells: Array,
    grip_axis_origin: Vector3,
    grip_axis_direction: Vector3,
    hand_contact_position: Vector3
) -> Dictionary:
    # Project all cells onto grip axis, find min/max
    var min_proj: float = INF
    var max_proj: float = -INF
    for cell in all_cells:
        var center: Vector3 = cell.get_center_position()
        var proj: float = grip_axis_direction.dot(center - grip_axis_origin)
        min_proj = minf(min_proj, proj)
        max_proj = maxf(max_proj, proj)
    
    var total_length: float = max_proj - min_proj  # meters
    
    # Extremity points on grip axis
    var extremity_1: Vector3 = grip_axis_origin + grip_axis_direction * min_proj
    var extremity_2: Vector3 = grip_axis_origin + grip_axis_direction * max_proj
    
    # Hand projection
    var hand_proj: float = grip_axis_direction.dot(hand_contact_position - grip_axis_origin)
    var dist_to_1: float = absf(hand_proj - min_proj)
    var dist_to_2: float = absf(hand_proj - max_proj)
    
    # Longer distance = tip, shorter = pommel
    var tip_point: Vector3
    var pommel_point: Vector3
    var tip_dist: float
    var pommel_dist: float
    if dist_to_2 >= dist_to_1:
        tip_point = extremity_2
        pommel_point = extremity_1
        tip_dist = dist_to_2
        pommel_dist = dist_to_1
    else:
        tip_point = extremity_1
        pommel_point = extremity_2
        tip_dist = dist_to_1
        pommel_dist = dist_to_2
    
    return {
        "weapon_total_length_meters": total_length,
        "weapon_tip_point": tip_point,
        "weapon_pommel_point": pommel_point,
        "weapon_tip_distance_meters": tip_dist,
        "weapon_pommel_distance_meters": pommel_dist,
    }
```

### Existing Code Reuse

| What | Source | Status |
|------|--------|--------|
| Grip endcap center calculation | `_calculate_slice_center()` at anchor_resolver.gd:L381 | ✅ Reused for Step 1 |
| Furthest-apart grip span | `_build_grip_span_from_candidate_chain()` at anchor_resolver.gd:L325 | ✅ Provides span_start/end |
| Grip axis direction | `primary_grip_slide_axis` in BakedProfile | ✅ Provides normalized axis vector |
| Hand contact position | `primary_grip_contact_position` in BakedProfile | ✅ Provides projection reference |
| All cell centers | Segment geometry passed through resolver chain | ✅ Available as input |
| Projection math | `Vector3.dot()` — Godot built-in | ✅ No helper needed |
| Perpendicular plane construction | `Plane(normal, point)` — Godot built-in | ✅ Used conceptually; actual code uses scalar projection |

### Relationship to Motion-Node System

- `weapon_total_length_meters` → pommel sphere radius (how far pommel can orbit around tip)
- `weapon_tip_point` → default tip position for new motion nodes
- `weapon_pommel_point` → default pommel position for new motion nodes
- `weapon_tip_distance_meters` → tip reach from hand (affects trajectory plane sizing)
- `weapon_pommel_distance_meters` → pommel reach from hand (affects counterweight feel)
- Tip/pommel identity is **deterministic from geometry** — the longer side from the hand is always "tip", no manual assignment needed

### Additional Motion-Node Context (from user explanation)

- The tip↔pommel axis supports ±120° rotation from model default (0° = south in perpendicular POV), in 1° increments via 3D viewport drag gizmo → this is the `weapon_roll_degrees` field on CombatAnimationMotionNode
- The tip is bound to `trajectory_plane` centered at player shoulder-spine center. The plane has a single-axis tilt gizmo. Tilting the plane moves the tip along the other 2 axes while staying on the plane surface. Player IK limitations apply.
