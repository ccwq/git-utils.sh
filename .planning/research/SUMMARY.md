# Project Research Summary

**Project:** wsha - Wildcard Alias Expansion CLI
**Domain:** CLI alias expansion tool with wildcard matching
**Researched:** 2026-04-13
**Confidence:** MEDIUM-HIGH

## Executive Summary

This project rewrites the wsha.sh shell script in Python while maintaining full backward compatibility. The recommended approach is a "default Python, fallback shell" pattern where entry points attempt Python first, then fall back to bash. This preserves existing user workflows while enabling better debugging, cross-platform reliability, and easier testing via Python's native test frameworks.

The core functionality is alias expansion with wildcard matching: `w pxhttp-server` becomes `pnpx http-server`. The algorithm uses token scoring (alias_count * 10000 + literal_chars * 100 - wildcard_weight) to select the best match when multiple patterns could apply. Python implementation should achieve 250-400 lines vs the current 1064-line shell script due to native dict/list support.

Key risks center on behavioral equivalence: regex greedy matching differences, tokenization edge cases, and cache file format compatibility. Mitigation requires comprehensive test suite validation against the existing 33KB test file before any user-facing release. The phase structure prioritizes foundation work (config loading, path handling) before algorithm implementation (matching, expansion).

## Key Findings

### Recommended Stack

**Core technologies:**
- **Click 8.3.2** — CLI framework with decorator-based commands, auto-help, and lazy loading. Industry standard (17.4k stars) that handles argument parsing cleanly.
- **uv 0.11.6** — Package manager that is 10-100x faster than pip. Supports `uvx wsha` for run-without-install and `uv tool install` for global installation. Replaces pip/pipx/poetry.
- **pathlib** (stdlib) — Cross-platform path handling critical for Windows Git Bash compatibility where Cygwin paths (/tmp) vs Windows paths (C:\) cause issues.
- **fnmatch/re** (stdlib) — Wildcard and regex handling for alias matching.

**Python version:** 3.10+ required per existing project constraint.

### Expected Features

**Must have (table stakes — validated by test suite):**
- Basic alias mapping — `w ab` -> `pnpx agent-browser`
- Argument passthrough — `w foo --ping` -> `foobar open --ping`
- `*` wildcard single-token capture — `px*` captures `http-server` as `$1`
- `**` double-star remainder capture — `s**` captures `ls -l` as `$$`
- `$1`, `$2` template replacement and `$$` remainder replacement
- `--` placeholder for controlling argument insertion position
- Multi-source config priority (built-in < user < project)
- Config caching with timestamp validation
- Unknown alias passthrough (execute unknown commands directly)
- `--list` / `-l` table view of aliases
- Shell command validation before eval (security)

**Should have (competitive differentiators):**
- Token scoring algorithm for best-match selection
- Quoted alias names with spaces: `"pcodex l"`
- `%VAR%` environment variable expansion in templates
- `--cache-clear` explicit cache invalidation

**Defer (v2+):**
- Shell completions (bash, zsh, fish)
- Config format variants (JSON, TOML)
- Dry-run mode
- Alias import/export

### Architecture Approach

Python integration follows a thin-adapter pattern: shell wrappers (w.bat, w.sh) remain unchanged initially, calling a new wsha.py that provides Python implementations of config loading, matching, expansion, and execution. The architecture layers as: Entry Layer (shell wrappers) -> Python Adapter Layer -> Core Logic (pure Python, no shell dependencies).

**Major components:**
1. **ConfigLoader** — Parses wsh-alias.txt format, manages 3-source priority (built-in < user < project), handles file timestamp cache
2. **AliasMatcher** — Tokenization, bucket indexing by first token, scoring algorithm, pattern matching (*, **)
3. **TemplateExpander** — `$1`, `$2`, `$$` replacement, `--` placeholder logic
4. **Executor** — Command invocation via subprocess, exit code preservation

The data flow is deterministic O(n) where n = alias count. Bucket indexing provides effective scaling to 1000+ aliases.

### Critical Pitfalls

1. **Regex greedy vs lazy matching** — Bash's `=~` does not support lazy quantifiers; shell converts `.*?` to `(.*)` (greedy). Python's re module defaults to lazy with `.*?`. Must explicitly use greedy `.*` in Python to match bash behavior. Address in Phase 2.

2. **Tokenization differences** — Bash's `get_tokens()` handles IFS, glob expansion, and quote processing differently than Python's `shlex.split()`. Quoted aliases like `"pcodex l"` must parse as single token. Address in Phase 2.

3. **Cache file format incompatibility** — Shell writes tab-separated cache with sha1sum keys. Python must produce byte-for-byte identical files or disable cache in v1 to avoid constant invalidation on shell/Python switch. Address in Phase 1.

