# Feature Research

**Domain:** CLI alias/wildcard expansion tools
**Researched:** 2026-04-13
**Confidence:** MEDIUM

*Note: Web search tools were unavailable during research. Findings are based on analysis of existing wsha.sh implementation (1064 lines, 33KB test suite) and documentation from fish shell, zsh, and other shell ecosystems. Some competitor analysis is limited.*

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any alias tool. Missing these = product feels broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Basic alias mapping | Core purpose: short name -> full command | LOW | Essential, no alias tool exists without this |
| Argument passthrough | `alias foo echo` should still allow `foo bar` to become `echo bar` | LOW | Shell aliases do this by default with `$*` |
| Config file format | Users need to edit/view aliases; not just runtime | LOW | Flat file (wsh-alias.txt) is simple and portable |
| Help/list command | Users need to discover available aliases | LOW | `w --list` or `w -l` |
| Unknown alias passthrough | If user types unknown command, execute it directly | LOW | Fail gracefully, don't error on typos |
| Shell integration | Must work with existing shell workflow | MEDIUM | Entry point `w <alias>` is established pattern |

### Differentiators (Competitive Advantage)

Features that set wsha apart from basic shell aliases and justify its existence.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Wildcard patterns (`*`) | Single-token glob capture | MEDIUM | `px*` matches `pxhttp-server`, captures `http-server` as `$1` |
| Double-star capture (`**`) | Match all remaining input | MEDIUM | `s**` captures `ls -l` as `$$` for `wsh $$` |
| Token scoring/best match | When multiple aliases match, choose the best | HIGH | `alias_count * 10000 + literal_chars * 100 - wildcard_weight` |
| Multi-source config priority | Builtin < User < Project level override | MEDIUM | Merges from 3 sources, higher priority wins |
| Config caching with timestamp | Fast startup, skip parsing if configs unchanged | MEDIUM | Cache in `~/.cache/wsha/`, validate via `stat -c '%Y:%s'` |
| Template variable expansion | `$1`, `$2` for captured tokens, `$$` for remainder | LOW | Simple string replacement in template |
| `--` placeholder | Control where runtime args insert in template | LOW | Without it, args append at end |
| Environment variable expansion | Use `%VAR%` style in templates | LOW | `%APP_HOME%`, `%USERPROFILE%` |
| Quoted alias names | Define aliases with spaces: `"pcodex l"` | LOW | Parse with regex `^"([^"]+)"` |
| Shell command validation | Detect `&&`, `\|`, `;`, `>` for security | LOW | `is_complex_shell_command()` before `eval` |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems for this tool's scope.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time config watching | Want instant alias updates | Adds file watcher complexity, cross-platform issues | Manual cache clear: `w --cache-clear` |
| Remote config sync | Sync aliases across machines | Auth, storage, conflict resolution complexity | User-managed dotfiles + symlinks |
| Shell-specific syntax | Some users want zsh/fish features | Breaks portability; Git Bash is primary target | Keep POSIX-compatible core |
| Script evaluation in templates | Want `$(git rev-parse ...)` in aliases | Security risk, eval complexity | Pre-processing in wrapper scripts |
| Interactive alias selection | FZF-like picker for ambiguous matches | Outside core scope, adds heavy dependency | Token scoring provides deterministic best match |
| Multiple output formats | JSON, YAML, TOML config support | Over-engineering; flat text works fine | Keep `key value` format simple |
| Plugin/package ecosystem | Extend with third-party aliases | Maintenance burden, dependency hell | Builtin aliases + user config is sufficient |

## Feature Dependencies

```
[Config File Parsing]
    └──requires──> [Config Caching]
                          └──requires──> [Timestamp Validation]

[Wildcard Matching]
    └──requires──> [Tokenization]
                          └──requires──> [Glob-to-Regex Conversion]

[Token Scoring]
    └──requires──> [Wildcard Matching]
                          └──requires──> [Best Match Selection]

[Template Expansion]
    └──requires──> [Capture Extraction]
                          └──requires──> [Token Scoring]

[Multi-Source Merge]
    └──requires──> [Config File Parsing]
                          └──requires──> [Priority Override Logic]
```

