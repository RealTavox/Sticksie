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
  `settings.cfg` next to the projects (light direction and height in section `view`, default from the top left at 55°, set in the
  advanced settings; skip limit, start corner or automatic, stitch method, block size, the advanced
  stitch style; not saved in the project file, pushed into the open project; plus the touch or
  desktop layout in section `ui`, default touch on mobile); `palette/` thread colours and Lab matching, `pattern/` the `Pattern`
  resource, `import/` PNG → pattern, `planner/` Danish stitch order (`StitchPlanner` →
  `StitchStep`s), `stitching/` progress per thread (`StitchSession`), the back of the fabric
  (`BackSide`: the thread between the needle holes, worked out from the planned steps; drawn
  mirrored by `PatternView.back_side`), where the needle comes up (`StitchStyle`, see Planner
  rules) and position hints
  (`PositionHint`: the nearest findable stitch to count from, any colour: the last stitch
  made or the end of a run, never a stitch in the middle of a row of equal stitches; before the
  very first stitch the nearest corner of the pattern, landmark `CORNER`), `render/`
  the 3D fabric and thread (`StitchScene`: orthographic camera, Aida plane, one MultiMesh
  instance per leg or back stitch, soft shadows reusing the same MultiMeshes, the flip as a turn
  about a vertical axis with a little perspective from `flip.gdshaderinc`; `StitchTextures`
  makes the fabric and floss normal and shade maps procedurally on first use, in their own
  normal convention, not Godot's NORMAL_MAP; instance colours are passed as sRGB because the
  Compatibility renderer converts them itself), `ui/`
  views (`PatternView` draws `StitchScene` from a SubViewport and its 2D marks on top with the
  same grid-to-screen mapping; preview mode shows every cell as a finished cross, progress mode
  the stitched legs, the current block with an arrow along every leg (up hole to down hole) and
  its stitch count in a badge, the counting path in turquoise from hole to hole (from the
  reference's corner matching the needle's first hole to that hole, so each hop is a cell) with
  small numbers plus each leg's total in a badge like the block count, and the thread labels a cell away with a leader line, moved to the
  other side when a badge or the path is in the way; the block colour is orange or the button
  blue, whichever differs more from the thread (`contrast_color()`, CIEDE2000), the thread
  start/end marks switch to their second colour only when the first is closer than
  `MARK_MIN_DELTA_E`; `set_back_side(…, true)` animates the
  flip; gestures for touch and mouse: one or two fingers / right mouse drag pan, pinch / wheel
  zoom, tap = next (held back `DOUBLE_TAP_SECONDS` to rule out a double tap), double tap = back,
  two-finger double tap / double right click = new thread, swipe in from the right edge = flip,
  from the left edge = overview; `set_covered()` keeps steps clear of overlays), `StitchPanel`
  step guidance (texts in `info`, buttons in `controls`, so the touch layout can split them),
  `RoundButton` the round see-through touch buttons (lit by `round_button.gdshader` from the
  same light as the fabric, `tint_color` when on: the block colour while stitching, blue in the overview, symbols from `ButtonIcons` distance functions, tooltip on long press; `ButtonIcons.button_icon()`
  draws the same symbols white for ordinary buttons: menu, windows, project list),
  `OverlayWindow` the in-app windows in the overlays' look (dark rounded panel, title with a close
  button, scrolling content, buttons at the bottom, over a dimmed screen that takes all input and
  keys; slides up and fades in, back down and out; the settings, the project list and its rename
  and delete questions are ones; opening the file dialog, the project list or the settings closes
  the open touch overlays, menu included, and `main.gd` `_restore_overlays()` opens them again when
  it closes), `ProjectBrowser` the
  project list: open, rename, delete after a confirmation; the preview comes from
  `ProjectStore.preview()`, for now the source image, later meant to show the progress), `main.tscn`/`main.gd` the start screen (the sample image opens from the advanced settings): two layouts
  built from the same widgets, moved by `_apply_ui_mode()`: desktop (toolbar, side panel) and
  touch (view on the whole screen, round buttons for the menu top left, which closes itself on
  the next touch of the view unless pinned, the colour list / stitching buttons bottom left, the
  texts bottom right; all inside the display's safe area; `_set_overlay()` slides and fades
  them in and out (panels stacked in the dock move along as one), then the view glides the
  current step clear of them; the overview opens the
  colour list and info by itself), `ProgressStrip` the progress bar
  between the bottom round buttons (desktop: under everything): grey capsule track, capsule fill
  in the block colour (blue in the overview), progress counted in legs
  (`StitchSession.leg_progress()`, a half stitch is one of two); going up it flashes the new
  part white, pops and fills after it with long bands of light, at most two at a time, winding
  round the bar as if it were a solid tube (`progress_strip.gdshader`),
  `Celebration` the full-screen show when a colour is finished (dimmed screen, the bar flies to
  the middle and glows, CPUParticles2D confetti and sparkles, congratulation; a tap goes to the
  overview, whose bar then fills from where the project was when stitching began, and the colour
  is struck through in the list by `StrikeLine`; finished colours stay struck through; when that
  was the last colour, `Finale` follows: flash and screen shake, darkness around the pattern
  with turning golden rays (`finale.gdshader`), "MEISTERWERK!" letter by letter, fireworks,
  confetti, a count-up and a rainbow bar, then buttons: overview, new project (file dialog),
  open project (project list)); after every step the light swings once around on an oval
  (`StitchScene.orbit()`: shifted towards the light, so it rises towards overhead on the far side
  and never comes low from the opposite corner; `main.gd` `_spin_light()`), during both shows it
  keeps turning (`_loop_light()`),
  `SkeinSwatch` a thread colour drawn as a square of the pure
  colour with a loop of thread coming out of it (one colourless template image per shape,
  tinted by `skein.gdshader`, so it fades as one; tapping it opens the colour picker),
  `ThreadPicker`/`ThreadGrid` the colour picker that swipes in over the colour list: every DMC
  colour as skeins on stairs (loop up, square lengthened by the loop), greys first then by hue,
  rows light to dark; or as a list with number and name sorted by number (`by_number()`: B5200,
  Blanc, Ecru, then numeric), and/or only the project's colours
  moved together, every skein gliding to its new place or fading out; choosing one shrinks the others away, then "Ersetzen" calls
  `StitchProject.replace_color()` (colour list rows; "Auslassen" fades the whole row),
  `tests/run_tests.gd`, plus `project.godot` and the `*.import` files next to resources (they
  hold import settings: `data/threads/dmc-floss.csv` uses the "keep" importer so it isn't
  turned into a translation, `samples/*.png` use the "image" importer so `load()` returns an
  exact `Image`).
