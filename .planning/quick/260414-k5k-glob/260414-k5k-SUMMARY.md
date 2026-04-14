---
phase: quick
plan: "260414-k5k"
type: execute
wave: 1
dependency_graph:
  requires: []
  provides:
    - "parser.py:parse_dir"
    - "parser.py:prefix_types"
    - "config.py:detect_duplicates"
    - "config.py:AliasEntry.prefix_type"
  affects: []
tech_stack:
  added:
    - "glob (stdlib)"
    - "PREFIX_NORMAL/PREFIX_SEQUENTIAL/PREFIX_OR constants"
    - "parse_dir() function"
    - "detect_duplicates() function"
key_files:
  created: []
  modified:
    - "py/wsha/parser.py"
    - "py/wsha/config.py"
    - "py/wsha/__init__.py"
    - "config/wsh-alias/main.txt"
decisions:
  - "Glob directory structure: config/wsh-alias/*.txt (1 level deep)"
  - "Prefix parsing: & for sequential, | for or"
  - "First-wins merging for duplicate names"
  - "Renamed config/wsh-alias.txt to config/wsh-alias/main.txt for directory glob"
metrics:
  duration: null
  completed_date: "2026-04-14"
  tasks_completed: 2
---

# Quick Task 260414-k5k Summary

## One-liner

Glob directory config loading with & and | prefix execution chains for wsha aliases.

## Completed Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | parser.py - glob & prefix | 456f36f | py/wsha/parser.py, py/wsha/__init__.py, config/wsh-alias/main.txt |
| 2 | config.py - dirs & dup detection | bd9f296 | py/wsha/config.py, py/wsha/__init__.py |

## Changes Made

### parser.py

- Added `parse_dir(dir_path)` function for glob loading `*.txt` files from directories
- Files starting with `_` are skipped
- Files processed in alphabetical order
- `parse_line()` now returns `(alias_name, template, prefix_type)` tuple
- Added `PREFIX_NORMAL`, `PREFIX_SEQUENTIAL`, `PREFIX_OR` constants
- `&foo` prefix indicates sequential execution (stop on error)
- `|foo` prefix indicates or execution (stop on success)

### config.py

- `get_default_config_paths()` now returns directory paths (`wsh-alias/`) instead of single files
- `load_config()` uses `parse_dir` for directories, `parse_file` for single files
- `AliasEntry` now includes `prefix_type` field
- First occurrence wins for duplicate alias names
- Added `detect_duplicates(aliases)` function to find same-named aliases with different content

### __init__.py

- Exports `parse_dir`, `PREFIX_*` constants, `detect_duplicates`

### config/wsh-alias/main.txt

- Moved original `config/wsh-alias.txt` to `config/wsh-alias/main.txt` to support glob directory loading

## Deviations from Plan

None - plan executed exactly as written.

## Verification

```bash
python -c "
from wsha.config import get_default_config_paths, load_config, detect_duplicates
paths = get_default_config_paths()
print('paths:', paths)
aliases, errors, sources = load_config()
print('loaded aliases:', len(aliases))
print('errors:', len(errors))
dup_errors = detect_duplicates(aliases)
print('duplicate errors:', len(dup_errors))
"
# Output: paths: {'builtin': '...'}, loaded aliases: 54, errors: 0, duplicate errors: 0
```

## Self-Check: PASSED
