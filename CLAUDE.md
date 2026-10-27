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

- Project code: `src/` (`project/` saving: `StitchProject` and its JSON format, `ProjectStore`
  files in `user://projects/` (list with preview picture, rename, delete) and the last opened project, `Preferences` app-wide settings in
  `settings.cfg` next to the projects (skip limit, start corner, stitch method, the advanced
  stitch style; not saved in the project file, pushed into the open project); `palette/` thread colours and Lab matching, `pattern/` the `Pattern`
  resource, `import/` PNG → pattern, `planner/` Danish stitch order (`StitchPlanner` →
  `StitchStep`s), `stitching/` progress per thread (`StitchSession`), the back of the fabric
  (`BackSide`: the thread between the needle holes, worked out from the planned steps; drawn
  mirrored by `PatternView.back_side`), where the needle comes up (`StitchStyle`, see Planner
  rules) and position hints
  (`PositionHint`: the nearest findable stitch to count from, any colour: the last stitch
  made or the end of a run, never a stitch in the middle of a row of equal stitches), `ui/`
  views (`PatternView` preview and progress mode with the current block's stitch count, `StitchPanel` step guidance, `ProjectBrowser` the
  project list: open, rename, delete after a confirmation; the preview comes from
  `ProjectStore.preview()`, for now the source image, later meant to show the progress), `main.tscn`/`main.gd` the start screen),
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
   pairs, DMC palette, importing the sample, stitch planner incl. that every cell of the sample
   is crossed exactly once, stitching progress, position hints and their wording).
3. `$G --headless --path . --quit-after 120 -- --projects-dir=<scratch dir> --open=res://samples/hypsi_anhaenger.png --stitch=3837 --steps=7 2>&1 | grep -E "ERROR|WARNING"`:
   no output. Always pass `--projects-dir` with a scratch folder: every run that opens an image
   saves a project, and without it that lands in the user's real projects.
4. Screenshot (opens a window for a moment):
   `$G --path . --resolution 720x1280 -- --projects-dir=<scratch dir> --open=res://samples/hypsi_anhaenger.png --screenshot=<abs path>.png`,
   and again with `1280x720` for landscape; look at the PNGs. Add `--stitch=<DMC code>
   --steps=<n>` for the stitching screen after n confirmed steps, `--max-skip=<n>` to set the
   skip limit (-1: none), `--start=<top-left|top-right|bottom-left|bottom-right>` the start corner, `--settings` to open the settings dialog, `--projects` the project list, `--back` the back side while stitching,
   `--method=<danish|english>`, `--needle=<auto|bottom|top>`, `--first-leg=<slash|backslash>`
   (both fix the style), `--advanced` with `--settings` for the advanced part. In zsh, pass each user
   argument as its own word (an unsplit `"$args"` arrives as one argument and is ignored).

Touch input (pan, pinch) and the native file dialog are not covered by these; check them on a
device or in the editor and say so in the report. Resuming: run once with `--open` and
`--steps`, then again with only `--projects-dir` (the last project opens by itself).

### Save format

`StitchProject.to_dict()`, one JSON file per project, `format` 2 (2 added `progress.max_skip`
and `progress.manual_thread_starts`; format 1 files load with no limit and no manual changes). It holds the image (PNG,
base64), fabric codes, the pattern itself (so palette or matching changes can't alter a pattern
being stitched) and progress as cell states; a step counts as done when the cells already show
it (`StitchSession.restore()`), so any plan order works. `done_steps` per thread code is only
informational. Changing the format needs the user's OK and a new
`format` number with a migration for older files.

### Planner rules

Fixed in `src/planner/stitch_planner.gd`, decided with the user (DESIGN.md "Offene Punkte"):
a row segment ends at a gap of more than 3 cells (`MAX_GAP`); a segment of one stitch becomes a
single full cross; blocks hold at most 5 stitches (`MAX_BLOCK`) and are split evenly
(7 → 4 + 3); a block never has a gap inside: each run of adjacent cells is split on its own and
the thread skips on the back only between blocks; every segment starts at its end nearer to the needle (on a tie the start side; legs stay `/` then `\` either way), and the Danish return pass ends there. Order: segments
in neighbouring rows that overlap or touch diagonally form an area (`connected_areas()`); an
area is finished before the next and grows without holes (`_next_segment()`): first candidates
are open segments touching the one just finished, then open segments of the area touching any
finished one, then other areas. Within a tier the nearest to the needle wins (Chebyshev skip from
the end the last segment began at to the nearer end of the candidate), ties go to row order. `tests/run_tests.gd` checks on the
sample that every segment after an area's first touches an earlier one.

English method (`Preferences.english()`, `StitchSession.set_english()` replans like the skip
limit): every block is a `CROSS` step of whole crosses, in the same blocks, and the needle ends
at the segment's far end, which the next segment's nearer end is measured from.

Needle holes: `StitchStyle.needle_holes()` is the one place that decides where each leg comes up;
the guide text (`StitchPanel.describe_corner()`), the needle dot and the back all use it.
Automatic (default): "/" first, the first leg of a step comes up on the side the step comes
from, every later leg at the hole nearest to where the needle went down (vertical preferred,
never the same hole), so Danish passes leave only vertical back stitches in both directions
(tested on the sample). Fixed (advanced settings): the chosen leg order ("/" or "\" first; cell
state `HALF` means the first leg) and always up at the bottom or always at the top.

Thread changes: `StitchStep.travel_before` is the cells skipped on the back from the previous
step's last stitch (Chebyshev distance − 1, so a neighbour, diagonal or next row is 0). With a
skip limit (`Preferences.max_skip()`, default `StitchPlanner.UNLIMITED`), a step travelling
further `starts_thread`, and the in-row gap limit drops to min(3, limit). Manual thread changes
live in `StitchSession` keyed by (first cell, kind), so they survive replanning; changing the
limit replans via `StitchSession.set_max_skip()`, which takes progress over from the cells.

Start corner: `Preferences.top_to_bottom()` / `start_left()` (default top left: rows to the
right, then down) set the row order and the start side; they decide where the first segment
begins and break ties. Changing them replans via `StitchSession.set_direction()` like the skip
limit. `main.gd` `_apply_preferences()` pushes both preferences into the open project.

Progress: `StitchSession` keeps a done flag per planned step, not a count, because after
replanning finished stitches can lie anywhere in the new order. The current step is the first
not done (`current_index()`), "back" clears the last done step before it. The flags live in a
Dictionary of PackedByteArray (a value type): write them through `_set_flag()`.