4. **Configuration loading state mutation** — Shell uses global `declare -a` arrays accumulating state. Python must use class-based instance state to avoid test order dependencies. Address in Phase 1.

5. **Path separator handling** — Windows Git Bash uses Cygwin paths (/tmp) but Python may see Windows paths. Use `pathlib` exclusively and detect Cygwin via `OSTYPE` environment variable. Address in Phase 1.

## Implications for Roadmap

Based on research, the following phase structure emerges from component dependencies and pitfall mapping.

### Phase 1: Core Architecture and Config Loading
**Rationale:** Foundation with no dependencies. Must establish path handling, config parsing, and cache schema before higher-level logic.
**Delivers:** Python package structure, ConfigLoader class, path utilities, cache format definition
**Addresses:** State mutation pitfalls, path handling, cache format
**Avoids:** Configuration loading state mutation, Path separator and Cygwin path handling, Cache file format incompatibility

### Phase 2: Pattern Matching Core
**Rationale:** Algorithm depends on ConfigLoader. Tokenization and regex matching are the hardest parts to get right.
**Delivers:** AliasMatcher class with tokenization, bucket indexing, scoring algorithm, glob-to-regex conversion
**Addresses:** Tokenization differences, regex greedy matching, case-insensitive matching
**Avoids:** Regex greedy vs lazy matching behavior, Tokenization and word splitting differences, Case-insensitive matching inconsistency

### Phase 3: Template Expansion and Command Execution
**Rationale:** Depends on matcher for capture extraction. Final integration step before shell wrapper modification.
**Delivers:** TemplateExpander class ($1, $2, $$, -- placeholder), Executor class (subprocess invocation, exit codes)
**Addresses:** Subprocess command execution differences, exit code semantics, heredoc handling
**Avoids:** Subprocess command execution differences, Exit code semantics, Heredoc and multi-line string handling

### Phase 4: Shell Integration and Fallback
**Rationale:** Must have working Python implementation before modifying shell wrappers. Fallback ensures no user breakage.
**Delivers:** wsha.py launcher, modified w.bat/w.sh to call Python first, fallback to wsha.sh on error
**Uses:** Click for CLI interface
**Implements:** Entry point flow with try/catch fallback pattern

### Phase 5: Test Compatibility and Validation
**Rationale:** Final validation against existing 33KB test suite. Must pass all existing tests before release.
**Delivers:** All 22 test cases passing, cache round-trip validation, behavioral equivalence verification
**Avoids:** All pitfalls require verification in this phase

### Phase Ordering Rationale

- **Config before matching:** Can't score aliases without parsed config
- **Matching before expansion:** Need capture groups before template substitution
- **Core before integration:** Python must work standalone before shell wrapper modification
- **Integration before testing:** Need integration layer for full test coverage
- **Testing as final:** All other phases build toward test validation

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Pattern Matching):** Regex equivalence is complex — may need dedicated regex test suite iteration
- **Phase 3 (Command Execution):** Subprocess edge cases (pipes, redirects, shell built-ins) may reveal additional pitfalls

Phases with standard patterns (skip research-phase):
- **Phase 1:** Standard Python project structure, well-documented pathlib usage
- **Phase 4:** Click CLI patterns are well-established

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Click/uv versions verified on GitHub, but web search unavailable during research |
| Features | MEDIUM | Based on existing wsha.sh implementation and test suite, not competitor research |
| Architecture | HIGH | Detailed analysis of wsha.sh (1064 lines), clear component boundaries |
| Pitfalls | MEDIUM-HIGH | 10 pitfalls identified with prevention strategies, but edge cases may emerge during implementation |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Cache format exact specification:** Not fully documented in ARCHITECTURE.md — need to extract exact field layout from wsha.sh during Phase 1
- **Regex equivalence testing:** Need to create test cases comparing Python vs bash regex behavior for all wildcard patterns
- **Tokenization edge cases:** shlex.split() behavior vs bash get_tokens() needs empirical validation

## Sources

### Primary (HIGH confidence)
- `sh/wsha.sh` (1064 lines) — Core implementation reference
- `__test__/wsha.test.sh` (33KB, 22 test cases) — Behavioral requirements
- `.planning/codebase/ARCHITECTURE.md` — Existing flow documentation

### Secondary (MEDIUM confidence)
- Click GitHub (v8.3.2, 2026-04-03) — CLI framework recommendation
- uv GitHub (v0.11.6, 2026-04-09) — Package manager recommendation
- .planning/codebase/CONCERNS.md — Known defects and technical debt

### Tertiary (LOW confidence)
- fish/zsh shell documentation — Feature comparison, needs validation against actual behavior

---
*Research completed: 2026-04-13*
*Ready for roadmap: yes*
