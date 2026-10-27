# Cleanup analysis

Running list of open cleanup findings, written by `/analyse-code` and worked off by
`/fix-next-finding`. Rules (ids, stamps, deleting fixed items) are in
`list-format.md` of the `dev-workflow` plugin's `setup-workflow` skill. All paths are relative to the repo root
unless noted. Items are roughly ordered by priority inside each section.

Passes:

Legend: **[H]** high — fix before building more on top, **[M]** medium, **[L]** low / nice to have.

---

## 1. Bugs

_Next id: 1.2_

### 1.1 [M] Needle instructions make diagonal back stitches on half passes to the left and return passes to the right

_Found: 2026-10-27 15:54 CET (`68737bd`)_

- The guide always brings the needle up through a bottom hole: "/" at the bottom left, "\" at
  the bottom right (`StitchPanel.describe_position()`, the needle dot in `PatternView`). For a
  half pass to the right and a return pass to the left this gives short vertical stitches on
  the back, as in the Danish method. For a half pass to the left (and a return pass to the right)
  the thread runs on the back from the top right of one cell to the bottom left of the next:
  a diagonal over two cells, about twice the thread, and the back no longer looks Danish.
  These passes happen whenever a segment starts at its right end (start corner on the right,
  or the nearer end after the previous segment).
- Seen in the new back view: `--start=top-right --stitch=3837 --steps=7 --back`.

**Done when:** every pass leaves vertical stitches on the back: a "/" pass to the left comes up
top right and goes down bottom left, a "\" pass to the right comes up top left; the text, the
needle dot and `BackSide.needle_holes()` agree, with a test for both directions.

**Notes for Claude:** changes the stitching instructions, so ask the user first (USER_WORKFLOW.md
"Ask before": stitching rules). The legs on the front stay "/" then "\"; only where the needle
comes up changes.

---

## 2. Performance

_Next id: 2.1_

_No open items._

---

## 3. Cleanliness / architecture

_Next id: 3.1_

_No open items._

---

## 4. Suggested order of work

_No open items._
