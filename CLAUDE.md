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

- Project code: `src/` (`palette/` thread colours and Lab matching, `pattern/` the `Pattern`
  resource, `import/` PNG → pattern, `ui/` views, `main.tscn`/`main.gd` the start screen),
  `tests/run_tests.gd`, plus `project.godot` and the `*.import` files next to resources (they
  hold import settings: `data/threads/dmc-floss.csv` uses the "keep" importer so it isn't
  turned into a translation, `samples/*.png` use the "image" importer so `load()` returns an
  exact `Image`).
- Data: `data/threads/dmc-floss.csv` (DMC palette, CC BY 4.0, source and credit in
  `data/threads/SOURCE.md`; the credit must stay visible in the app). `samples/` holds test
  images.
- Generated / not project code: `.godot/`. (Hands-off paths are in `USER_WORKFLOW.md`.)
- List paths are relative to the repo root.

### Verification

How to check a change; every fix and feature runs these. Godot binary:
`/Applications/Godot.app/Contents/MacOS/Godot` (4.7.2), called `$G` below.

1. `$G --headless --path . --import 2>&1 | grep -E "ERROR|WARNING"`: no output (parses every
   script and imports resources; run it first after adding a `class_name`).
2. `$G --headless --path . --script res://tests/run_tests.gd`: prints "All tests passed."
   and exits 0. Plain checks without a framework (Lab/CIEDE2000 against Sharma's reference
   pairs, DMC palette, importing the sample).
3. `$G --headless --path . --quit-after 120 -- --open=res://samples/hypsi_anhaenger.png 2>&1 | grep -E "ERROR|WARNING"`:
   no output.
4. Screenshot (opens a window for a moment):
   `$G --path . --resolution 720x1280 -- --open=res://samples/hypsi_anhaenger.png --screenshot=<abs path>.png`,
   and again with `1280x720` for landscape; look at the PNGs.

Touch input (pan, pinch) and the native file dialog are not covered by these; check them on a
device or in the editor and say so in the report.
