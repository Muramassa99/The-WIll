# Native grip-contact calculation

This standalone Godot 4.7 GDExtension registers `GripContactKernel`,
`GripSliceKernel`, `GripTopologyKernel` and `GripSavedContactKernel` as `RefCounted` classes at scene
initialization. It implements the existing planar contact/overlap calculation,
triangle slicing and section-topology validation. Grip sequencing, bone limits, section
allowances, wrapper ownership, and weapon movement remain owned by the calling
Godot code. This library does not link Forge or Manifold.

The supported build is Windows x86_64, Godot standard/single-precision
`real_t`, using the workspace LLVM-MinGW Clang 22.1.8 toolchain. CMake
`Release` supplies `-O3`; `template_debug` preserves Godot extension debug
features and does not mean the calculation is built without optimization.
The kernel explicitly disables fast-math and floating-point contraction/FMA.
Changing geometric accuracy to 0.05 mm is a solver configuration decision,
not permission for unsafe compiler arithmetic or a change in overlap caps.

## Workspace build using already compiled bindings

Run from the game project root, after closing the game before replacing its
DLL. Do not run another Godot test alongside a manual
game test. These commands use only the existing workspace compiler tools and
bindings; they neither install software nor execute the binding generator's
Python interpreter. Absolute tool paths avoid requiring the PowerShell
activation script, which is blocked by this machine's script execution policy.

```powershell
$gripCMake = 'C:\WORKSPACE\helper applications\cpp-toolchain\cmake-4.4.2-windows-x86_64\bin\cmake.exe'
& $gripCMake -S native/grip_contact `
  -B 'C:/WORKSPACE/helper applications/cpp-build/grip-contact' `
  -G Ninja `
  '-DCMAKE_MAKE_PROGRAM=C:/WORKSPACE/helper applications/cpp-toolchain/ninja-1.13.2/ninja.exe' `
  '-DCMAKE_TOOLCHAIN_FILE=C:/WORKSPACE/helper applications/cpp-toolchain/llvm-mingw-x86_64.cmake' `
  -DCMAKE_BUILD_TYPE=Release `
  -DGRIP_USE_PREBUILT_GODOT_CPP=ON
& $gripCMake --build 'C:/WORKSPACE/helper applications/cpp-build/grip-contact' `
  --target grip_contact --parallel 4
