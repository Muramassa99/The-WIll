# Skill Crafter grip chronology

Two runners use the same chronology recorder and offline analyzer. Choose the runner matching the code being measured: the accepted frozen-fixture preparation runs `contact_driven_grip_preparation.gd`; the live UI runner still reaches `preview_grip_acquisition.gd` and `handle_grip_acquisition.gd`. These are different paths. Running the live UI tracer does not measure the accepted isolated preparation solver.

The recorder adds timing and state observations. It does not optimize the solver, change grip rules, substitute a solved pose, suppress acquisition, or trace skin/weapon geometry. Use one substantial Godot run at a time. Set recording environment variables before launching Godot; the logger reads its requested path when the script loads. Run from a dedicated PowerShell terminal so the environment overrides remain local to that terminal and its child process.

## Accepted frozen-fixture preparation capture

`run_contact_driven_preparation.gd` observes the complete isolated preparation for both captured hands, including fixture loading, context and saved-section preparation, the actual solver, result verification, and report writing. It does not open Skill Crafter or execute weapon/skill selection. Its `preparation.runner.*` events identify the scope as `accepted_frozen_fixture`. The source library and hand captures are hash-checked frozen files under `C:/WORKSPACE/test_artifacts`; it never loads the player save library from `user://`.

The fixed inputs are `forge_v2_grip_target_wrapper_2026-09-28T03-59-21_straight_library.tres` and the right/left `full_hand_placement_*_2026-09-27T14-46-36.bin` captures. Expected hashes remain declared in the runner. The trace observes these inputs without replacing or saving them. The existing visual HTML and JSON report retain their fields; timings include recorder overhead.

```powershell
$env:APPDATA = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\roaming'
$env:LOCALAPPDATA = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\local'
$env:TEMP = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\temp'
$env:TMP = $env:TEMP
$gripTraceStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$env:THE_WILL_GRIP_TRACE_PATH = "C:/WORKSPACE/test_artifacts/grip_preparation_chronology_${gripTraceStamp}_${PID}.jsonl"
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\WORKSPACE\The Will- main folder\the-will-gamefiles\tools\launch_the_will_safe.ps1' -Headless -ScriptPath 'res://tools/grip_plane_proof/run_contact_driven_preparation.gd'
```

This runner awaits natural completion of both hands and closes the recorder once after its reports are written, including handled setup-failure paths. It has no wall-clock cutoff or 35-second observation cap. The live UI runner's `THE_WILL_GRIP_TRACE_TIMEOUT_SECONDS` and `THE_WILL_GRIP_TRACE_AFTER_SECONDS` settings do not govern this route. Do not add the launcher's `-QuitAfterSeconds` option: that forwards Godot `--quit-after` and can end the capture prematurely. Structural checks and a completed trace do not certify final grip acceptance or gameplay integration.

## Live UI capture

`trace_skill_crafter_grip.gd` records the natural current live acquisition path: open Skill Crafter, activate an existing saved weapon through its real double-click handler, press the actual Skill 1 selector, and observe grip processing until it becomes quiescent or reaches the observation timeout. Skill selection has a button handler, not a separate double-click handler. The runner instantiates the real station UI with an isolated library provider; it does **not** measure full game startup, travel to the station, or physical mouse delivery.

The existing diagnostic runtime must already contain the intended saved weapon in `roaming/Godot/app_userdata/The Will-Gamefiles/forge/player_wip_library_state.tres`. This command does not copy or modify the real game saves. The isolated library is not saved; its hash is checked after observation. A library requiring a persisting schema migration is rejected before opening the station.

```powershell
$env:APPDATA = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\roaming'
$env:LOCALAPPDATA = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\local'
$env:TEMP = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\temp'
$env:TMP = $env:TEMP
$env:THE_WILL_DIAGNOSTIC_USER_ROOT = 'C:/WORKSPACE/test_artifacts/grip_p1_runtime/roaming/Godot/app_userdata/The Will-Gamefiles'
$gripTraceStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$env:THE_WILL_GRIP_TRACE_PATH = "C:/WORKSPACE/test_artifacts/grip_chronology_${gripTraceStamp}_${PID}.jsonl"
$env:THE_WILL_GRIP_TRACE_TIMEOUT_SECONDS = '1800'
$env:THE_WILL_GRIP_TRACE_AFTER_SECONDS = '5'
$env:THE_WILL_GRIP_TRACE_WEAPON_NAME = 'Star_Handle_Testing'
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\WORKSPACE\The Will- main folder\the-will-gamefiles\tools\launch_the_will_safe.ps1' -Headless -ScriptPath 'res://tools/grip_plane_proof/trace_skill_crafter_grip.gd'
```