### Dependency Notes

- **Config caching requires timestamp validation:** Can't cache without knowing if source changed
- **Token scoring requires wildcard matching:** Scoring weights wildcards
- **Template expansion requires capture extraction:** `$1` replacements come from match captures
- **Multi-source merge requires config parsing:** Must parse each source before merging

## MVP Definition

### Launch With (v1)

Minimum viable product - must pass existing `wsha.test.sh` (33KB, 22 test cases).

- [ ] Basic alias mapping - `w ab` -> `pnpx agent-browser` (from test: `test_expand_ab`)
- [ ] Argument passthrough - `w foo --ping` -> `foobar open --ping` (from test: `test_expand_foo_append`)
- [ ] `--` placeholder insertion - `w bar --age 40` -> `barbar --age 40 --name ccwq` (from test: `test_expand_bar_placeholder`)
- [ ] Unknown alias passthrough - `w echo hello` -> `echo hello` (from test: `test_unknown_alias_passthrough_with_args`)
- [ ] List command - `w --list` / `w -l` shows aliases in table (from test: `test_list_long_flag`)
- [ ] `*` wildcard single-token capture - `w pxhttp-server` -> `pnpx http-server` (from test: `test_wildcard_single_token_alias`)
- [ ] `**` double-star capture - `w sls -l` -> `wsh ls -l` (from test: `test_double_star_capture`)
- [ ] `$1` template replacement (from test: `test_wildcard_multi_capture`)
- [ ] `$$` remainder replacement (from test: `test_double_star_capture`)
- [ ] Multi-source config merge with priority (from test: `test_default_merge_priority`)
- [ ] Config caching with timestamp validation (from test: `test_default_missing_optional_configs_ignored`)
- [ ] Quoted alias names with spaces (from test: `test_quoted_alias_with_space`)
- [ ] Duplicate alias detection in single-file mode (from test: `test_duplicate_alias`)
- [ ] Invalid config error handling (from test: `test_invalid_mapping`)
- [ ] Environment variable expansion `%VAR%` (from test: `test_builtin_env_vars`)
- [ ] Shell command validation before eval (security)

### Add After Validation (v1.x)

Features to add once core works and tests pass.

- [ ] `--cache-clear` explicit cache invalidation
- [ ] `--find <pattern>` search aliases by pattern
- [ ] Better error messages for cache corruption
- [ ] Python-native hashing (avoid sha1sum/cksum dependency)

### Future Consideration (v2+)

Features to defer until product-market fit established.

- [ ] Shell completions (bash, zsh, fish)
- [ ] Config format variants (JSON, TOML support as alternative)
- [ ] Alias import/export
- [ ] Dry-run mode (`w --dry-run pxhttp-server` shows expansion without executing)

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Basic alias mapping | HIGH | LOW | P1 |
| Argument passthrough | HIGH | LOW | P1 |
| `*` wildcard capture | HIGH | MEDIUM | P1 |
| `**` remainder capture | HIGH | MEDIUM | P1 |
| Template `$1`, `$$` | HIGH | LOW | P1 |
| Multi-source config | HIGH | MEDIUM | P1 |
| Config caching | MEDIUM | MEDIUM | P1 |
| List command | HIGH | LOW | P1 |
| `--` placeholder | MEDIUM | LOW | P1 |
| Token scoring | HIGH | HIGH | P1 |
| Unknown passthrough | HIGH | LOW | P1 |
| `%VAR%` expansion | MEDIUM | LOW | P2 |
| Quoted aliases | MEDIUM | LOW | P1 |
| Cache clear command | LOW | LOW | P2 |
| `--find` search | LOW | MEDIUM | P3 |
| Shell completions | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch (required by test suite)
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Existing wsha.sh Features Mapped

