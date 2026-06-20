# AGENT HANDOFF WORKFLOW LAW 2026-05-26

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

### Current Memory Hierarchy

This file predates SPS. Treat the current memory stack like this:

1. SPS = current user-facing resume slot.
2. Task-specific notes / ToDo files = active design direction and near-term implementation context.
3. Naming law = canonical terminology and id authority.
4. Exported knob registry = exported-field/search index authority.
5. Implementation memory = legacy long-form implementation archaeology and recovery context.

Rule:
- Read the newest SPS first for the active slice.
- Use code/verifiers as the strongest truth for what is live.
- Use implementation memory to understand past decisions, old seams, and recovery history.
- Do not bulk-append exploratory WIP into implementation memory by default.
- Update implementation memory only when the user asks, when a stable commit-grade addition needs long-term history, or when a recovery pass corrects old tracker drift.
- For current WIP handoff, prefer SPS plus the relevant ToDo/design note.

### 0. SPS current-session handoff

Folder:
- `GDD-and Text Resources/SPS/`

Filename format:
- `SPS_YYYY_MM_DD_HH-MM.md`

Meaning:
- SPS means "Save Project State".
- SPS is a durable session handoff / mental save slot.
- SPS is not a git commit, push, backup, or technical file save.
- SPS is user-facing first and agent-usable second.

Use for:
- the active vertical slice currently in the user's head
- what was done since the last SPS
- what was not reached
- what is true now
- the next narrow focus
- the first file / scene / thought-anchor to open next session
- what not to load yet

Create or update an SPS file when:
- the user says `SPS`
- the user says `save project state`
- the user asks for shutdown / handoff / resume memory
- context is getting too large and a durable pickup point is needed

Do not:
- treat SPS as implementation memory
- use SPS to claim code truth unless the SPS names the verified files/tests
- replace focused verifiers with SPS prose
- commit or push just because SPS was created
- broaden SPS into a whole-project recap unless the user asks

SPS required sections:
- Current Loaded Worldspace
- Previous SPS Plan
- Done Since Last SPS
- Planned Points Hit
- Planned Points Missed
- New Current State
- Next Focus
- First Click / First Action
- Do Not Load Yet

Rule:
- A new agent should read the newest SPS first to recover the active slice quickly.
- Then use naming law, knob registry, design docs, code, verifiers, and legacy implementation memory for deeper authority as needed.
- SPS preserves focus. Trackers preserve code/project truth.

SPS file hygiene:
- Create a new SPS file for each real handoff.
- Do not overwrite older SPS files to represent a newer session.
- Editing an older SPS is allowed only for typo fixes or clearly marked correction notes.
- The newest SPS by filename timestamp is the active resume slot.
- If chat and SPS disagree after a handoff, trust the newest SPS first, then inspect code/verifiers.
- SPS files may describe uncommitted WIP. Do not assume an SPS means the repo was committed or pushed.

SPS detail level:
- Keep SPS narrow to the active vertical slice.
- Include enough context for a long gap, not only tomorrow-level memory.
- Prefer exact files, scenes, scripts, nodes, test names, and first action anchors.
- Mark unknowns clearly instead of inventing missing project truth.
- Put "do not load yet" boundaries in every SPS so future work does not sprawl.

SPS and git:
- SPS is not a save-state commit.
- Creating SPS does not imply `git add`, `git commit`, or `git push`.
- Git remains a separate functioning-code snapshot only when the user explicitly requests it.

### 1. Legacy implementation memory / historical state tracker

File:
- [CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/CURRENT%20STATE%20OF%20THE%20WILL%20-%20IMPLEMENTATION%20MEMORY.md)

Use for:
- historical implementation context
- old code seams and why they exist
- verified legacy claims that may still be useful
- recovery notes when tracker drift is discovered
- stable implementation additions that must outlive SPS

Update this file when:
- the user explicitly asks for implementation memory to be updated
- a stable / commit-grade subsystem addition should become long-term historical record
- a major live seam is replaced and the old historical reading would mislead future work
- a verification result proves an older implementation-memory claim is wrong
- a recovery pass reconstructs missing code truth from committed work

Entry format should always include:
- date
- what changed
- focused verification now on record
- honest boundary

Do not:
- treat this as the first-load resume surface for current WIP
- append every exploratory V2 slice by default
- write marketing summaries
- hide regressions
- copy old claims forward if fresh verifier truth contradicts them

### 2. Exported knob registry

File:
- [LIVE_EXPORTED_KNOB_REGISTRY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/LIVE_EXPORTED_KNOB_REGISTRY.md)

