# DISASSEMBLY BENCH UI WORKING SPEC

Date: 2026-03-27
Status: first honest raw-drop disassembly bench UI slice is now live; broader salvage/storage cases are still intentionally pending

Reference image:
- `C:\WORKSPACE\GDD-and Text Resources\Screenshot 2026-03-26 214220.png`

Remaining honest boundaries:
- there is still no real stationary storage interactable/page surface yet
- there is still no general dismantleable-item model yet for non-forge items
- blueprint extraction and chase-material skill extraction do not yet have the supporting item data to drive the optional controls honestly
- finalized-item material makeup/provenance does not yet exist, so finished-item salvage cannot be previewed honestly

Current implementation gate:
- the player body-inventory authority layer now exists
- the first raw-drop disassembly backend now exists and can preview -> confirm -> route processed materials into forge inventory with stale-preview protection
- the first responsive disassembly bench UI and world bench scene now exist on top of that backend for the raw-drop path only
- tabs 1 to 5 are now honest for supported raw-drop items in body inventory
- tabs 6 and 7 stay hidden/disabled until supporting item data exists
- the live UI follows the same responsive window rules used by the forge and system menu: keep the full window in frame, use scroll regions when needed, and avoid fixed off-screen layouts

## Locked working UX from the 2026-03-26 user note

1. Inventory list:
- show only player body-inventory items that are relevant and suitable for disassembly
- do not show irrelevant clutter
- items that remain here are still in the player inventory and were not committed to disassembly

2. Output preview list:
- show the processed material outcome preview for the current disassembly selection
- these previewed outputs do not exist in inventory yet
- outputs are only routed when the proper confirmation interaction happens
- wording must be clean and explicit to avoid duping/exploit confusion

3. Selected-for-disassembly list:
- items moved here were deliberately or accidentally selected for disassembly
- clicking an item in this list removes it from the pending selection and returns it to the inventory list
- selecting items in tab 1 adds them here and updates tab 2 output preview

4. Disassemble confirmation button:
- pressing it routes the resulting processed materials from tab 2 into forge storage / the forge-material destination page
- this transfer must be one-way and authoritative

5. Irreversible warning area:
- include text stating that disassembly converts items into forge building materials
- include text stating the result becomes non-tradable
- include text stating the change is permanent and cannot be reverted
- include a checkbox equivalent to: `by checking this box i understand that this process is irreversible`
- disassembly-related buttons stay disabled until the checkbox is checked

6. Optional extract-blueprint action:
- only show or enable this if blueprint-extractable items are present in the selected-for-disassembly list

7. Optional select-skill action:
- only show or enable this if a chase/special material with a skill is present in the selected-for-disassembly list

8. Previous image marker:
- ignore; the user marked this as a mistake

9. Previous image marker:
- ignore; the user marked this as a mistake

10. Selected item rows:
- each individual pending item shown in the selected-for-disassembly list can be clicked to return it to inventory

11. Output material rows:
- individual processed materials shown in the output preview are informational preview only until confirmation

12. Remaining inventory rows:
- disassemblable items not currently selected stay in the inventory list and remain in player inventory after the process

## Optional placement use for the old 8 and 9 areas

If those spaces are used later, the safest already-mentioned candidates are:
- a small `send to forge storage` / destination explanation block
- a conditional blueprint / skill extraction sub-panel host
- a compact summary block showing selected item count and projected output count

Do not repurpose those spaces for unrelated systems without a clear need.

## Structural dependency note

Before this UI should go live, the project needs:
- player body inventory state
- stationary storage state
- forge-side storage/material destination state
- a clear item model for dismantleable inventory entries
- authoritative routing rules for where confirmed outputs land
- contextual finalized-item salvage makeup if finished items are meant to appear in the same first-pass UI list

## 2026-03-27 implementation note

The first honest disassembly bench UI slice now exists in code and in the traversal sandbox:
- a world disassembly bench can be interacted with alongside the crafting bench
- the UI shows supported body-inventory raw drops only
- selecting a row moves it into the pending disassembly list and updates the processed-material preview
- the irreversible checkbox gates the disassemble action
- confirmed output routes directly into forge material storage
- blueprint extraction and chase-skill controls stay hidden unless their supporting backend flags become true
- the current body-inventory list is seeded through authored inventory seed data only when the body inventory is empty, so the station is testable without hardcoded UI-side fake items

Verification snapshot:
- `layout_inside_1280x720=true`
- `layout_inside_1024x576=true`
- `selected_count_after_pick=1`
- `disassemble_disabled_before=true`
- `disassemble_disabled_after_check=false`
- `forge_wood_quantity_after_commit=24`
- `main_scene_loaded=true`
- `disassembly_bench_present=true`
- `disassembly_ui_present=true`

Recommended next unlock step:
- keep finished-item salvage, blueprint extraction, and chase-skill selection hidden or disabled until their supporting item data exists
- add the stationary storage interactable/page layer above the current inventory authority surface
- keep extending the disassembly bench only where the backend truth already exists instead of filling missing item cases with guessed behavior
