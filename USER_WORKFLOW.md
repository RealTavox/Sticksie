# Workflow

How Claude's workflow skills (`/analyse-code`, `/fix-next-finding`, `/plan-features`,
`/pitch-feature`, `/implement-next-feature` and their loops) should work in this project.
This file is yours: edit it by hand whenever you change your mind. Claude only edits it when
you ask. Facts about the code (verification commands, code scope, invariants) live in
`CLAUDE.md`, which Claude keeps current; list rules are in
`list-format.md` of the `dev-workflow` plugin's `setup-workflow` skill.

---

## Design docs

Where the intent of the project is written down. `/plan-features` measures every idea against
these; the implement skills read them before building.

- `DESIGN.md`: the whole app design (in German): import, guided stitching with the Danish
  method, blocks of at most 5, smart position hints, thread changes, front/back views, settings,
  platforms, open points and the build order.

Claude does not edit these unless asked.

Conflicting ideas: allowed rarely, tagged [CONFLICT].

---

## Idea sources

Angles `/plan-features` should look from, in rough order of importance. Gaps against the design
docs always come first.

- Build order: the next step of "Reihenfolge der Umsetzung" in `DESIGN.md`; steps 1–3 (import,
  stitch planner, guided stitching) before anything visual.
- Open points: the "Offene Punkte" in `DESIGN.md` (gaps in a row, scattered single stitches,
  saving progress, fabric count and thread length).
- The stitcher's view: what someone with needle in hand, phone on the table, needs to not lose
  their place (one-hand use, big tap targets, clear next step, resume after days).
- Pattern quality: better thread colour matching, fewer thread changes, less counting.
- Mobile: portrait and landscape, small phones and tablets, battery (low processor mode).
- Feel: animation and thread look, once the core works.

---

## Analysis focus

What `/analyse-code` should weigh most here, beyond the generic bugs / performance / cleanliness
checks.

- Stitch planner: correct Danish order (half stitches out, cross stitches back), blocks of at
  most 5, every pixel covered exactly once, no long jumps on the back.
- Saved progress: a project lasts weeks; save format changes must not lose a user's progress.
- Rendering: must stay smooth for large patterns (e.g. 200×200) on older phones with the
  Compatibility renderer; redraw only on change.
- Colour matching: Lab distance, not RGB.

### Don't flag

Deliberate choices a pass should not report as problems.

- Compatibility renderer instead of Forward+/Mobile: needed for older devices and web.
- Only already-stitched cells are shown, no template overlay: deliberate design.

---

## Hands-off paths

Never edited by any skill (vendored code, scratch files, assets you manage yourself). Not
reported as findings either.

- `.godot/`: Godot's cache, generated.
- `DESIGN.md`: edited only when you ask (see Design docs).

---

## Ask before

Changes the skills must not make without your OK (unattended runs skip such items and ask at
the end). These add to the generic rules: big refactors, items marked "verify", design
questions.

- Changes to the save format of stitching projects.
- Adding addons or third-party libraries (including a test framework).
- Changing `project.godot` settings (renderer, window size, stretch mode, orientation).
- Changing the stitching rules from `DESIGN.md` (Danish method, block size, top leg direction).

---

## Commits

[Conventional Commits](https://www.conventionalcommits.org/): `type(scope)!: description`.

- Scope optional, from the list below. `!` marks a breaking change (e.g. an incompatible change
  of a saved or public format), explained in a `BREAKING CHANGE:` footer.
- Description: lowercase, imperative ("add", not "added"), no trailing period; subject line at
  most 72 characters. Optional body after a blank line: why, and anything not obvious from
  the diff.
- The type follows what the change does, not where it came from: a bug from the analysis list
  is `fix`, a cleanup finding is `refactor`, a performance finding is `perf`, a stale doc is
  `docs`.
- Workflow items are referenced in a footer (see `list-format.md`):
  `Refs: analysis 1.4 (<item title>)`.

Types:

- `feat`: new feature for the user
- `fix`: bug fixed in a user feature
- `docs`: documentation only
- `style`: formatting, no code change
- `refactor`: restructuring code without changing behaviour
- `perf`: performance improvement; the message says what got better (CPU, memory, GPU, load
  time) and by how much, measured where possible
- `test`: adding, refactoring or changing tests, no production code change
- `ci`: CI pipeline
- `build`: build scripts or tools
- `chore`: anything else (config, dependencies, the workflow list files)
- `revert`: reverting an earlier commit (`revert: <subject of the reverted commit>`, body
  `This reverts commit <hash>.`)

### Scopes

If no scope fits, commit without one and tell me in the answer, with a suggestion for a new
scope to add here.

- `import`: loading pixel art (PNG) and turning it into a pattern grid
- `palette`: thread palette (e.g. DMC) and Lab colour matching
- `planner`: stitch order, Danish rows, blocks ≤ 5, position hints, thread changes
- `guide`: guided stitching flow, highlighting, confirming steps
- `render`: 3D fabric and thread, front/back, flip, stitch animations
- `ui`: menus, screens, buttons, layout for phone/tablet
- `save`: saving and loading projects and progress
- `settings`: user settings (stitch direction, top leg)
- `editor`: the in-app pixel art editor
- `workflow`: the workflow list files and `USER_WORKFLOW.md`
