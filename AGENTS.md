# Workspace operating instructions

These are standing user instructions for work in `C:\WORKSPACE`, recorded on
2026-10-03. Read them at the start of a new session. Current explicit user
instructions take precedence over older project documents.

## Required orientation

Read all four files in `Agent law` completely before project work:

1. [Project orientation and authority map](<Agent law/PROJECT ORIENTATION AND AUTHORITY MAP.md>)
2. [Agent guardrails](<Agent law/AGENT_GUARDRAILS.md>)
3. [Collaboration mindset](<Agent law/COLLABORATION_MINDSET.md>)
4. [Handoff workflow and SPS protocol](<Agent law/AGENT_HANDOFF_WORKFLOW_LAW_2026-05-26.md>)

Then read the newest timestamped SPS in `GDD-and Text Resources/SPS`, its
first-action target, and the relevant task note. Read current code when an
implementation task is selected. Orientation alone does not authorize resuming
a historical implementation plan.

The orientation map contains dated historical snapshots and links inherited
from its former documentation-root location. Resolve documentation targets
under `GDD-and Text Resources`; use the four rule files in `Agent law` as the
current agent-law sources. Discover the newest SPS and current repository
metadata rather than treating a historical branch or resume pointer as current.

## Work and verification

- Do proper work: inspect the authoritative owner and current code, make
  material assumptions explicit, and resolve root causes rather than stacking
  speculative fixes or forcing a repeatedly failing approach.
- Preserve existing user work. Keep scope narrow and ownership clear. Do not
  invent core mechanics, add unrequested systems, or rename established files,
  folders, classes, IDs, or concepts without explicit user direction.
- Understand the intended finished machine while building from authoritative
  roots upward; protect future seams without implementing future scope early.
- For Godot implementation, research the topic in official, version-matched
  documentation first and prefer documented native workflows.
- Before implementation, explain the plan, material assumptions, unresolved
  decisions, and exact files to touch. Leave missing core rules as `TODO` or
  `NEEDS_DECISION` rather than inventing them.
- Meaningful implementation needs code truth, focused verifier truth, and
  current task-note/handoff truth. Distinguish fresh verification, historical
  results not rerun, and untested or uncertain behavior.
- The orientation map supersedes older automatic tracker-update clauses:
  implementation memory, naming trackers, and exported-knob registry are
  sunset and read-only. Use current task notes and SPS when appropriate.

## SPS and Git

SPS means **Save Project State**: durable session/focus memory. The full protocol
and nine-section template are in the handoff workflow law. Store each real new
handoff as `GDD-and Text Resources/SPS/SPS_YYYY_MM_DD_HH-MM.md`, using
Europe/Bucharest time. The newest filename timestamp is the resume slot. Older
snapshots retain their history; only typo fixes or clearly marked corrections
may amend them.

Create SPS when requested, for an actual shutdown/handoff/resume-memory request,
or when durable context preservation is genuinely needed. SPS preserves the
active slice, evidence, gaps, next focus, first action, and what not to load.
It does not establish test success or authorize Git operations.

The Git root is `C:\WORKSPACE`; the active Godot project is
`The Will- main folder/the-will-gamefiles`. Inspect current Git status before
editing project code. Preserve unrelated changes. Do not revert, clean,
broadly reformat, stage, commit, push,
or otherwise change branches, repository history, or the index unless the user
requests that action. A Git
savepoint is separate from an SPS and from ordinary implementation permission.