Use for:
- live / stabilized exported vars
- search/index terms
- where knobs live
- subsystem lookup by name

Update this file when:
- new `@export` / `@export_range` / `@export_multiline` fields become part of the live/stabilized surface
- canonical input/action ids are added or renamed
- new subsystem search terms become important
- a major authoring branch gains new live fields
- snapshot counts need refresh after a large sweep

Do not:
- use this file for semantic naming law
- force registry churn for disposable WIP scaffolding unless the user asks
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
- use naming law as a session recap; use SPS for that

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
- SPS / task-specific design note for current WIP handoff
- implementation memory only for stable long-term history, explicit user request, or recovery correction
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

- current WIP behavior / implementation = SPS plus task-specific note
- stable long-term behavior / implementation = legacy implementation memory when needed
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

## Handoff Law Supersession

This file may be renamed forward when the workflow law changes materially.

Rules:
- The newest dated `AGENT_HANDOFF_WORKFLOW_LAW_YYYY-MM-DD.md` is the active handoff law.
- If the file is renamed forward, update the internal title to match the filename date.
- Search for stale references to the older handoff-law filename and update them when practical.
- Do not keep duplicate active handoff-law files with different dates unless one is explicitly marked archived/superseded.
- Older handoff-law filenames should be treated as superseded historical artifacts, not parallel authority.

## Large Commit Recovery Law

If the agent is reconstructing history from committed work:

1. identify the commit/range exactly
2. cross-reference against newest SPS first if it exists
3. cross-reference against implementation memory for legacy history
4. do not relog sections already represented later
5. only add genuinely missing subsystem truths
6. ignore noise:
  - `.uid`
  - `.godot`
  - raw logs
  - test artifacts
  - result txt snapshots by themselves

## Token Scarcity Law

If context or tokens are running low:

- stop expanding feature scope
- spend remaining room on:
  - newest SPS handoff
  - recovery savepoint
  - naming/knob corrections
  - implementation memory only if the user explicitly needs legacy tracker correction

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

## Post-Work Honest View

After each meaningful work clump, the agent should give the user a compact honest view.

This is not SPS.
This is not implementation memory.
This is the immediate thinking platform for the user to bounce off while the current slice is still loaded.

Required shape:
- what changed
- what did not change
- what was verified
- what remains uncertain
- what is best to do next

The "best next" part should be more detailed than the rest:
- name the exact next narrow slice
- explain why that slice is the best next move
- name the first file / system / scene to touch
- name the smallest useful verification
- call out what should not be pulled into that next slice yet

Purpose:
- help the user correct direction before more code is built
- expose hidden assumptions early
- invite better user context and sharper prompting
- prevent later system rewrites caused by vague next steps
- support snowballing design refinement without turning the whole project into a broad planning session

Do not:
- bury the honest view in a long recap
- inflate "next" into a full roadmap unless the user asks
- describe speculative future systems as if they are already decided
- skip uncertainties just because the change compiled
- end meaningful work with only "done" if the next direction is not obvious

## Hard Failure Conditions

The agent failed the workflow if it:

- made meaningful code changes without updating the tracker layer
- renamed live concepts without updating naming law
- added exported knobs without updating the registry
- claimed verification without rerunning relevant verifiers
- let a newer system coexist with old wording without marking what is legacy

## Practical Restart Order For Any New Agent

Before doing work, read in this order:

1. newest `GDD-and Text Resources/SPS/SPS_*.md` file, if one exists
2. the `First Click / First Action` target named by that SPS
3. task-specific ToDo/design note named by that SPS, if present
4. code around the active files before trusting old tracker prose
5. [NAMING_LAW.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/NAMING_LAW.md), only when naming/ids/semantic terms are involved
6. [LIVE_EXPORTED_KNOB_REGISTRY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/LIVE_EXPORTED_KNOB_REGISTRY.md), only when live exported knobs/search indexes are involved
7. [CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/CURRENT%20STATE%20OF%20THE%20WILL%20-%20IMPLEMENTATION%20MEMORY.md), when historical context or recovery archaeology is needed
8. [REPO_ALIGNMENT_RECOVERY_SAVEPOINT_2026-04-13.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/REPO_ALIGNMENT_RECOVERY_SAVEPOINT_2026-04-13.md), when tracker drift/recovery context is relevant
9. broader design docs only after the active slice is loaded

## Final Rule

Do not make future cleanup necessary on purpose.

If the agent touches the codebase, it must leave the repo easier to resume than it found it.
