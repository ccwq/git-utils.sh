# Pitfalls Research

**Domain:** Shell-to-Python migration (wsha rewrite)
**Researched:** 2026-04-13
**Confidence:** MEDIUM-HIGH

## Critical Pitfalls

### Pitfall 1: Regex Greedy vs Lazy Matching Behavior

**What goes wrong:**
Python's `re` module uses lazy (non-greedy) matching by default with `.*?`, while bash's `=~` operator does not support lazy quantifiers at all. The shell script converts `.*?` to `(.*)` (greedy) as a workaround, but Python's default behavior differs from bash's explicit greedy conversion.

**Why it happens:**
```bash
# wsha.sh line 697: converts lazy to greedy
regex="${regex//\(.\*\?\)/(.*)}"

# But Python's re module will lazy-match by default with .*?
# which produces different capture results
```

**How to avoid:**
- Use `re.compile(pattern, re.DOTALL)` to make `.` match newlines
- Explicitly use greedy `.*` in Python when the original bash behavior was greedy
- Write test cases that verify capture groups match exactly between versions

**Warning signs:**
- `w "px*" something` produces different `$1` capture lengths
- Wildcard patterns with multiple segments behave differently
- Test failures in `quoted_wildcard` test mode

**Phase to address:**
Phase 2 (Pattern Matching) - needs regex equivalence testing

---

### Pitfall 2: Case-Insensitive Matching Inconsistency

**What goes wrong:**
Bash `${param,,}` (lowercase) and `${param^^}` (uppercase) require bash 4+. On case-insensitive comparisons, bash's `[[ "$a" == "$b" ]]` is locale-dependent. Python's `.lower()` is more consistent but may produce different results for Unicode characters.

**Why it happens:**
```bash
# wsha.sh line 657-658 uses bash 4+ lowercase expansion
local pat_lower="${pattern,,}"
local tok_lower="${token,,}"
```

**How to avoid:**
- Test for minimum bash version (4.0) and fail gracefully
- Use Python's `str.lower()` but ensure consistent Unicode handling
- Add locale-aware case folding for non-ASCII characters if needed

**Warning signs:**
- Aliases with non-ASCII characters (Chinese, etc.) behave differently
- CI tests pass but Windows Git Bash users report failures
- `match_token_pattern` tests fail intermittently by locale

**Phase to address:**
Phase 2 (Pattern Matching) - case handling is core to matching

---

### Pitfall 3: Tokenization and Word Spliting Differences

**What goes wrong:**
Bash tokenizes input using IFS and applies glob expansion, quote handling, and escape processing. Python's `shlex.split()` handles quotes differently from bash. The shell script's `get_tokens()` function has specific behavior that Python must replicate exactly.

**Why it happens:**
```bash
# wsha.sh token parsing - handles quoted aliases like "pcodex l"
# Python shlex.split("\"pcodex l\"") produces ['pcodex l']
# But bash sees "pcodex l" as a single token when quoted
```

**How to avoid:**
- Import and test `shlex.split()` behavior against bash tokenization
- Compare `get_tokens()` output token-by-token with Python equivalent
- Pay special attention to: empty tokens, escaped characters, mixed quotes

**Warning signs:**
- `"pcodex l"` treated as one token vs two in Python version
- Escape sequences like `\` handled differently
- Double-quoted strings with spaces parse incorrectly

**Phase to address:**
Phase 2 (Pattern Matching) - tokenization is foundational

---

### Pitfall 4: Configuration Loading State Mutation

**What goes wrong:**
The shell script uses global `declare -a` arrays (`ALIAS_KEYS`, `ALIAS_TEMPLATES`, etc.) that accumulate state across multiple function calls. Python's module-level globals can cause similar issues but manifest differently with import cycles and testing.

**Why it happens:**
```bash
# wsha.sh lines 157-158 - global mutable state
declare -a ALIAS_KEYS=()
declare -a ALIAS_TEMPLATES=()