The trace path must be an absolute `.jsonl` path inside `C:/WORKSPACE`; nonempty existing files are refused. Omitting `THE_WILL_GRIP_TRACE_PATH` disables runtime recording. Use the exact existing saved weapon name; duplicate matching names are rejected.

The defaults are 1,800 seconds of observation and five seconds after a terminal candidate remains quiescent for two seconds. The timeout is checked between main-thread frames, so it cannot interrupt a main-thread stall at exactly 1,800 seconds. On timeout, cancellation waits for an owned worker to finish safely; joining may extend the total run. One-second heartbeats expose frame gaps, UI status, acquisition state, queued requests, and worker activity.

Timeout cancellation can itself produce stale-request or discarded-result events. Their position after `runner.timeout` or `runner.cancel_and_join` distinguishes cleanup effects from evidence of the original stall.

## Offline report

For either capture route, the analyzer only reads the JSONL and writes adjacent `.summary.json` and `.html` files. It does not open Skill Crafter or run a grip solve. Analyze an interrupted capture too: completed records remain useful, and incomplete final lines are reported.

```powershell
$env:THE_WILL_GRIP_SUMMARY_PATH = $env:THE_WILL_GRIP_TRACE_PATH
Remove-Item Env:THE_WILL_GRIP_TRACE_PATH -ErrorAction SilentlyContinue
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\WORKSPACE\The Will- main folder\the-will-gamefiles\tools\launch_the_will_safe.ps1' -Headless -ScriptPath 'res://tools/grip_plane_proof/summarize_grip_chronology.gd'
```

Set `THE_WILL_GRIP_SUMMARY_PATH` explicitly when analyzing an older capture. The analyzer also accepts the Godot script argument `--trace <absolute-path>`; that argument takes precedence over the environment variable. The environment form above works with the supported launcher without changing its argument interface.

The HTML offers per-stage counts, paired durations, average/maximum/P95 duration, recorded outcomes, unfinished spans, and a sortable/filterable chronological event table. JSON preserves the full accepted record sequence. Times use monotonic microseconds and are presented in milliseconds; one initial UTC timestamp connects the trace to other logs.

## Interpretation

- Stage durations are inclusive: children and worker operations overlap. Summing every stage does not yield elapsed wall time. Open-span counts include nesting and are not worker-thread counts.
- `trace.closed`, a runner exit, or `preview_applied` does not certify a correct grip. Compare terminal status, assessment fields, final observations, and visuals. The runner explicitly does not assert grip success.
- An unmatched start means an operation had no recorded finish. A partial trace alone cannot distinguish a stall, crash, cancellation, capture stop, or missing instrumentation. Its observed duration is a lower bound at the last recorded event.
- Span boundaries flush immediately to retain evidence of the operation entered before a stall. Other records flush periodically on subsequent calls and at terminal/close events. Recorded cumulative write time and flush counts expose instrumentation cost; reported solve durations include that boundary overhead.
- Trace JSONL/HTML/summary files and launcher logs are diagnostic outputs, not source assets to push.

Official API references: [Time](https://docs.godotengine.org/en/4.7/classes/class_time.html), [The Profiler](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/the_profiler.html), [Thread](https://docs.godotengine.org/en/4.7/classes/class_thread.html), [Mutex](https://docs.godotengine.org/en/4.7/classes/class_mutex.html), and [FileAccess](https://docs.godotengine.org/en/4.7/classes/class_fileaccess.html). The 4.7 Time and profiler guidance support monotonic tick differences for elapsed durations and distinguish inclusive timing from self time; profiling overhead remains part of a measured run. The 4.7 FileAccess page was unavailable during initial research; [official 4.5 FileAccess documentation](https://docs.godotengine.org/en/4.5/classes/class_fileaccess.html) supplied the flush/persistence behavior check.
