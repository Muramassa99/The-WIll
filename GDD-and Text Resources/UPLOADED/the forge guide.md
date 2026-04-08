Yes.
Here is the **agent-ready Forge UI implementation instruction block** for **Godot 4.6.1**, rewritten around your **new drawing as authority**, not the older shell shorthand.

        !!!!!!!!     IMPORTANT      NOTE       !!!!!!!


 this guide makes reference  to the image  found in :

"GDD-and Text Resources\crafting menu how it is supposed to look like.png"




This version is anchored to:

* the current code reality: the first forge slice is already live enough to bake WIPs, show a bench-side preview mesh, and run through the resolver/service/profile path, but the current bench editor is still provisional and not the intended final forge station surface. 
* the active first-slice laws: materials → cells → profiles → test prints, sandbox only; gameplay reads `BakedProfile`, not raw cells; `CraftedItemWIP` remains a pure data model; baking lives in `ProfileResolver` + `ForgeService`. 
* the Forge identity: materials are universal truth, raw cells are authoring truth, baked profile is gameplay truth, and the four sacred classes must never collapse.

---

# THE WILL — Forge Station UI Implementation Brief

## Godot 4.6.1 / VS Code GPT 5.4 Agent-Ready

## 1. Core instruction

Implement the **real Forge station interface**, not a placeholder menu.

This UI must become the next honest authoring surface for the already-live first forge slice. It must sit on top of the existing resolver/service/WIP/bake/test-print truth stack and must not fake systems that are not yet implemented. The current temporary bench editor is only a provisional harness and must be replaced by the structure described below, not extended by inertia.

---

## 2. Non-negotiable laws

### 2.1

There is **one authored object**.

Sections **7** and **8** are not separate systems.
They are two synchronized viewports looking at and editing the **same `CraftedItemWIP`**.

### 2.2

The workflow law remains:

**player authors matter → Forge resolves matter into baked profile → gameplay/test systems read baked profile**

Do not let gameplay/test-print logic read raw cells directly once a baked profile exists.

### 2.3

The four sacred classes remain separate:

* `ForgeMaterialStack`
* `CraftedItemWIP`
* `TestPrintInstance`
* `FinalizedItemInstance`

### 2.4

This slice is still sandbox/forge-first:

* no combat integration
* no economy/trading flow
* no multiplayer
* no full behavior-template system yet
* no broader page/context systems yet 

### 2.5

Materials are universal truth.
Paint/skin/finish is a later **aesthetic layer** and must not alter structural math. Material truth and appearance truth must remain separate. 

---

## 3. The actual UI layout to build now

Use the user’s latest sketch as authority.

### Right side = material side

Contains:

* **1** Material inventory container
* **5** Material entries inside inventory
* **6** Search/filter field
* **2** Material description tab/panel
* **3** Material data/stat panel

### Center = object side

Contains:

* **7** free 3D viewport
* **8** plane-locked viewport
* **11** orientation gizmo inside 7
* shared object editing context
* shared object visualization context

### Left side = editing support side

Contains:

* **9** ghost / remaining-capacity visualization context
* **10** active layer indicator
* **12** tool category strip
* **13** current tool palette
* edit-support and layer-support controls

### 14 = dropdown action host

A grouped menu area for:

* viewport options
* geometry/surface operations
* bake/save/workflow commands
* later export/finalization commands

Do not reinterpret this layout back into the older left-material shell.
The new drawing has priority.

---

## 4. Material-side behavior

## 4.1 Section 1 — Material inventory

This shows processed forge materials, not raw world drops. Processed stacks already exist conceptually and in current code as `ForgeMaterialStack`.

Inventory must support:

* owned materials
* optional visibility of non-owned materials
* category/sort/filter views
* search narrowing

Default mode:

* hide non-owned materials unless the current filter says otherwise

## 4.2 Section 5 — Material entry behavior

Each visible material entry in the inventory must support **three roles at once**:

### A) inspection source

When selected, it populates:

* **2** material description
* **3** material stat/data view

### B) active deposit payload

If `quantity >= 1`, selecting it also arms it as the active material for placement/editing in **7** and/or **8**

### C) toggle selection

Selecting the already-selected entry again cancels active deposit state

### Exact law

* if quantity `>= 1`: selectable + readable + placeable
* if quantity `= 0`: selectable + readable, but **not placeable**

The slot should visually indicate:

* selected
* owned/usable
* depleted/unusable
* maybe hovered

## 4.3 Section 6 — Search bar

This is **only** a filter box.

It behaves like `Ctrl+F`:

* narrows visible entries in **1**
* hides non-matching entries
* does not reveal source info
* does not populate descriptions
* does not perform gameplay hint logic

All “where do I get this” information comes from selecting an entry and reading **2**.

## 4.4 Section 2 — Material description

This is the human-readable material explanation panel.

It should show:

* what the material generally is
* what it is good at / bad at
* rough use-case notes
* acquisition/source text

This information must be visible whether or not the material is currently owned, as long as the player can select the entry.

## 4.5 Section 3 — Material data dump

This is the player-facing numeric/stat readout.

It should show selected material payload in stat language, using the approved stat-id vocabulary and material truth chain already present in the project. 

Examples:

* attack-related values
* defense-related values
* crit values
* attack speed / move penalties
* heal values
* capability bias hints if exposed to players
* special support flags if intentionally player-visible

Do not invent a second hidden payload here.
This should be a read model built from the selected material definition / resolved variant stats.

---

## 5. Object-side behavior

## 5.1 Shared object law

Sections **7** and **8** display the same current authored object:

* same `CraftedItemWIP`
* same layer state
* same plane state
* same selected material
* same active tool
* same placements and removals

Any edit in one view updates the other.

## 5.2 Section 7 — Free 3D viewport

This is the orbit/spectator/spatial view.

Responsibilities:

* rotate/orbit around the object
* zoom in/out within safe limits
* pan within defined limits if needed
* inspect object from any angle
* show grid on/off
* show ghosted adjacent layers
* show/hide anchors later
* show center-of-mass marker later
* allow editing on the same shared object

This viewport is not just a preview pane.
It is one valid editing portal into the same authored object.

## 5.3 Section 8 — Plane-locked viewport

This is the same shared object, viewed through a plane-locked camera.

Responsibilities:

* provide faster, clearer placement/editing on the currently selected plane
* remain synchronized with section 7
* obey current plane selection (`XY`, `ZX`, `ZY`)
* obey current active layer

This view should feel like “editing a slice of the same real object,” not like a separate 2D sub-editor.

## 5.4 Section 11 — Orientation gizmo

Inside viewport 7:

* show world/object orientation
* remain fixed in viewport corner
* reflect object rotation context
* double-click/snap interaction may switch 7 to direct axis views

This is a helper only.
It must not silently change the authored object.

---

## 6. Layer and capacity behavior

## 6.1 Section 10 — current layer

This must always make the active layer obvious.

It should display:

* current layer index
* maybe max layer count
* maybe current plane + layer together

This state must drive both 7 and 8.

## 6.2 Section 9 — ghost capacity / aura visualization

This is a visualization of remaining legal placement space around the current build.

It represents:

* current fill usage
* remaining placement allowance
* shrinking legal growth room as the player approaches cap

Important law:
**Section 9 is visual only.**
It does not compute legality by itself.

Backend legality still comes from:

* occupancy
* fill cap
* layer rules
* connectivity
* other WIP constraints

Section 9 visualizes that legality truth.

For first implementation, it is acceptable to start with:

* simple ghost volume / legal area visualization
* numeric budget indicator

and evolve later toward the full shrinking aura behavior.

---

## 7. Tool and action behavior

## 7.1 Section 12 — tool categories

This selects the current action family.

Examples:

* brush tools
* placement tools
* erase tools
* deformation/shape tools
* favorites/custom
* plane selector (`XY`, `ZX`, `ZY`)

This area controls **mode family**, not the exact active brush.

## 7.2 Section 13 — active tool palette

This displays the exact usable tools for the selected category.

Examples:

* single-place
* line
* fill
* multi-box brush
* erase
* selection brush
* later symmetry-aware tools

Clicking here changes the active tool used in **7** and **8**.

## 7.3 Section 14 — dropdown action host

Section 14 is a grouped menu host.

It should contain dropdowns/submenus for:

* viewport/display actions
* geometry/surface actions
* workflow actions

Examples:

* show grid
* hide grid
* show ghost layers
* bevel
* chamfer
* round
* save WIP
* bake
* reset
* blueprint save later
* export/finalize later

Do not flatten these into one clutter row.

---

## 8. Mouse rules inside the Forge

These are the **menu-local Forge rules**, separate from overworld movement. Current runtime already supports UI mode that releases mouse capture and halts player movement while interface is open, so the Forge can safely define its own mouse behavior.

## 8.1 Global UI mouse rules

* when Forge UI opens: player movement is halted, mouse is released, Forge input context becomes active
* when Forge UI closes: gameplay input context resumes

## 8.2 Inventory mouse rules

* **LMB on material entry**:

  * select entry
  * populate 2 and 3
  * if quantity `>= 1`, arm it as active deposit material
  * if same selected entry is clicked again, unarm/deselect
* **Mouse wheel over inventory**: scroll inventory content
* **LMB on filter tab**: switch inventory view mode
* **LMB in search box**: focus search field

## 8.3 Viewport mouse rules — shared idea

Both 7 and 8 are edit portals into the same object.

### Suggested default

* **LMB in viewport on valid target**:

  * place active material if one is armed and quantity `>= 1`
  * or perform active tool action
* **RMB in viewport**:

  * remove cell / perform erase action
* **MMB drag**:

  * pan camera if supported in that viewport
* **Mouse wheel**:

  * zoom in/out for the hovered viewport
* **Shift + LMB drag**:

  * continuous paint / brush stroke, if active tool supports dragging
* **Ctrl + LMB**:

  * sample/pick existing cell material under cursor, if tool mode supports eyedropper behavior
* **Alt + LMB**:

  * temporary alternate action if needed later, but do not force it in first build unless required

## 8.4 Viewport 7 specific

* **RMB drag** or **hold orbit modifier + mouse move**:

  * orbit around object
* camera must stay within defined zoom/orbit limits
* object can rotate for inspection if that is the chosen implementation pattern, but do not decouple this from spatial orientation helpers

## 8.5 Viewport 8 specific

* camera remains locked to chosen plane
* same editing actions as 7
* optimized for clear planar placement

---

## 9. Forge-specific keybinding profile

These should be **default bindings**, not hard-coded forever. All Forge bindings should be customizable later, consistent with your broader keybinding philosophy. The general project already leans toward high input density and full customizability.

### Core Forge defaults

* `Esc` = close Forge / return from current dropdown / cancel focus
* `Enter` = Bake
* `R` = Reset current WIP to last stable state / current preset baseline
* `Ctrl+S` = save WIP
* `Ctrl+Shift+S` = save-as / later blueprint save
* `F` = toggle grid visibility
* `G` = toggle ghost layer/capacity overlay
* `T` = cycle active tool category
* `Tab` = cycle major Forge focus region (inventory → viewport → tool area → info area)

### Layer controls

* `Q` = layer down
* `E` = layer up
* `Shift+Q` = jump down by larger step (optional)
* `Shift+E` = jump up by larger step (optional)

### Plane controls

* `1` = XY plane
* `2` = ZX plane
* `3` = ZY plane

### View controls

