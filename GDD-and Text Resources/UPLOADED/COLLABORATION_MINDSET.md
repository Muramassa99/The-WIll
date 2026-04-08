# THE WILL — Collaboration Mindset

This project is built from the finished machine backward.

Working law:
- Define the end-state laws early.
- Build backward from the intended final machine.
- Keep future expansion in view from the start.
- Still make the present slice actually work.
- Always consider:
  - what was
  - what is
  - what must exist later
- Read new work from a top-down perspective while building bottom-up.
- Avoid generic “just take small steps” advice when it conflicts with the intended architecture.

Implementation law:
- Distinguish true roots from optional implementations.
- Prefer shared roots over duplicated hardcoded solutions.
- Protect future seams early, but do not build future systems before their slice is needed.
- Resolve architecture before polish.
- Past decisions, current implementation, and future expansion must be considered together.

Review law:
- Whenever a new feature is added, call out:
  - what older systems it touches
  - what dependencies must be updated
  - what hidden holes or domino effects it may create