# State modified by load_config(), find_best_match(), etc.
```

**How to avoid:**
- Use a class-based architecture with instance state
- Avoid module-level mutable state for core logic
- Make configuration a first-class object passed explicitly
- Design for thread-safety from the start (future-proofing)

**Warning signs:**
- Tests pass in isolation but fail when run in different order
- Global variables retain state between test cases
- `load_config()` called multiple times causes duplication

**Phase to address:**
Phase 1 (Core Architecture) - foundational design issue

---

### Pitfall 5: Cache File Format Incompatibility

**What goes wrong:**
The shell script writes a cache file with tab-separated values and uses `sha1sum` or `cksum` for cache keys. Python needs to produce byte-for-byte identical cache files to avoid unnecessary cache invalidation and to share cache between shell and Python versions.

**Why it happens:**
```bash
# wsha.sh line 371 - cache format
printf 'KEY\t%s\n' "$cache_key"
# ... tab-separated fields follow
```

**How to avoid:**
- Define a cache schema with exact field ordering and types
- Use Python's hashlib for SHA1 (matches sha1sum output)
- Test cache file format by writing a cache in Python and reading in bash
- Consider cache versioning to handle future format changes

**Warning signs:**
- Cache invalidates on every run when Python version runs first
- Cache files from Python can't be read by shell version
- `sha1sum` output format differs between GNU and BSD

**Phase to address:**
Phase 1 (Core Architecture) - caching is a key pain point from CONCERNS.md

---

### Pitfall 6: Subprocess Command Execution Differences

**What goes wrong:**
The shell script uses `eval -- "$cmd_text"` for complex commands and direct execution for simple ones. Python's `subprocess.run()` handles I/O redirection, environment variables, and shell features differently. Edge cases like shell built-ins, aliases, and PATH lookup behave differently.

**Why it happens:**
```bash
# wsha.sh line 911 - eval for complex commands
eval -- "$cmd_text"

