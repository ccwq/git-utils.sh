# Codebase Concerns

**Analysis Date:** 2026-04-13

## Tech Debt

**Large Unstructured History Directory:**
- Issue: `.history/` contains 39+ backup files accumulated over time, including old test reports, AGENTS backups, config backups, and shell script backups
- Files: `.history/`
- Impact: Repository bloat, confusing for developers, these should be cleaned up or properly archived
- Fix approach: Archive or delete old history files; implement a cleanup policy

**Complex Alias Matching Architecture in wsha.sh:**
- Issue: Uses parallel arrays (`ALIAS_KEYS`, `ALIAS_TEMPLATES`, etc.) to simulate a map data structure, adding complexity
- Files: `sh/wsha.sh` (lines 157-172)
- Impact: Hard to maintain, error-prone when modifying alias storage
- Fix approach: Consider refactoring to use associative arrays or a more structured approach

**Caching Implementation with File System Dependencies:**
- Issue: Cache key generation uses `sha1sum` or `cksum` as fallback, but these may not be consistently available
- Files: `sh/wsha.sh` (lines 317-324)
- Impact: Cache may not work correctly on all systems
- Fix approach: Implement a more portable hash function or use a built-in bash approach

## Known Bugs

**macOS sed -i Incompatibility:**
- Symptoms: `sed -i` requires an empty string argument on macOS but not on GNU sed
- Files: `sh/wsh-replace-cn-punc.sh` (lines 77-82)
- Trigger: Running the script on macOS
- Workaround: The code does handle this with a check for `sed --version`, but it may not work reliably on all macOS versions

**Windows stat Command Incompatibility:**
- Symptoms: `stat -c` is GNU-specific and does not work on BSD/macOS stat
- Files: `sh/wsha.sh` (lines 299-300)
- Trigger: Running on non-GNU systems (macOS, some BSD)
- Workaround: Uses `2>/dev/null` fallback but this loses functionality

## Security Considerations

**Use of eval for Command Execution:**
- Risk: `eval -- "$cmd_text"` executes dynamically constructed commands
- Files: `sh/wsha.sh` (line 911)
- Current mitigation: Command is validated through `is_complex_shell_command()` before eval
- Recommendations: Consider using arrays for command construction instead of string eval; add additional input sanitization for alias templates

**Alias Template Injection Risk:**
- Risk: Alias templates with `$1`, `$2`, etc. could potentially be exploited if alias definitions contain user-controlled content
- Files: `sh/wsha.sh` (lines 1009-1016)
- Current mitigation: Templates come from config files which are typically user-controlled
- Recommendations: Document that config files should have appropriate permissions; consider adding a sandbox mode

**Config File Permission Requirements:**
- Risk: If config files (`wsh-alias.txt`) are world-writable, malicious aliases could be defined
- Files: `config/wsh-alias.txt`, `$HOME/.config/wsh-alias.txt`
- Current mitigation: None
- Recommendations: Document required permissions (600 or similar)

## Performance Bottlenecks

**Nested Loop in Alias Bucket Iteration:**
- Problem: `find_best_match()` iterates through candidate indexes in a loop, with inner token matching
- Files: `sh/wsha.sh` (lines 788-880)
- Cause: For each input, it iterates all matching bucket candidates and does token-by-token comparison
- Improvement path: Consider indexing by alias count to reduce candidates

**Cache File System Operations:**
- Problem: Each cache hit still requires reading and parsing the entire cache file
- Files: `sh/wsha.sh` (lines 335-362)
- Cause: Cache format stores all aliases in a single file
- Improvement path: Consider database or more granular caching

## Fragile Areas

**wsha.sh - Complex Token Matching Logic:**
- Files: `sh/wsha.sh` (lines 642-775)
- Why fragile: Regex construction for glob patterns, lazy vs greedy matching issues, bash regex limitations
- Safe modification: Extensive testing required for any changes to `match_token_pattern()` and `match_double_star_remainder()`
- Test coverage: `__test__/wsha.test.sh` covers many cases but pattern matching edge cases may exist

**wsha.sh - Windows Path Conversion:**
- Files: `sh/wsha.sh` (line 416: `cygpath` usage in tests)
- Why fragile: `cygpath` only exists on Cygwin/Git Bash, breaks on native Windows or Linux
- Safe modification: Guard all `cygpath` calls with platform checks

**w.sh - Exec Bash Entry:**
- Files: `sh/w.sh` (line 7: `exec bash`)
- Why fragile: If bash is not in PATH or has different behavior, script fails completely
- Safe modification: Add fallback or clearer error message

**wsh-replace-cn-punc.sh - Sed Replacement Array:**
- Files: `sh/wsh-replace-cn-punc.sh` (lines 36-54)
- Why fragile: Uses `"${sed_cmd[@]}"` which relies on proper array quoting; if array is empty, command fails silently
- Safe modification: Verify array is not empty before executing

## Scaling Limits

**Alias Count:**
- Current capacity: Unlimited in theory, but performance degrades with many aliases due to linear bucket iteration
- Limit: Hundreds of aliases before noticeable slowdown
- Scaling path: Implement alias indexing by first token AND alias count

**Config File Size:**
- Current capacity: Entire config is loaded into memory and parsed line-by-line
- Limit: Config files up to a few MB should work, but large configs are inefficient
- Scaling path: Lazy loading or indexed config parsing

## Dependencies at Risk

**External Tool: sha1sum/cksum:**
- Risk: `sha1sum` may not be available on all systems; `cksum` is more portable but output format differs
- Files: `sh/wsha.sh` (lines 319-323)
- Impact: Cache key generation would fail, causing config to be reloaded every time
- Migration plan: Use bash built-in `$RANDOM` or a pure bash hash implementation

**bin/tcping.exe:**
- Risk: Pre-compiled Windows binary, not available for Linux/macOS
- Files: `bin/tcping.exe`
- Impact: `sh/wsh-ping.bat` only works on Windows
- Migration plan: Consider a cross-platform alternative using bash sockets

## Missing Critical Features

**No Test Automation/CI:**
- Problem: Tests are run manually via `npm test` or `test-all.sh`
- Blocks: No automated verification on commit, no cross-platform test matrix
- Priority: High

**No Error Recovery in Cache Loading:**
- Problem: If cache file is corrupted, error message is not informative
- Files: `sh/wsha.sh` (line 338: `[[ -f "$cache_file" ]] || return 1`)
- Blocks: Debugging cache-related issues is difficult
- Priority: Medium

## Test Coverage Gaps

**Cross-Platform Shell Behavior:**
- What's not tested: BSD sed vs GNU sed differences, BSD stat vs GNU stat, bash version differences
- Files: `sh/wsh-replace-cn-punc.sh`, `sh/wsha.sh`
- Risk: Scripts may work on developer's Git Bash but fail on CI Linux or macOS
- Priority: High

**Error Path Testing:**
- What's not tested: What happens when git is not installed, when repo is corrupted, when permissions are denied
- Files: `sh/w.sh`
- Risk: Users get cryptic errors instead of helpful guidance
- Priority: Medium

**Alias Priority Edge Cases:**
- What's not tested: What happens when same alias appears in multiple config files with different priorities
- Files: `sh/wsha.sh` (lines 488-509)
- Risk: Behavior may not match documentation
- Priority: Low

---

*Concerns audit: 2026-04-13*