* `Home` = fit object in viewport
* `X` = snap viewport 7 to X-facing orthographic view
* `Y` = snap viewport 7 to Y-facing orthographic view
* `Z` = snap viewport 7 to Z-facing orthographic view

### Tool quick select

These are suggestions only; only wire the ones actually implemented:

* `B` = brush/place tool
* `V` = fill tool
* `C` = line/paint stroke tool
* `D` = erase tool
* `M` = mirror toggle / symmetry menu
* `H` = hide/show non-active layers
* `P` = pick material from selected/hovered cell

### Workflow

* `Space` inside Forge should **not** trigger world jump while UI is open
* `WASD` inside Forge should **not** move player while UI is open
* if viewport 7 uses keyboard camera navigation at all, it must be explicitly menu-scoped and not leak back into player controls

---

## 10. Data flow the agent must respect

### Material side

* inventory entries come from `ForgeMaterialStack`
* stack points to `material_variant_id`
* resolver/path maps variant → base material truth + tier-modified stats as needed
* selecting entry builds a UI-facing material view model for sections 2 and 3

### Authoring side

* placement/removal actions modify the active `CraftedItemWIP`
* `CraftedItemWIP` remains pure data; no bake logic inside it 
* layer changes update `current_layer_index`
* cell placement must use `material_variant_id`, not direct resource refs, consistent with current mochi law. 

### Bake side

* UI requests bake through `ForgeGridController`
* `ForgeGridController` calls `ForgeService`
* `ForgeService` orchestrates segment → anchor → profile → capability resolution
* latest baked snapshot may be stored on WIP for workflow convenience
* preview/test mesh updates from `TestPrintInstance` / display cells, not directly from the UI pretending geometry truth.

---

## 11. Godot 4.6.1 implementation structure

Keep scene/controller/service responsibilities clean.

### Recommended scene split

* `crafting_bench_ui.tscn` = root Control for Forge UI shell
* `forge_inventory_panel.tscn`
* `forge_material_info_panel.tscn`
* `forge_tool_panel.tscn`
* `forge_free_viewport_panel.tscn`
* `forge_plane_viewport_panel.tscn`
* `forge_status_panel.tscn`

### Recommended controllers

* `crafting_bench_ui.gd` = top-level UI orchestrator only
* `forge_inventory_controller.gd`
* `forge_selection_controller.gd`
* `forge_viewport_controller.gd`
* `forge_plane_view_controller.gd`
* `forge_tool_controller.gd`
* `forge_layer_controller.gd`
* `forge_actions_menu_controller.gd`

### Strong rule

Do not move bake/profile/material truth into panel scripts.
Panel scripts should request actions, reflect state, and render outputs. Truth still lives in the model/resolver/service path already established.

---

## 12. What the agent must not do

* do not reinterpret 7 and 8 as separate authoring systems
* do not move material inventory back to the left side
* do not make search (6) into a hint/lore engine
* do not let section 9 decide placement legality
* do not compute center of mass or profile values in the viewport/UI layer
* do not merge `ForgeMaterialStack`, `CraftedItemWIP`, `TestPrintInstance`, `FinalizedItemInstance`
* do not broaden into combat/economy/behavior-template systems while building this UI slice
* do not treat the current temporary bench shape as final if it conflicts with this clarified Forge definition.

---

## 13. Acceptance criteria

The implementation is correct only if:

1. selecting a material entry updates 2 and 3
2. selecting an owned material arms it for placement
3. selecting it again cancels active deposit state
4. quantity `0` materials remain readable but not placeable
5. 7 and 8 both edit the same WIP and stay synchronized
6. plane selection and layer selection affect both viewports consistently
7. search only filters inventory visibility
8. bake still runs through existing `ForgeGridController` → `ForgeService` path
9. preview/test path still respects the baked-profile authority split
10. the station feels like a workshop, not a bag menu or debug slab

---

## 14. One-sentence style lock

Build this as a **real Forge workstation for authoring matter**, not as a prettier version of the current temporary bench editor.

