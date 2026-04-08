# Session Debugging Memory

## Purpose
This note runs in parallel with plan.md.

Use this file to track:
- current debugging targets
- symptoms and observed errors
- confirmed root causes
- attempted fixes and their outcomes
- wrong assumptions to avoid repeating
- workflow lessons that should affect future debugging

Do not use this file as the main task queue. plan.md remains the place for sequencing, checkpoints, and next-step planning.

## How This Works With The Other Notes
- plan.md: what we are trying to do next and why
- debugging.md: what is broken, what broke it, what fixed it, and what to avoid repeating
- audit_findings.md: larger completed audits with broader architectural conclusions
- repo memory: durable repository truths worth keeping beyond this session

## Debug Workflow
1. Capture the active symptom exactly.
2. Confirm whether it is a static/editor problem, a runtime problem, or a bad assumption problem.
3. Reproduce it with the smallest reliable path.
4. Record the actual root cause, not just the visible error.
5. Record the fix and how it was validated.
6. Record any false leads or assumptions that should not be repeated.
7. If the result changes project workflow, copy the durable part into repo memory.

## Current Debug Focus
### Runtime startup recovery - 2026-03-24
Status: fixed and revalidated.

Symptoms:
- Godot startup showed red runtime/load errors.
- Forge UI reported multiple node-not-found errors.
- A follow-on null assignment hit own_world_3d.
- First-run loading of the forge WIP library produced user:// file load errors.

What was wrong:
- PlayerForgeWipLibraryState.load_or_create() attempted to load the user save path even when the file did not exist yet.
- CraftingBenchUI had stale onready NodePaths that no longer matched the actual scene hierarchy.

Confirmed root causes:
- Missing first-run user save file was being treated like an error instead of normal initialization.
- The scene added wrapper nodes such as PlaneVBox, FreeVBox, DescriptionMargin, and StatsMargin, but the script paths still targeted the older structure.

Fixes applied:
- Added a file existence guard before loading the user forge WIP save.
- Updated CraftingBenchUI node paths to match the real scene tree.
- Re-ran headless Godot startup and confirmed the red startup errors were gone.

Validation:
- Touched files reported no editor errors after the patch.
- Headless startup no longer reported the earlier runtime blockers.

Do not repeat:
- Do not trust clean editor diagnostics as proof that runtime startup is healthy.
- Do not assume the script is wrong before comparing it against the current scene hierarchy.
- Do not treat a missing first-run user save file as exceptional if the correct behavior is to initialize empty state.

## Warning Cleanup Notes
### Forge warning pass - 2026-03-24
Status: cleaned in touched forge files.

What was wrong:
- Several midpoint calculations used int(value / 2), which is noisier and easier to misread in integer-only paths.
- ForgeWorkspacePreview used a local variable named transform, which shadowed Node3D.transform.

Fixes applied:
- Converted midpoint calculations in active forge files to integer midpoint expressions.
- Renamed the local transform variable to cell_transform.

Lesson:
- When warnings appear in active-path files, clean them while the related runtime context is already open, but keep them secondary to real startup blockers.

## Repeated Mistakes To Avoid
- Mixing planning notes and debugging notes in one file until neither stays useful.
- Recording only the visible error without the underlying cause.
- Forgetting to capture how a fix was validated.
- Repeating a failed assumption because it was never written down.

## Maintenance Rule

## Workflow Guardrail
### Menu implementation scope control - 2026-03-24
Status: active rule.

Problem:
- Large menu passes touching settings logic, input bootstrap, UI scene structure, and runtime behavior together increase the chance of VS Code/editor instability and make failures harder to isolate.

Rule:
- Break menu work into small vertical slices.
- Separate bootstrap fixes, settings persistence, keybinding logic, and shell/layout changes into different passes.
- Validate after each slice before moving to the next.

Do not repeat:
- Do not combine broad menu redesign and low-level runtime/input fixes in one large pass unless explicitly necessary.

When a meaningful debug cycle happens, add a short entry here with:
- date
- symptom
- root cause
- fix
- validation
- mistake to avoid next time
