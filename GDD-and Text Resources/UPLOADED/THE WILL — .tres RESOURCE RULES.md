THE WILL — .tres RESOURCE RULES
Godot 4.6.1

CORE PRINCIPLE

Use `.tres` for **definitions, templates, and tuning data**.
Do NOT use shared `.tres` files as live mutable gameplay/session state.

Meaning:
- `.tres` = “what a thing is by default”
- runtime state = “what this specific thing is doing right now”
- save data = “what this player/session changed over time”

If a value is expected to be edited during play, per player, per session, or per instance, it must NOT live as a shared project `.tres` unless it is duplicated into an isolated runtime copy first.

--------------------------------------------------
1) WHAT BELONGS IN `.tres`
--------------------------------------------------

A `.tres` is correct when the data is:

1. AUTHORED DEFINITION DATA
   Data that designers/devs create ahead of time and many systems read.
   Examples:
   - BaseMaterialDef
   - TierDef
   - MaterialVariantDef
   - ProcessRuleDef
   - FloorDifficultyProfile
   - EnemyArchetypeDef
   - CapabilityThresholdDef
   - ToolDef
   - BrushDef
   - UI config/layout defaults
   - default balance/tuning values
   - default station rules
   - default loot table definitions
   - default skill/ability templates

2. TEMPLATE DATA
   Data used as a blueprint for creating runtime instances.
   Examples:
   - AbilityTemplate
   - DotProfile
   - Forge tool preset
   - default WIP template shape
   - default viewport config
   - default keybinding preset

3. STATIC LOOKUP DATA
   Data that should be referenced by ID and not mutated during normal play.
   Examples:
   - category definitions
   - rarity colors
   - enum-like mappings
   - slot rules
   - stat metadata
   - codex entry definitions

4. TUNING / BALANCE DATA
   Numbers that must stay editable without changing code.
   Examples:
   - town caps
   - floor caps
   - occupancy thresholds
   - damage coefficients
   - salvage ratios
   - forge fill percentages
   - timer lengths
   - threat coefficients

--------------------------------------------------
2) WHAT MUST NOT LIVE AS SHARED `.tres`
--------------------------------------------------

Do NOT store these as shared project `.tres` resources:

1. LIVE SESSION STATE
   Anything changing moment-to-moment while the player is using the game.
   Examples:
   - hovered cell
   - selected tool
   - selected material
   - current layer index
   - active viewport mode
   - temporary validation state
   - current bake result cache
   - current preview mesh state
   - open dropdown state
   - mouse interaction state

2. PER-PLAYER / PER-INSTANCE MUTABLE OBJECT STATE
   Anything unique to one player, one forge session, one test print, one floor run, or one item instance.
   Examples:
   - current CraftedItemWIP contents
   - current ForgeMaterialStack quantity if tied to player inventory
   - current TestPrintInstance state
   - active floor enemies and their HP
   - current town occupancy
   - current inventory counts
   - durability on a specific item
   - current ownership/provenance history on an instance

3. NODE / SCENE RUNTIME REFERENCES
   Never store runtime scene references as static project `.tres` truth.
   Examples:
   - Node references
   - viewport references
   - scene tree state
   - live player references
   - active controller state

--------------------------------------------------
3) CONDITIONAL RULE — WHEN A RESOURCE IS OKAY AT RUNTIME
--------------------------------------------------

A Resource can be used at runtime IF one of these is true:

A. It is treated as READ-ONLY definition data.

B. It is duplicated/cloned before mutation, and the clone is treated as isolated runtime state.

C. It is created specifically as per-save / per-player data and is not shared as a project definition resource.

Important:
Project-authored `.tres` files inside the content library are assumed SHARED and IMMUTABLE at runtime unless explicitly duplicated.

--------------------------------------------------
4) HARD LAW: NEVER MUTATE SHARED DEFINITIONS
--------------------------------------------------

If a script loads a project `.tres` definition, it must treat it as immutable.

Bad:
- loading `BaseMaterialDef.tres`
- changing one of its values during play
- accidentally changing behavior for every future user of that resource

Correct:
- read from `BaseMaterialDef.tres`
- create runtime state separately
- or duplicate the resource before editing if that resource type is intended to become instance-local

--------------------------------------------------
5) HOW TO DECIDE: 5-QUESTION TEST
--------------------------------------------------

Before making something a `.tres`, ask:

1. Is this data authored ahead of time?
2. Should many systems read the same data the same way?
3. Is it mostly static during play?
4. Should changing it rebalance or redefine content globally?
5. Would it be dangerous if one player's/session's edits changed the base value for everyone?

If answers are mostly YES -> `.tres` definition is correct.
If answers are mostly NO -> this belongs in runtime state, save data, or an instance model.

--------------------------------------------------
6) THE WILL-SPECIFIC CLASSIFICATION
--------------------------------------------------

A) DEFINITELY `.tres`
- BaseMaterialDef
- TierDef
- MaterialVariantDef
- ProcessRuleDef
- FloorDifficultyProfile
- stat metadata / stat dictionary defs
- loot table defs
- ability templates
- dot profiles
- brush/tool defs
- forge UI config defs
- capability threshold defs
- default keybinding preset
- enemy archetype defs
- tuning configs

B) DEFINITELY NOT SHARED `.tres`
- current CraftedItemWIP being edited in a live session
- current selected material/tool/layer
- hovered/selected cell state
- current forge UI interaction state
- current inventory quantities
- current active test print
- current runtime preview state
- current town/floor occupancy live state
- current player-specific unlocked/owned counts if they change during play

C) ALLOWED ONLY AS DUPLICATED / INSTANCE DATA
- per-player WIP save objects
- per-player saved blueprints
- finalized item instances
- per-player forge session snapshot
- saved inventory instance records

These may use Resource-based data structures if helpful, but they must be treated as INSTANCE DATA, not shared authored definitions.

--------------------------------------------------
7) CODING RULES THE AGENT MUST FOLLOW
--------------------------------------------------

RULE 1
Scripts consume definition data from `.tres`.
Scripts do not silently recreate the same definitions as hardcoded constants.

RULE 2
Shared project `.tres` resources are read-only at runtime.

RULE 3
If runtime needs to modify something that came from a `.tres`,
duplicate it first or convert it into a runtime model.

RULE 4
Save files should prefer:
- stable IDs
- quantities
- references
- instance state
rather than copying whole definition resources unless intentionally saving an instance resource.

RULE 5
Keep a strict split between:
- Def = static definition
- State = live mutable runtime
- Save = persistent player/session instance data

RULE 6
If the thing can be changed by the player during a session, assume it is NOT a shared `.tres` definition.

RULE 7
If the thing is a global tuning knob or authored content definition, prefer `.tres` over hardcoding.

RULE 8
Do not put scene-tree behavior inside definition resources.
Resources define data. Controllers/services perform behavior.

--------------------------------------------------
8) SIMPLE MENTAL MODEL
--------------------------------------------------

Use `.tres` for:
- “what this kind of thing is”

Use runtime state for:
- “what this specific thing is doing right now”

Use save data / instance objects for:
- “what this specific thing became over time”

--------------------------------------------------
9) ONE-SENTENCE STYLE LOCK
--------------------------------------------------

In The Will, `.tres` files define truth, templates, and tuning; they do not act as shared live session memory unless explicitly duplicated into isolated instance data first.