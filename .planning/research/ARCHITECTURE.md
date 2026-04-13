# Architecture Research: Python wsha Integration

**Domain:** CLI alias expansion tool with wildcard matching
**Researched:** 2026-04-13
**Confidence:** HIGH

## Executive Summary

Python wsha should integrate as a drop-in replacement for wsha.sh core logic, with shell wrappers (w.bat, w.sh) remaining as thin adapters. The architecture follows a "default Python, fallback shell" pattern where entry points attempt Python first, then fall back to bash. This maintains full backward compatibility while enabling better debugging, cross-platform reliability, and easier testing via Python's native test frameworks.

## Current Architecture Analysis

### Existing Entry Points

```
w <alias> [args...]
    │
    ├─ Windows: w.bat → exec-git-bash.bat → bash wsha.sh
    │   (Sets WSHA_ENTRY=w)
    │
    └─ Unix: w.sh → bash wsha.sh
        (Sets WSHA_ENTRY=w)
```

### Current wsha.sh Flow (lines 918-1059)

```
main()
    │
    ├─ set_app_env()          # Setup APP_HOME, APP_SH, PATH
    ├─ load_config()          # Multi-source config + cache
    │   ├─ load_alias_cache() # Try cache first
    │   └─ load_single_config_file() # Parse wsh-alias.txt
    │
    ├─ find_best_match()      # Bucket + scoring algorithm
    │   ├─ Bucket by first token (literal vs wildcard)
    │   ├─ Score = alias_count*10000 + literal_chars*100 - wildcard_weight
    │   └─ Template capture extraction
    │
    ├─ Template expansion     # $1, $2, $$, $$ replacement
    ├─ Runtime arg handling   # -- placeholder logic
    └─ invoke_cmd()          # eval or token array exec
```

### Config Format (wsh-alias.txt)

```
# Comment lines ignored
ab echo agent-browser              # unquoted: alias + template
"pcodex l" echo codex-last         # quoted alias (spaces allowed)
"px*" echo pnpx $1                 # single wildcard capture
"s**" echo wsh $$                  # double wildcard (rest of input)
bar echo barbar -- --name ccwq     # -- placeholder for runtime args
```

**Three config sources with priority:**
1. `$APP_HOME/config/wsh-alias.txt` (built-in)
2. `$HOME/.config/wsh-alias.txt` (user-level)
3. `$PWD/.config/wsh-alias.txt` (project-level)

## Recommended Python Architecture

### Component Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│  Entry Layer (shell wrappers - NO CHANGES NEEDED)           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                      │
│  │ w.bat   │  │ w.sh    │  │ wsha.sh │  (fallback only)     │
│  └────┬────┘  └────┬────┘  └────┬────┘                      │
│       │            │            │                            │
├───────┴────────────┴────────────┴───────────────────────────┤
│  Python Adapter Layer (thin shim)                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │ wsha.adapter: arg parsing, env setup, exit handling │    │
│  └──────────────────────────┬──────────────────────────┘    │
│                             │                                │
├─────────────────────────────┴───────────────────────────────┤
│  Core Logic (pure Python - no shell dependencies)            │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ ConfigLoader │  │ AliasMatcher │  │ TemplateExpander│    │
│  │ - cache      │  │ - bucket idx │  │ - $1, $2, $$  │     │
│  │ - priority   │  │ - scoring    │  │ - -- placeholder│   │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Project Structure

```
wsha/                          # Python package
├── __init__.py              # Exposes main entry point
├── adapter.py               # Shell adapter: env setup, exit codes
├── config.py                # ConfigLoader: parsing, cache, priority
├── matcher.py               # AliasMatcher: tokenization, bucket, scoring
├── expander.py              # TemplateExpander: variable replacement
└── cli.py                   # CLI interface (if standalone)

sh/
├── wsha.py                  # NEW: Python launcher (replaces wsha.sh call)
├── w.bat                    # MODIFY: call wsha.py instead of wsha.sh
├── w.sh                     # MODIFY: call wsha.py instead of wsha.sh
└── wsha.sh                  # KEEP: fallback mode only

__test__/
├── wsha.test.sh             # Existing tests (MUST PASS)
└── test_wshao_python.py     # NEW: Python test suite
```

### Entry Point Flow (Recommended)

```
User: w pcodex
    │
    ├─ w.bat / w.sh
    │   └─ Checks WSHA_TRY_PYTHON=true (default)
    │       ├─ TRY: python/wsha.py (via Git Bash python)
    │       │   └─ Success: exit with code
    │       └─ CATCH: fallback to wsha.sh
    │
    └─ Output same as before
```

**Alternative (simpler): Direct Python call**

```
User: w pcodex
    │
    ├─ w.bat → exec-git-bash.bat → bash wsha.py (Python script)
    │   └─ wsha.py is a Python script with #!/usr/bin/env python3
    │
    └─ Same output
```