All features below are validated by `__test__/wsha.test.sh`:

| Feature | Test Coverage | Status |
|---------|--------------|--------|
| `w <alias>` basic expansion | `test_expand_ab` | MUST HAVE |
| `w <alias> [args]` argument passthrough | `test_expand_foo_append` | MUST HAVE |
| `--` placeholder insertion | `test_expand_bar_placeholder` | MUST HAVE |
| Unknown alias passthrough | `test_unknown_alias_passthrough_with_args`, `test_unknown_alias_ping_passthrough` | MUST HAVE |
| Quoted alias names | `test_quoted_alias_with_space` | MUST HAVE |
| `*` wildcard single token | `test_wildcard_single_token_alias` | MUST HAVE |
| `*` wildcard multi token | `test_wildcard_multi_token_alias` | MUST HAVE |
| Multiple capture groups | `test_wildcard_multi_capture` | MUST HAVE |
| `**` double-star remainder | `test_double_star_capture` | MUST HAVE |
| `$1`, `$2` template replacement | `test_wildcard_multi_capture` | MUST HAVE |
| `$$` remainder replacement | `test_double_star_capture` | MUST HAVE |
| `--list` / `-l` table view | `test_list_long_flag`, `test_list_short_flag` | MUST HAVE |
| `--list-view` / `-lv` | `test_list_view_flag` | MUST HAVE |
| Multi-config merge priority | `test_default_merge_priority` | MUST HAVE |
| Missing optional configs ignored | `test_default_missing_optional_configs_ignored` | MUST HAVE |
| Merged alias list display | `test_default_list_merged_aliases` | MUST HAVE |
| Duplicate alias detection | `test_duplicate_alias` | MUST HAVE |
| Invalid config error | `test_invalid_mapping` | MUST HAVE |
| `%VAR%` env expansion | `test_builtin_env_vars` | MUST HAVE |
| Complex command passthrough | `test_quoted_complex_command_passthrough`, `test_quoted_and_chain_passthrough` | MUST HAVE |
| Error code preservation | `test_unknown_command_passthrough_error_code` | MUST HAVE |
| Quoted template equivalence | `test_quoted_content_equivalence` | MUST HAVE |

## Competitor Feature Analysis

| Feature | Shell Alias | zsh alias -s | fish abbreviation | wsha (ours) |
|---------|-------------|---------------|-------------------|-------------|
| Basic mapping | Yes | Yes | Yes | Yes |
| Argument passthrough | Manual ($*) | Manual | Via function | Automatic |
| Wildcard patterns | No | Limited | No | Yes (`*`, `**`) |
| Token scoring | No | No | No | Yes |
| Multi-source config | No | No | No | Yes (3 sources) |
| Config caching | No | No | No | Yes (timestamp) |
| Template vars | No | No | No | Yes ($1, $2, $$) |
| Shell portable | N/A | zsh only | fish only | Bash + Python |

**Analysis:** Shell built-in aliases are primitive. zsh suffix aliases (`alias -s`) handle file extensions only. fish abbreviations are simple text expansion. wsha competes by offering wildcard matching + scoring + caching that none of these provide.

## Sources

- **wsha.sh implementation:** `sh/wsha.sh` (1064 lines)
- **Test suite:** `__test__/wsha.test.sh` (33KB, 22 test cases)
- **Config file:** `config/wsh-alias.txt` (real-world examples)
- **fish shell docs:** Standard glob patterns, abbreviation vs function distinction
- **zsh docs:** Extended glob patterns, glob qualifiers, parameter expansion
- **Shell ecosystems:** Oh My Fish (unmaintained), starship (prompt only, not aliases)

---
*Feature research for: CLI alias/wildcard tool*
*Researched: 2026-04-13*
