---
name: project-cross-platform-safeguards
description: Hand and Seal already has strong cross-platform infrastructure in place (verify_content.py, .gitattributes, .gitignore) — check it still passes rather than re-deriving from scratch.
metadata:
  type: project
---

Hand and Seal (C:\HREGAME) is developed on both a Mac laptop and a Windows desktop
against one Git repo. A source file was once silently corrupted by a PowerShell
rewrite that round-tripped it through cp1252 (turned em dashes into mojibake).
That incident is why `tools/verify_content.py` exists and runs a `check_encodings()`
pass over scripts/tests/tools/data/scenes on every invocation, checking for:
cp1252 double-encoding artifacts, UTF-8 BOM, CRLF line endings, and invalid UTF-8.

The project also already has, as of the 2026-07-28 review:
- `.gitattributes` forcing `eol=lf` on all text formats (.gd/.tres/.tscn/.json/.md/.cfg/.svg/.uid).
- `.gitignore` excluding `.godot/`, OS junk (.DS_Store, Thumbs.db, etc.), and the
  workspace-local `.tools/` (portable Godot binary) and `.godot-*.log` files.
- A documented, deliberate note that `*.uid` files ARE committed on purpose
  (Godot 4.4+ `.gd.uid` sidecars — omitting them causes UID desync between machines).
- `config/features=PackedStringArray("4.3", ...)` in project.godot deliberately
  targets an OLDER engine version than what's actually run (4.6.3), documented
  in project.godot's own header comment as intentional (older-declared-version
  opens clean in newer editors; a newer-declared version can break in an older one).

**Why:** Explains why cross-platform findings have been sparse in reviews so far —
the obvious failure modes are already guarded against structurally, not by luck.

**How to apply:** Run `python tools/verify_content.py` early in a review to confirm
these guards still pass (it is cheap and catches most silent corruption). Still
manually verify NEW files/resource references for case-sensitive filename matches
against the actual filesystem listing (case-insensitive filesystems on both Win/Mac
will hide a mismatch that only breaks on Linux export or on a case-sensitive
checkout) — verify_content.py does not check this, so it must be done by directly
listing directories and comparing exact strings, not by using `test -f` (which is
case-insensitive on both dev platforms and will falsely report success).