```

Output:
`native/grip_contact/bin/grip_contact.windows.template_debug.x86_64.dll`.
The intermediate objects remain under `helper applications/cpp-build/grip-contact`.
The build does not change the existing Forge extension, its build cache, or
vendor sources.

The active descriptor is `grip_contact.gdextension`. Godot 4.7 has successfully
imported the built extension; no descriptor rename is required.

## Kernel verification and timing scope

The Windows Godot 4.7 run recorded in
`C:/WORKSPACE/test_artifacts/native_overlap_kernel_2026-10-01T01-32-20.json`
passed 420 checks over 2,471 compared segments, with zero measured
position/depth differences at identical settings. Its aggregate evaluator
timing was 2,427,182 microseconds for GDScript and 78,958 microseconds for
C++ (30.74x). These measurements include native call conversion but exclude
shared target preparation; they are not full-grip or gameplay timings.

Run the reference comparison after the build and import, with the game
closed, in a dedicated PowerShell terminal:

```powershell
$env:APPDATA = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\roaming'
$env:LOCALAPPDATA = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\local'
$env:TEMP = 'C:\WORKSPACE\test_artifacts\grip_p1_runtime\temp'
$env:TMP = $env:TEMP
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\WORKSPACE\The Will- main folder\the-will-gamefiles\tools\launch_the_will_safe.ps1' -Headless -ScriptPath 'res://tools/grip_plane_proof/run_native_overlap_kernel.gd'
```

The runner verifies its frozen capture hash, compares the GDScript and native
outputs, benchmarks captured inputs, then writes a timestamped JSON under
`C:/WORKSPACE/test_artifacts`. Elapsed durations use monotonic microseconds.
For subsequent complete preparation traces and chronological reports, follow
[GRIP_CHRONOLOGY.md](../../tools/grip_plane_proof/GRIP_CHRONOLOGY.md); that
document distinguishes the isolated solver from the live UI acquisition path.

## Complete isolated-solver comparison

The matched frozen-input comparison uses
`contact_driven_preparation_2026-10-01T00-31-21.json` as the GDScript baseline
and `contact_driven_preparation_2026-10-01T01-34-49.json` as C++ at the same
0.01 mm depth bound. Both files are under `C:/WORKSPACE/test_artifacts`.
All 156,165 compared baseline leaf fields, excluding timing, were identical.
The native run passed 70 structural checks; both hands still have two accepted
contact sections. This proves preservation of this example, not a successful
complete gameplay grip.

| Solver measurement | Right hand | Left hand |
| --- | ---: | ---: |
| GDScript baseline | 52.504066 s | 59.618256 s |
| C++, matched 0.01 mm settings | 19.671936 s | 21.348995 s |
| C++, default-settings rerun `01-43-11` | 22.264120 s | 24.705714 s |

The first matched comparison reduced combined solver time from 112.122322 s
to 41.020931 s, approximately 2.73x faster. The later no-override rerun passed
67 checks and demonstrates that duration varies: the observed C++ ranges are
19.67-22.26 s right and 21.35-24.71 s left. These are individual measurements,
not a guaranteed duration or a statistical benchmark.

The `01-40-22` experiment at a 0.05 mm depth bound changed the left thumb's
recorded contact and did not improve speed. It was not selected. Defaults in
`saved_wrapper_skin_contact.gd` are C++ with the proven 0.01 mm bound; the proof
runner derives those defaults and permits explicit diagnostic overrides with
`THE_WILL_GRIP_CONTACT_BACKEND` and `THE_WILL_GRIP_DEPTH_TOLERANCE_M`. A missing
extension emits a warning and records reference-backend fallback use in cache
statistics. This changes the contact evaluator; it does not replace the live
UI's existing grip-acquisition owner with the isolated preparation solver.

The remaining largest measured owner is saved weapon-section slicing and
topology: 8.707 s right / 9.486 s left in the `01-34-49` trace, about 44% of
each solver. Those inclusive totals contain 4.402 / 4.821 s of topology and
3.456 / 3.746 s of triangle slicing; do not add the nested figures again.
Saved-contact evaluation separately takes 4.591 / 4.681 s, plus target
preparation of 1.926 / 2.100 s. Native numerical calculations are therefore
only one part of the remaining duration.

## Compiled section calculations

`GripSliceKernel.slice(surface, plane_to_world, plane_origin_id, reach_m,
skin_padding_m)` ports the complete `slice_reachable_surface.gd` packet,
including source-order intersection, welding, edge insertion, disk clipping,
contour extraction, failure statuses and counts. It is stateless between calls.
`GripTopologyKernel.prepare_target(segments, origin_id)` ports the existing
`skin_plane_contact_query.gd.prepare_target` packet, including metadata,
endpoint representatives, ordered bounds-tree traversal and the first twelve
intersection diagnostics. It does not implement that script's evaluate method.

`prepared_weapon_plane_section.gd` now defaults to both compiled kernels.
The triangle index, fixed-plane and origin checks, centroid and complete-section
policy stay in GDScript. The original helpers remain the reference/fallback;
ordinary selected calls run one implementation. Invalid native geometry stays
invalid. Missing classes use the reference with explicit warning/counters.
Backend counters are instance-owned and separate from geometric/cache packets.
Set `THE_WILL_GRIP_SECTION_BACKEND=gdscript` in the preparation runner to make
a controlled comparison; this is independent of the contact backend selection.

Current-run evidence under `C:/WORKSPACE/test_artifacts`:

- `native_section_kernels_2026-10-01T02-15-03.json`: 431 checks passed,
  including 12 real triangle slices, 60 frozen topology cases, synthetic
  invalid/open/clipped/diagonal/near-threshold cases and three-repeat timings.
  Native conversion is included. Captured slice medians are 17.7-20.4x faster;
  topology medians 5.7-10.4x. These are component timings, not full-grip speedups.
- `contact_driven_preparation_2026-10-01T02-15-26.{json,html}`: 74 checks passed,
  contact and section backends C++, no fallbacks. Against fresh reference-section
  report `02-13-41`, right 22.243046 -> 14.652243 s; left 23.966708 -> 15.378523 s.
  This saves 34.1% / 35.8% of complete solver time in this comparison.
- `native_section_pose_comparison_2026-10-01.json`: all 156,181 existing case
  values except timings match the previous `01-43-11` report exactly. New backend
  counters are additional metadata. The existing two accepted sections per hand
  remain unchanged; this still does not certify a complete gameplay grip.
- `verify_prepared_weapon_plane_section_2026-10-01T02-17-35.json`: 161 checks
  passed with the selected C++ default and zero fallback.
- `prepared_saved_grip_sections_2026-10-01T02-17-52.json`: 421 checks passed,
  including straight/curved saves, oblique planes, source immutability, named
  origin chains and independent GDScript translated-mesh reference checks.

The complete native trace `grip_section_native_chronology_2026-10-01T02-15-00`
contains 13,948 records and closes with no analyzer issues or unfinished spans.
Inside the solver, saved weapon-section cost fell from 9.524 / 10.332 s to
1.862 / 1.971 s right/left. The new inclusive totals contain triangle slicing
0.329 / 0.349 s and topology 0.556 / 0.584 s; do not add nested times twice.
Remaining saved-contact evaluation is 5.476 / 5.411 s with separate target
preparation 2.190 / 2.276 s. Further work requires measurement of that boundary,
not removal of checks. The live UI acquisition owner has not switched.

DLL SHA256 at the section-port checkpoint (superseded by the batch build below):
`08987a7a28ba5e014a58c3e1051dcb357340b83ef945b43e28591059fc12c06b`.
The CMake target and build command above are unchanged; the new classes are
compiled into the same extension, with the same floating-point flags.
Official [Vector3](https://docs.godotengine.org/en/4.7/classes/class_vector3.html)
and [Geometry2D](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html)
references were reviewed alongside the existing CPU optimization guidance.

## Complete saved-contact batch

`GripSavedContactKernel.prepare(section)` and
`evaluate(prepared, skin_segments, plane_origin_id, config)` own the complete
saved-wrapper contact calculation: ordered target preparation, material checks,
digit/palm guide grouping, numerical depth calls, witness normalization and
combined safety results. The existing `GripContactKernel` remains the sole
native numerical implementation. Calls between these classes stay inside C++.
The batch returns the established dictionaries; it does not write a skeleton,
move the weapon, generate a wrapper or decide the grip's stage sequence.

`saved_wrapper_skin_contact.gd` selects one backend. The original script and
per-segment native adapter remain available for controlled comparisons, but
normal batch calls do not execute either of them. The complete batch bypasses
the old serialized segment-result cache. Actual calculation/cache counters may
therefore change while logical depths, contact decisions and poses must match.

Each batch instance owns one acquisition epoch, begun with `begin_acquisition`;
`reset` releases prepared geometry and target handles. Prepared snapshots and
native sections each have a 64-entry limit; at most 192 typed targets are
retained. Hashes only select possible matches. Reuse requires exact type,
source order and scalar/vector component-bit equality against detached input
snapshots. No quantization, approximate cache key or shared global geometry
cache is used. Released handles are not reused within the instance. Use a
separate evaluator per concurrent acquisition; one instance is not a shared
thread-safe service.

Inputs are expected to come from `prepare`. A caller-mutated target with
inconsistent polygon, edge bounds or tree is rejected explicitly as
`noncanonical_prepared_target_packet`; the script reference previously trusted
those internal fields. This additional malformed-packet check does not alter
valid geometry acceptance. Unassigned skin still requires strictly exterior
evidence and cannot inherit another section's flesh allowance.

The focused verifier is `tools/grip_plane_proof/run_native_saved_contact.gd`.
Run it through the same supported launcher and isolated environment above.
It compares full native/reference packets using synthetic cases and frozen
real slices, then tests backend selection, input mutation and cache lifetimes.
Reports contain separate component benchmarks, not gameplay timings.

The preparation runner's `THE_WILL_GRIP_CONTACT_BATCH=0|1` selects the old
per-segment adapter or complete batch when `THE_WILL_GRIP_CONTACT_BACKEND=cpp`.
Explicit `gdscript` with batch `1` is rejected. The trace adds
`saved_contact.native_batch` with material/guide/witness durations and logical
depth counts. See `saved_contact_cache_statistics` for prepared/native cache
hits, retained target count, actual segment calls and fallback counts.

### Batch validation and selected default, 2026-10-01

The complete batch is now the default. Current evidence under
`C:/WORKSPACE/test_artifacts`:

- `native_saved_contact_2026-10-01T03-37-19.json`: **522 checks passed**, including
  captured/synthetic full packets, mixed signed-zero bounds below/above the tree
  threshold, exact warm reuse, changed inputs, eviction and reset. Four captured
  cold component medians are 11.3-16.1x faster than the script reference; repeat
  tests also exercise the script's existing result cache. These are component
  benchmarks, not whole-hand speedups.
- `saved_wrapper_skin_contact_2026-10-01T03-35-10.json`: **107 existing checks
  passed**, using the selected batch by default and the old adapter explicitly
  for its separate cache-lifecycle test.
- `contact_driven_preparation_2026-10-01T03-35-22.{json,html}`: **79 checks
  passed** with no overrides/fallbacks. Right **15.397612 -> 11.170773 s**,
  left **16.942334 -> 11.322146 s**, compared with fresh old-adapter control
  `03-20-39`. Combined measured solve time fell by about 30.5%.
- `complete_native_contact_default_comparison_2026-10-01.json`: all **156,089
  compared values match exactly**. Timings and backend execution statistics are
  excluded; logical work, geometry, poses, contact decisions and tolerance are
  compared. Both hands retain their existing two accepted sections, below three.
- `grip_complete_batch_default_20261001_033520_448.{jsonl,summary.json,html}`:
  natural completion, 12,523 records, no issues or unfinished spans. Whole cycle
  including setup/checks/report output is 29.511 s, distinct from per-hand solve.

Two port defects were caught before final verification: signed-zero bounds must
use Godot's equal-value tie behavior; container schema equality must handle
Godot's absent script reference (`OBJECT(null)`). Container schemas now use
`is_same_typed`, while all packet data retains exact bit/type/order comparisons.
Final runs record 115 / 119 prepared and native section hits right/left, with
190 retained targets per hand and zero fallback. No tolerance or cap changed.

The inclusive prepare/evaluate boundary fell from **8.001 / 8.522 s** to
**3.303 / 3.220 s** right/left. Its new target-preparation subtotal is
0.307 / 0.316 s; do not add it again. Candidate pose work remains
1.595 / 1.531 s, skin slicing plus palm annotation 2.353 / 2.228 s, and saved
weapon sections 2.030 / 2.066 s. These remaining boundaries still matter.
The two-second goal is not met, and this does not repair or replace live UI
acquisition/application. The last user-reported failed visual grip remains open.

Current DLL SHA256:
`dfa51ae084f3ddd150dd455ee20d8f9f22655c9ea962e62dd6b9ce3ea297d512`.

## Validated binding provenance

The default build imports only the existing generic static `godot-cpp`
library and headers from
`C:/WORKSPACE/helper applications/cpp-build/forge-v2-manifold`.
It checks the source commit, exact project API hash, expected cache entries
(`Release`, `template_debug`, `single`, threading and compatibility flags),
compiler version, archive hash, and both complete header-tree hashes before
compiling. A mismatch fails configuration instead of silently using another
ABI or regenerating bindings. The archive itself is not copied into the game
project.

| Input | Pinned value |
| --- | --- |
| godot-cpp commit | `d7b6162249ed52796a8301d216c24ee71d68c2bf` |
| Project `extension_api.json` SHA256 | `53d37f85be32b6d10fb2266ca51f6ef0c3a55728acdb7c8301b1458a93c00943` |
| `bin/libgodot-cpp.windows.template_debug.x86_64.a` SHA256 | `69e2053f5c92c9703b2583bc900098a7bbc875b34b3bd3e83bc2321435305909` |
| Generated `godot-cpp/gen/include` tree, 1,079 files | `d9349925517622eec7aca54fd3a9e89674ea34f821c5b78d6b120049c116355b` |
| Source `godot-cpp/include` tree, 72 files | `322ce6c107258608c1d61affbb8f03bd6729a57ab8d880903493f1e1b3f8061b` |

Header-tree hashes are SHA256 of the UTF-8 concatenation of all relative file
paths in ordinal sorted order, each as
`forward/slash/path<TAB>lowercase-file-SHA256<LF>`.
These are the existing workspace artifacts measured on 2026-10-01; changing
them requires deliberate revalidation rather than removing the checks.

## Rebuilding bindings from their pinned source

This optional path needs Python for Godot's binding generator. The existing
Forge cache and workspace SCons virtual environment refer to an interpreter
outside `C:/WORKSPACE`. Do not silently use it: obtain authorization for the
interpreter first, or use an already authorized workspace interpreter.
No dependency download, installation, or external interpreter execution is
part of the default build above.

After approval, use a separate clean build directory and explicitly supply
that interpreter's path; CMake rejects an omitted interpreter in this mode:

```powershell
$gripCMake = 'C:\WORKSPACE\helper applications\cpp-toolchain\cmake-4.4.2-windows-x86_64\bin\cmake.exe'
& $gripCMake -S native/grip_contact `
  -B 'C:/WORKSPACE/helper applications/cpp-build/grip-contact-full' `
  -G Ninja `
  '-DCMAKE_MAKE_PROGRAM=C:/WORKSPACE/helper applications/cpp-toolchain/ninja-1.13.2/ninja.exe' `
  '-DCMAKE_TOOLCHAIN_FILE=C:/WORKSPACE/helper applications/cpp-toolchain/llvm-mingw-x86_64.cmake' `
  -DCMAKE_BUILD_TYPE=Release `
  -DGRIP_USE_PREBUILT_GODOT_CPP=OFF `
  '-DPython3_EXECUTABLE=<authorized interpreter path>'
& $gripCMake --build 'C:/WORKSPACE/helper applications/cpp-build/grip-contact-full' `
  --target grip_contact --parallel 4
```

This reproduces bindings from the same source commit and exact Godot API.
It uses its own binding objects, leaves the vendor checkout unchanged, and
does not reuse or alter Forge build outputs. The expected LLVM-MinGW libc++
link-option correction is applied to the CMake target, following the existing
Forge build pattern.

Official references reviewed for this implementation:
[Godot 4.7 C++ extension setup and registration](https://docs.godotengine.org/en/4.7/tutorials/scripting/cpp/gdextension_cpp_example.html)
and [CPU optimization](https://docs.godotengine.org/en/4.7/tutorials/performance/cpu_optimization.html).