### Build Order (Dependencies)

```
Phase 1: Config Loader (foundation)
    - Parse wsh-alias.txt format
    - Priority merging (built-in < user < project)
    - File timestamp cache
    => No shell dependencies, testable immediately

Phase 2: Matcher Core (algorithm)
    - Tokenization (preserve current behavior)
    - Bucket indexing
    - Scoring algorithm
    - Pattern matching (*, **)
    => Depends on Config Loader

Phase 3: Template Expander
    - $1, $2, ... replacement
    - $$ rest capture
    - -- placeholder logic
    => Depends on Matcher

Phase 4: Integration Shell Script
    - wsha.py wrapper in sh/
    - Modify w.bat, w.sh to call Python
    - Fallback to wsha.sh on error

Phase 5: Test Compatibility
    - Run existing wsha.test.sh
    - Fix any behavioral differences
    => Final validation
```

### Data Flow

```
Input: w px http-server
    │
    ▼
┌─────────────────┐
│ Config Loader  │ ← wsh-alias.txt (3 sources)
│ Returns: Alias[]│ ← name, template, metadata
└────────┬────────┘
         │ deserialize
         ▼
┌─────────────────┐
│ Alias Matcher   │
│ 1. Tokenize     │ ← "px" "http-server"
│ 2. Find bucket  │ ← px → candidate indices
│ 3. Score each  │ ← best = "px *"
│ 4. Extract caps│ ← $1 = "http-server"
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Template Expander│ ← "pnpx $1"
│ 1. Replace $1  │ ← "pnpx http-server"
│ 2. Handle --   │ ← append remaining args
│ 3. Final cmd   │ ← "pnpx http-server"
└────────┬────────┘
         │
         ▼
    invoke_cmd()
```

### Anti-Patterns to Avoid

**Anti-Pattern 1: Complete Rewrite Without Compatibility Layer**

**What:** Replace wsha.sh entirely with Python, breaking existing users
**Why bad:** Users with custom workflows, PATH setups, or embedded wsha.sh calls break
**Instead:** Keep wsha.sh as fallback, make Python an opt-in enhancement

**Anti-Pattern 2: Mixing Shell and Python Data Structures**

**What:** Use shell array serialization to pass complex data to Python
**Why bad:** Fragile, hard to debug, Windows path issues
**Instead:** Python reads config files directly, no shell data structure passthrough

**Anti-Pattern 3: Different Config Cache Format**

**What:** Implement Python cache incompatible with shell cache
**Why bad:** Cache invalidation on Python/shell switch, stale data
**Instead:** Use same cache key algorithm (file paths + mtime + size), or disable cache in v1

## Integration Points

### With Existing Shell Architecture

| Point | Current | Python Integration |
|-------|---------|-------------------|
| `w.bat` | calls `wsha.sh` | calls `wsha.py` with fallback |
| `w.sh` | calls `wsha.sh` | calls `wsha.py` with fallback |
| `wsh-alias.txt` | read by wsha.sh | read by Python directly |
| Cache | `~/.cache/wsha/*.cache.sh` | Python writes same format OR disabled |
| Exit codes | 0/specific errors | Match shell behavior |

### Config File Compatibility

Python MUST parse existing wsh-alias.txt without modification:
- Unquoted lines: `alias template`
- Quoted alias: `"alias with spaces" template`
- Comments: `# ignored`
- Priority: built-in < user < project
- Env vars: `%VAR_NAME%` expansion

### Fallback Strategy

```bash
# w.bat / w.sh new behavior
WSHA_TRY_PYTHON=${WSHA_TRY_PYTHON:-true}
if [[ "$WSHA_TRY_PYTHON" == "true" ]]; then
    python "$APP_SH/wsha.py" "$@" 2>/dev/null
    [[ $? -ne 127 ]] && exit $?  # Python exists and ran
fi
# Fallback
bash "$APP_SH/wsha.sh" "$@"
```

## Scaling Considerations

This tool has deterministic O(n) performance where n = alias count.

| Scale | Current Behavior | Python Impact |
|-------|------------------|---------------|
| 0-100 aliases | Fast enough | Same |
| 100-1000 aliases | Bucket indexing helps | Same algorithm |
| 1000+ aliases | Consider trie | Future optimization |

**Scaling priorities:**
1. Cache hit rate (already solved in shell version)
2. Config file size (disk I/O bound, same in Python)
3. Pattern matching (O(n) per alias, same algorithm)

## Sources

- Current wsha.sh implementation (lines 1-1064)
- wsha.test.sh for behavioral requirements
- PROJECT.md for milestone constraints
- ARCHITECTURE.md (existing) for current flow documentation

---

*Architecture research for: Python wsha integration*
*Researched: 2026-04-13*
