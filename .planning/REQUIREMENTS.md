# Requirements: git-utils.sh wsha Python

**Defined:** 2026-04-13
**Core Value:** 让命令行别名真正有用 — 通配符匹配、参数捕获、模板展开，而非静态字符串替换。

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Config System

- [ ] **CFG-01**: Python can parse wsh-alias.txt format (unquoted, quoted, comments)
- [ ] **CFG-02**: Multi-source config priority merge (built-in < user < project)
- [ ] **CFG-03**: Config caching with file timestamp validation in ~/.cache/wsha/
- [ ] **CFG-04**: `w --cache-clear` explicit cache invalidation
- [ ] **CFG-05**: Cache corruption error handling with informative messages

### Pattern Matching

- [ ] **MATCH-01**: User can use basic alias expansion — `w ab` → `pnpx agent-browser`
- [ ] **MATCH-02**: User can pass arguments through — `w foo --ping` → `foobar open --ping`
- [ ] **MATCH-03**: User can use `*` wildcard for single-token capture — `px*` matches `pxhttp-server`
- [ ] **MATCH-04**: User can use `**` double-star for remainder capture — `s**` captures `ls -l` as `$$`
- [ ] **MATCH-05**: User can use multiple capture groups — `f* *` captures `$1` and `$2`
- [ ] **MATCH-06**: Alias matcher selects best match using scoring: `alias_count*10000 + literal_chars*100 - wildcard_weight`
- [ ] **MATCH-07**: Unknown alias passthrough — `w echo hello` → `echo hello`
- [x] **MATCH-08**: Complex shell command passthrough (quoted commands, pipes, chains)

### Template Expansion

- [x] **TPL-01**: User can use `$1`, `$2` template replacement for captured tokens
- [x] **TPL-02**: User can use `$$` for remainder replacement (double-star capture)
- [x] **TPL-03**: User can use `--` placeholder to control where runtime args insert
- [x] **TPL-04**: User can use `%VAR%` environment variable expansion in templates
- [x] **TPL-05**: Quoted alias names with spaces — `"pcodex l"` defined as `echo codex-last`

### CLI Interface

- [ ] **CLI-01**: User can run `w --list` or `w -l` to show all aliases in table format
- [ ] **CLI-02**: User can run `w --list-view` or `w -lv` to show detailed view
- [ ] **CLI-03**: User can run `w --find <pattern>` to search aliases by pattern
- [ ] **CLI-04**: User can run `w --cache-clear` to clear the config cache
- [x] **CLI-05**: Exit codes match shell version behavior (0 = success, 127 = command not found)

### Shell Integration

- [ ] **SHELL-01**: Python implementation available via `uvx wsha`
- [ ] **SHELL-02**: Python implementation installable as pip global command `w`
- [ ] **SHELL-03**: Python version uses same wsh-alias.txt config as shell version
- [ ] **SHELL-04**: Fallback to wsha.sh when Python execution fails
- [ ] **SHELL-05**: Entry point `w <alias> [args...]` routes to Python by default
- [ ] **SHELL-06**: Duplicate alias detection within single config file
- [ ] **SHELL-07**: Invalid config file error handling with descriptive messages

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### CLI Enhancements

- **CLI-11**: Dry-run mode (`w --dry-run <alias>`) shows expansion without executing
- **CLI-12**: Shell completions (bash, zsh, fish) for `w` command

### Config Enhancements

- **CFG-11**: Config format variants (JSON, TOML support as alternative to flat text)
- **CFG-12**: Alias import/export functionality

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Real-time config watching | File watcher complexity, cross-platform issues. Manual cache clear is sufficient |
| Remote config sync | Auth, storage, conflict resolution complexity. User-managed dotfiles is the alternative |
| Shell-specific syntax (zsh/fish) | Breaks portability. Git Bash is primary target |
| Script evaluation in templates | Security risk with eval complexity |
| Interactive alias picker (FZF-like) | Heavy dependency, outside core scope. Token scoring provides deterministic selection |
| Plugin/package ecosystem | Maintenance burden, dependency hell. Builtin + user config is sufficient |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CFG-01 | Phase 1 | Pending |
| CFG-02 | Phase 1 | Pending |
| CFG-03 | Phase 1 | Pending |
| CFG-04 | Phase 1 | Pending |
| CFG-05 | Phase 1 | Pending |
| MATCH-01 | Phase 2 | Pending |
| MATCH-02 | Phase 2 | Pending |
| MATCH-03 | Phase 2 | Pending |
| MATCH-04 | Phase 2 | Pending |
| MATCH-05 | Phase 2 | Pending |
| MATCH-06 | Phase 2 | Pending |
| MATCH-07 | Phase 2 | Pending |
| MATCH-08 | Phase 3 | Complete |
| TPL-01 | Phase 3 | Complete |
| TPL-02 | Phase 3 | Complete |
| TPL-03 | Phase 3 | Complete |
| TPL-04 | Phase 3 | Complete |
| TPL-05 | Phase 3 | Complete |
| CLI-01 | Phase 4 | Pending |
| CLI-02 | Phase 4 | Pending |
| CLI-03 | Phase 4 | Pending |
| CLI-04 | Phase 4 | Pending |
| CLI-05 | Phase 3 | Complete |
| SHELL-01 | Phase 4 | Pending |
| SHELL-02 | Phase 4 | Pending |
| SHELL-03 | Phase 1 | Pending |
| SHELL-04 | Phase 4 | Pending |
| SHELL-05 | Phase 4 | Pending |
| SHELL-06 | Phase 1 | Pending |
| SHELL-07 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30/30 ✓
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-13*
*Last updated: 2026-04-13 after roadmap created*
