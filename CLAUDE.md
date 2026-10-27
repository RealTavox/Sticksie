# Kreuzstich

Godot 4.7 app (GDScript, Compatibility renderer) that turns pixel art into a cross-stitch
pattern and guides the user stitch by stitch with the Danish method. Phones and tablets first,
maybe web later. The design is in `DESIGN.md` (German).

## Workflow

This project uses the global workflow skills (`/analyse-code`, `/fix-next-finding`,
`/plan-features`, `/pitch-feature`, `/implement-next-feature`, their loops, and
`/setup-workflow`). The running lists `CLAUDE_ANALYSIS.md`, `USER_ANALYSIS.md`,
`CLAUDE_PLAN.md` and `USER_PLAN.md` sit at the repo root; their rules are in
`list-format.md` of the `dev-workflow` plugin's `setup-workflow` skill. The user's preferences for them (design
docs, idea sources, hands-off paths, what to ask before, commit rules and scopes) are in
`USER_WORKFLOW.md`. This section holds the facts; keep it current when the code changes. The
lists may be newer than this file: if they disagree, check the code. When a finding or plan
item is resolved during normal work, delete its entry in the same change.

### Code scope

- Project code: all `*.gd`, `*.tscn`, `*.tres`, `*.gdshader` in the repo, plus `project.godot`.
  (No code yet; update this once the folder layout exists.)
- Generated / not project code: `.godot/`, `*.import` files. (Hands-off paths are in
  `USER_WORKFLOW.md`.)
- List paths are relative to the repo root.

### Verification

How to check a change; every fix and feature runs these. Godot binary:
`/Applications/Godot.app/Contents/MacOS/Godot` (4.7.2).

1. `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | grep -E "ERROR|WARNING|SCRIPT ERROR"`:
   no new errors or warnings (parses every script and imports resources).
2. Once a main scene exists: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 2>&1 | grep -E "ERROR|SCRIPT ERROR"`:
   the app starts and runs a few frames without errors.
3. Manual: run the project in the Godot editor and look at the changed screen; there is no
   automated visual check yet.

No test framework yet, so planner and colour-matching logic are only checked by running the
app; reports must say so.