- Data: `data/threads/dmc-floss.csv` (DMC palette, CC BY 4.0, source and credit in
  `data/threads/SOURCE.md`; the credit must stay visible in the app). `samples/` holds test
  images.
- Generated / not project code: `.godot/`; `addons/godot_ai/` (third-party Godot AI MCP
  add-on, v4.3.1, MIT; update it only with the dock's Update button, never by extracting over
  it). It registers the autoload `_mcp_game_helper`, which only acts while a debugger is
  attached and sits idle in release builds. (Hands-off paths are in `USER_WORKFLOW.md`.)
- List paths are relative to the repo root.

### Verification

How to check a change; every fix and feature runs these. Godot binary:
`/Applications/Godot.app/Contents/MacOS/Godot` (4.7.2), called `$G` below.

1. `$G --headless --path . --import 2>&1 | grep -E "ERROR|WARNING"`: no output (parses every
   script and imports resources; run it first after adding a `class_name`).
2. `$G --headless --path . --script res://tests/run_tests.gd`: prints "All tests passed."
   and exits 0. Plain checks without a framework (Lab/CIEDE2000 against Sharma's reference
   pairs, DMC palette, importing the sample, stitch planner incl. that every cell of the sample
   is crossed exactly once, stitching progress, position hints and their wording, view gestures fed as touch events).
3. `$G --headless --path . --quit-after 120 -- --projects-dir=<scratch dir> --open=res://samples/hypsi_anhaenger.png --stitch=3837 --steps=7 2>&1 | grep -E "ERROR|WARNING"`:
   no output. Always pass `--projects-dir` with a scratch folder: every run that opens an image
   saves a project, and without it that lands in the user's real projects.