# Python subprocess doesn't have eval equivalent
# Need to carefully replicate shell command parsing
```

**How to avoid:**
- For simple commands: use `subprocess.run()` with shell=False
- For complex commands: parse and reconstruct for shell=True
- Avoid Python-side eval entirely for security
- Test shell built-ins (cd, export, etc.) explicitly

**Warning signs:**
- Commands with pipes `|` work differently
- Redirection `>` and `<` not functioning
- Environment variable expansion in commands fails
- Exit codes differ for the same command

**Phase to address:**
Phase 3 (Command Execution) - invocation is the final step

---

### Pitfall 7: Path Separator and Cygwin Path Handling

**What goes wrong:**
Windows Git Bash uses Cygwin paths (/tmp, /usr/bin) but Python may see Windows paths (C:\...). The shell script uses `cygpath` in several places which Python cannot directly replicate without platform detection.

**Why it happens:**
```bash
# wsha.sh line 416 - cygpath usage in tests
# cygpath only exists in Cygwin/Git Bash, not in native Python Windows
```

**How to avoid:**
- Use `pathlib.Path` which handles cross-platform paths
- Detect Cygwin environment via `os.environ.get('OSTYPE', '').startswith('cygwin')`
- Provide fallback when cygpath unavailable
- Never assume POSIX paths on Windows

**Warning signs:**
- File not found errors on paths that exist
- Cache directory `~/.cache/wsha` fails to create
- `cygpath` command not found in Python subprocess

**Phase to address:**
Phase 1 (Core Architecture) - path handling is foundational

---

### Pitfall 8: Timestamp and Performance Measurement Differences

**What goes wrong:**
The shell script uses `date +%s%N` for nanosecond timestamps (with fallback to `date +%s` on BSD). Python's `time.time()` returns float seconds with nanosecond precision on modern systems. Differences cause performance test assertions to fail.

**Why it happens:**
```bash
# wsha.sh line 937 - nanosecond timestamps
step_start=$(date +%s%N 2>/dev/null || date +%s000000000)
```

**How to avoid:**
- Use `time.perf_counter_ns()` for highest precision
- Round to milliseconds for comparison with shell timing
- Use relative comparisons, not absolute thresholds
- Document timing is approximate and may vary

**Warning signs:**
- Performance tests fail with "too slow" even on fast hardware
- Timing logs show 0ms in Python but ms in shell
- Test assertions on timing are flaky

**Phase to address:**
Phase 1 (Core Architecture) - timing is used in test mode

---

### Pitfall 9: Exit Code Semantics

**What goes wrong:**
Bash treats certain exit codes specially (128+N for signals, 255 for generic errors). Python's `sys.exit()` defaults to 0 for success and 1 for failure. The test harness checks exit codes for success/failure detection.

**Why it happens:**
```bash
# Bash exit codes: 0=success, 1=general error, 128+N=signal N
# Python: 0=success, non-zero=failure, but no signal semantics
```

**How to avoid:**
- Match shell exit codes exactly (0, 1, 2 for usage errors)
- Use `sys.exit(0)` for success, `sys.exit(1)` for errors
- Handle signal-exited subprocesses by adding 128 to signal number
- Test exit codes explicitly in test suite

**Warning signs:**
- Tests report success when script actually failed
- Exit code 2 (usage error) treated as success
- Signal deaths produce wrong exit codes

**Phase to address:**
Phase 3 (Command Execution) - exit codes are part of interface contract

---

### Pitfall 10: Heredoc and Multi-line String Handling

**What goes wrong:**
The shell script uses heredocs for help text and multi-line output. Python has no direct equivalent; triple-quoted strings and `textwrap.dedent` must be used carefully. Indentation and trailing newline behavior differs.

**Why it happens:**
```bash
# wsha.sh line 8-46 - heredoc with no variable expansion (cat <<'EOF')
show_help() {
    cat <<'EOF'
wsha - alias command launcher
...
EOF
}
```

**How to avoid:**
- Use Python triple-quoted strings with `textwrap.dedent`
- Ensure trailing newline behavior matches
- Compare output byte-by-byte in tests
- Handle Windows CRLF vs Unix LF line endings

**Warning signs:**
- Help text has extra/missing newlines
- Indentation appears in output
- Diff tests fail on whitespace only

**Phase to address:**
Phase 3 (Command Execution) - help output is visible to users

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Reimplementing glob as regex | Avoids learning fnmatch | Regex edge cases differ from glob | Never - use `fnmatch` |
| Skipping cache format compatibility | Faster initial implementation | Cache invalidates constantly | Only in Phase 1 POC |
| Using shell=True everywhere | Simpler subprocess code | Security risk, platform differences | Only for complex shell features |
| Hardcoding paths | Works on developer machine | Fails on other systems | Only in throwaway scripts |
| Matching bash output exactly | Easier test writing | Brittle tests, false confidence | Only for user-visible output |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **Shared config files** | Python modifies format shell expects | Read-only config, Python uses same parser |
| **Shared cache directory** | Different hash algorithms | Use same sha1sum + cksum fallback |
| **Entry point w/wsha** | Inconsistent command-line interface | Unified argument parsing from start |
| **Environment variables** | Python doesn't inherit bash functions | Explicitly export needed vars |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| **O(n) alias lookup** | Slow with hundreds of aliases | Index by first token | At 100+ aliases |
| **Cache reads on every invocation** | Slow startup | Cache validation before full parse | Always - main shell pain point |
| **Regex recompilation per match** | Slow pattern matching | Pre-compile all patterns | With 50+ patterns |
| **Linear search through all aliases** | `find_best_match` is slow | Match scoring + early termination | At 500+ aliases |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| **Using Python eval** | Arbitrary code execution | Never eval user input; parse explicitly |
| **Insufficient path sanitization** | Path traversal attacks | Validate paths stay within expected directories |
| **Trusting config file content** | Malicious alias execution | Config files should be user-owned (600 perms) |
| **Shell injection via template vars** | `$1`, `$$` expansion issues | Escape special chars before shell execution |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| **Different help text formatting** | Confusing when switching versions | Match shell help output exactly |
| **Different error messages** | Harder to debug when things break | Replicate error message format and content |
| **Different list output format** | `--list` output differs | Match column format and content ordering |
| **Exit codes differ** | Script integration fails silently | Match shell exit codes exactly |

---

## "Looks Done But Isn't" Checklist

- [ ] **Pattern matching:** Have we verified `*`, `**`, `?` behavior matches bash exactly? Need edge case tests.
- [ ] **Cache format:** Can shell read Python-generated cache files? Test round-trip.
- [ ] **Tokenization:** Did we test quoted aliases `"pcodex l"` vs unquoted? Multiple spaces?
- [ ] **Exit codes:** Did we test error exits (alias not found, config missing)?
- [ ] **Wildcard captures:** Does `$1` capture correctly with `"px*"` pattern?
- [ ] **Double-star (`**`):** Does `$$` capture remainder correctly?
- [ ] **Argument insertion:** Does `--` placement work same as shell version?
- [ ] **Case sensitivity:** Does `foo` match `FOO`?
- [ ] **Performance:** Does Python version stay under test timeout?

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Regex mismatch | HIGH | Add regex equivalence test suite; iterate on pattern conversion |
| Cache incompatibility | MEDIUM | Write migration script; clear cache on version switch |
| Tokenization differences | HIGH | Add fuzzing tests; compare bash vs Python tokenization |
| Path handling issues | MEDIUM | Add platform detection; fallback to shell for paths |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Configuration loading state mutation | Phase 1: Core Architecture | Instance-based design, no global mutation |
| Cache file format incompatibility | Phase 1: Core Architecture | Round-trip cache read/write tests |
| Path separator handling | Phase 1: Core Architecture | Cross-platform path tests |
| Regex greedy vs lazy matching | Phase 2: Pattern Matching | Regex equivalence test suite |
| Tokenization differences | Phase 2: Pattern Matching | Token-by-token comparison tests |
| Case-insensitive matching | Phase 2: Pattern Matching | Unicode and locale test cases |
| Subprocess execution differences | Phase 3: Command Execution | Full integration tests against test suite |
| Exit code semantics | Phase 3: Command Execution | Explicit exit code tests |
| Heredoc handling | Phase 3: Command Execution | Output diffing against shell |
| Timestamp differences | Phase 1: Core Architecture | Timing-agnostic test design |

---

## Sources

Based on analysis of:
- `sh/wsha.sh` (1064 lines) - pattern matching, config loading, caching
- `__test__/wsha.test.sh` - 33KB test suite behavioral requirements
- `.planning/codebase/CONCERNS.md` - known defects and technical debt
- Shell-to-Python migration patterns and pitfalls
