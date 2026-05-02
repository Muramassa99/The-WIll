# AGENT HANDOFF WORKFLOW LAW 2026-04-13

## Purpose

This file exists so any other coding agent can join the repo without creating tracker drift, naming drift, or undocumented implementation churn.

This is the working law:

- code work is not complete until the tracking layer is updated
- no silent implementation
- no “I’ll log it later”
- no mixing design intent and code truth into one vague summary

## Non-Negotiable Rule

Every meaningful implementation slice must leave behind all three:

1. code truth
2. verifier truth
3. tracker truth

If one of those three is missing, the work is incomplete.

## Core Tracker Files

### 1. Implementation state tracker

File:
- [CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/CURRENT%20STATE%20OF%20THE%20WILL%20-%20IMPLEMENTATION%20MEMORY.md)

Use for:
- what changed in implementation
- what files matter
- what was verified
- what is still honestly unfinished
- recovery notes when drift is discovered

Update this file when:
- behavior changed
- a new subsystem was added
- a major seam was replaced
- a verification result changed the honest reading of the system
- a previously claimed behavior is no longer true

Entry format should always include:
- date
- what changed
- focused verification now on record
- honest boundary

Do not:
- write marketing summaries
- hide regressions
- copy old claims forward if fresh verifier truth contradicts them

### 2. Exported knob registry

File:
- [LIVE_EXPORTED_KNOB_REGISTRY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/LIVE_EXPORTED_KNOB_REGISTRY.md)

Use for:
- exported vars
- search/index terms
- where knobs live
- subsystem lookup by name

Update this file when:
- new `@export` / `@export_range` / `@export_multiline` fields are added
- canonical input/action ids are added or renamed
- new subsystem search terms become important
- a major authoring branch gains new live fields
- snapshot counts need refresh after a large sweep

Do not:
- use this file for semantic naming law
- leave major new live knobs undocumented

### 3. Naming law

File:
- [NAMING_LAW.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/NAMING_LAW.md)

Use for:
- exact meaning of terms
- canonical ids
- ambiguous-word resolution
- class/type/family naming rules

Update this file when:
- a new naming family appears
- a term can mean two things
- a legacy term remains in code but must be redefined precisely
- a branch changes from one conceptual model to another
  - example: `point` -> `motion node`
- canonical ids are introduced
  - example: `skill_slot_1` through `skill_slot_12`

Do not:
- leave old terminology active without marking it legacy
- let UI wording and code wording drift apart without noting it

## Design / Spec Files

### Skill / combat creator design

File:
- [SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md)

Use for:
- combat animation creator design law
- motion-node workflow law
- skill slot law
- authored control meaning

Update this file when:
- the user clarifies design intent
- workflow inputs change
- authored-control meaning changes
- slot law changes

Do not:
- use this as implementation memory
- use this to claim code already exists unless verified

### Recovery / restart anchor

File:
- [REPO_ALIGNMENT_RECOVERY_SAVEPOINT_2026-04-13.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/REPO_ALIGNMENT_RECOVERY_SAVEPOINT_2026-04-13.md)

Use for:
- tracker drift recovery
- restart after context loss
- cross-reference against large historic commits

Update this file when:
- a new recovery pass happens
- a large unlogged commit is being reconstructed

## Per-Turn Workflow Law

For any meaningful task, the agent must do this in order:

1. inspect current code first
- do not assume tracker text is still right
- do not assume older summaries are current

2. check whether this is a Godot task
- if yes, check official Godot docs first unless this exact pattern is already intentionally waived

3. implement the change

4. run focused verifiers
- rerun the verifiers closest to the touched subsystem
- do not claim green without evidence

5. update the tracker layer in the same turn
- implementation memory
- knob registry if relevant
- naming law if relevant
- design/spec file if user clarified design truth

6. report honest boundaries
- what works
- what was not tested
- what is still wrong

## Verification Law

The agent must distinguish these clearly:

- `verified in current run`
- `not rerun, assumed unaffected`
- `known stale / uncertain`

Never present:
- stale verifier truth as current truth
- old optimism as current validation

If a fresh rerun contradicts an older tracker claim:
- update the tracker
- mark the old claim superseded

## Anti-Drift Law

If the agent changes:
- behavior
- ids
- exported knobs
- workflow inputs
- authored-unit terminology

then the agent must update the matching tracker file immediately.

Mapping:

- behavior / implementation = implementation memory
- exported/searchable knobs = knob registry
- naming / ids / semantic meaning = naming law
- design/workflow clarification = design/spec file

## Legacy vs Live Law

When a system migrates:
- do not silently overwrite the old concept
- explicitly mark:
  - live truth
  - legacy truth
  - compatibility wording still left in code/verifiers

Example:
- `CombatAnimationPoint` may remain in repo
- `motion node` is the live authored-chain truth

## Large Commit Recovery Law

If the agent is reconstructing history from committed work:

1. identify the commit/range exactly
2. cross-reference against implementation memory first
3. do not relog sections already represented later
4. only add genuinely missing subsystem truths
5. ignore noise:
  - `.uid`
  - `.godot`
  - raw logs
  - test artifacts
  - result txt snapshots by themselves

## Token Scarcity Law

If context or tokens are running low:

- stop expanding feature scope
- spend remaining room on:
  - implementation memory
  - recovery savepoint
  - naming/knob corrections

If forced to choose:
- preserving alignment beats adding one more feature

## Required Writing Style

The agent should write tracker entries like this:

- what changed
- files involved
- focused verification now on record
- honest boundary

The agent should not write:

- vague “everything is working”
- future promises written as present truth
- blended design/code language that hides whether something is live

## Hard Failure Conditions

The agent failed the workflow if it:

- made meaningful code changes without updating the tracker layer
- renamed live concepts without updating naming law
- added exported knobs without updating the registry
- claimed verification without rerunning relevant verifiers
- let a newer system coexist with old wording without marking what is legacy

## Practical Restart Order For Any New Agent

Before doing work, read in this order:

1. [REPO_ALIGNMENT_RECOVERY_SAVEPOINT_2026-04-13.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/REPO_ALIGNMENT_RECOVERY_SAVEPOINT_2026-04-13.md)
2. [CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/CURRENT%20STATE%20OF%20THE%20WILL%20-%20IMPLEMENTATION%20MEMORY.md)
3. [NAMING_LAW.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/NAMING_LAW.md)
4. [LIVE_EXPORTED_KNOB_REGISTRY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/LIVE_EXPORTED_KNOB_REGISTRY.md)
5. task-specific design docs after that

## Final Rule

Do not make future cleanup necessary on purpose.

If the agent touches the codebase, it must leave the repo easier to resume than it found it.