4. Screenshot (opens a window for a moment):
   `$G --path . --resolution 720x1280 -- --projects-dir=<scratch dir> --open=res://samples/hypsi_anhaenger.png --screenshot=<abs path>.png`,
   and again with `1280x720` for landscape; look at the PNGs. Add `--stitch=<DMC code>
   --steps=<n>` for the stitching screen after n confirmed steps, `--max-skip=<n>` to set the
   skip limit (-1: none), `--start=<auto|top-left|top-right|bottom-left|bottom-right>` the start corner, `--settings` to open the settings dialog, `--projects` the project list, `--back` the back side while stitching,
   `--method=<danish|english>`, `--back-pass=<whole|blocks>`, `--max-block=<n>`, `--needle=<auto|bottom|top>`, `--first-leg=<slash|backslash>`
   (both fix the style), `--advanced` with `--settings` for the advanced part, `--ui=<touch|desktop>` the layout,
   `--overlays=<menu,pin,list,text>` opens touch overlays, `--picker=<code>` the colour picker
   for a colour of the list, `--picker-view=<list,project>` its list view and/or project filter, `--pick=<code>` chooses a colour in it, `--tooltip=<menu|list|text>` shows a
   round button's tooltip, `--safe-area=<l>,<t>,<r>,<b>` fakes a notch or island (canvas px), `--finish` stitches the rest of the `--stitch` colour (the celebration comes in), `--dismiss` taps it away to the overview, `--finale` shows the finished-project show, `--wait=<seconds>` waits that long before the screenshot (e.g. into the bar's fill; otherwise screenshots wait for the fill), `--zoom=<cell px>`
   to zoom in on the current step, `--light=<azimuth>,<elevation>` (degrees; azimuth clockwise
   from the top) for the light (saved like the settings), `--flip=<0..1>` with `--back` to hold the flip animation
   at that point. Screenshots wait for a running flip to end. In zsh, pass each user
   argument as its own word (an unsplit `"$args"` arrives as one argument and is ignored).

Real touch input (pan, pinch, edge swipes against the system's own edge gestures), mouse
gestures in a running window, long-press tooltips and the native file dialog are not covered
by these; check them on a
device or in the editor and say so in the report. Resuming: run once with `--open` and
`--steps`, then again with only `--projects-dir` (the last project opens by itself).

### Save format

`StitchProject.to_dict()`, one JSON file per project, `format` 3 (2 added `progress.max_skip`
and `progress.manual_thread_starts`; format 1 files load with no limit and no manual changes;
3 added `color_replacements`, matched code -> code the user chose, applied by the importer on
every rebuild; older files load with none). It holds the image (PNG,
base64), fabric codes, the pattern itself (so palette or matching changes can't alter a pattern
being stitched) and progress as cell states; a step counts as done when the cells already show
it (`StitchSession.restore()`), so any plan order works; a step with stitched and unstitched cells is
split where they meet, so a longer step after replanning or two merged colours lose no stitches. `done_steps` per thread code is only
informational. Changing the format needs the user's OK and a new
`format` number with a migration for older files.

### Planner rules

Fixed in `src/planner/stitch_planner.gd`, decided with the user (DESIGN.md "Offene Punkte"):
a row segment ends at a gap of more than 3 cells (`MAX_GAP`); a segment of one stitch becomes a
single full cross; blocks hold at most `max_block` stitches (`Preferences.max_block()`, default 5 =
`DEFAULT_MAX_BLOCK`; `StitchSession.set_max_block()` replans like the skip limit) and are split evenly
(7 → 4 + 3); a block never has a gap inside: each run of adjacent cells is split on its own and
the thread skips on the back only between blocks; every segment starts at its end nearer to the needle (on a tie the start side; legs stay `/` then `\` either way), and the Danish return pass ends there. Order: segments
in neighbouring rows that overlap or touch diagonally form an area (`connected_areas()`); an
area is finished before the next and grows without holes (`_next_segment()`): first candidates
are open segments touching the one just finished, then open segments of the area touching any
finished one, then other areas. Within a tier the nearest to the needle wins (Chebyshev skip from
the end the last segment began at to the nearer end of the candidate), ties go to row order. `tests/run_tests.gd` checks on the
sample that every segment after an area's first touches an earlier one.

Whole return pass (`Preferences.whole_back()`, default on; `StitchSession.set_whole_back()`
replans): the Danish return pass is one `BACK` step per run of adjacent cells instead of blocks
of 5; half stitches stay in blocks, and a step still never spans a gap. Off: blocks as above.

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

Start corner: `Preferences.auto_start()` (default on) plans every thread from all four corners
(`StitchPlanner.plan_shortest()`) and keeps the one with the least thread on the back
(`thread_cost()`: straight-line way between steps, `THREAD_START_COST` per new thread; tie:
order of `CORNERS`, top left first). Off: `Preferences.top_to_bottom()` / `start_left()` (rows to
the right, then down, for top left) set the row order and the start side; they decide where the
first segment begins and break ties. Changing any of them replans via
`StitchSession.set_direction()` like the skip limit. `StitchSession.auto_start` is not saved in
the project file (no format change); `main.gd` `_apply_preferences()` pushes all three
preferences into the open project.

Progress: `StitchSession` keeps a done flag per planned step, not a count, because after
replanning finished stitches can lie anywhere in the new order. The current step is the first
not done (`current_index()`), "back" clears the last done step before it. The flags live in a
Dictionary of PackedByteArray (a value type): write them through `_set_flag()`.
