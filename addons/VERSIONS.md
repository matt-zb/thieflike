# Vendored addon versions

Recorded at M0 project bootstrap. These addons are vendored (committed to
the repo), not downloaded at runtime. Update this file whenever an addon is
re-vendored at a newer tag.

## Godot

- **4.7.2-stable** — pinned per ARCHITECTURE.md §1.
  Headless build: https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip

## GUT (unit testing)

- **Tag:** v9.7.1
- **Commit SHA:** aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605
- **Source:** https://github.com/bitwes/Gut
- **Stated Godot compatibility:** README states "GUT versions 9.x are for
  Godot 4.x", no narrower pin found. Confirmed working under 4.7.2 via the
  M0 smoke test.

## func_godot (TrenchBroom .map / .vmf import)

- **Tag:** 2025.12
- **Commit SHA:** 169f2dd1461c0f166c81bf7e8c4fd6bce8af3a8a
- **Source:** https://github.com/func-godot/func_godot_plugin
- **Stated Godot compatibility:** README states "FuncGodot is a plugin for
  Godot 4", no narrower version pin found in plugin.cfg or README. Not yet
  exercised (no .map import until M10), but plugin loads without editor
  errors under 4.7.2.
