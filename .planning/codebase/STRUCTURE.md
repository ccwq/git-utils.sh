# Codebase Structure

**Analysis Date:** 2026-04-13

## Directory Layout

```
git-utils.sh/
├── bin/                    # Binary utilities
│   ├── win-helper/         # Windows Git Bash runtime helper
│   └── tcping.exe          # TCP connectivity checker
├── clink-lua-scripts/      # Clink auto-completion scripts
├── config/                 # Configuration files
│   ├── wsh-alias.txt       # Built-in alias definitions
│   └── wsh-ping.txt        # TCP ping presets
├── docs/                   # Documentation
├── openspec/               # OpenSpec related files
├── patch-files/            # Default output for wsh-fpatch
├── prompts/                # Prompt templates
├── scripts/                # Build/utility scripts
│   └── init.bat            # Installation script
├── sh/                     # Shell scripts (core utilities)
│   ├── exec-git-bash.bat   # Git Bash launcher (Windows entry)
│   ├── w.bat              # Windows alias launcher wrapper
│   ├── w.sh               # Unix alias launcher wrapper
│   ├── wsha.bat           # Windows wsha launcher
│   ├── wsha.sh            # Core alias expansion script (33KB)
│   ├── wsh.bat            # Windows Git Bash launcher wrapper
│   ├── wsh-fpatch.sh      # Git patch extraction utility
│   ├── wsh-ping.bat       # TCP ping launcher
│   ├── wsh-real-ignore.sh # Git untrack utility
│   └── wsh-replace-cn-punc.sh # Chinese punctuation replacer
├── __test__/               # Test suite
│   ├── report/             # Test execution reports
│   ├── wsha.test.sh        # wsha alias expansion tests
│   ├── wsh-fpatch.test.sh  # wsh-fpatch tests
│   ├── wsh-real-ignore.test.sh
│   ├── wsh-replace-cn-punc.test.sh
│   └── init.test.sh
├── .agent/                 # Agent skills (openspec)
├── .claude/                # GSD agent configuration
│   ├── agents/             # GSD agent definitions
│   ├── commands/           # GSD command definitions
│   └── skills/             # GSD skill definitions
├── .codex/                 # Codex configuration
├── .history/               # Command history
├── .iflow/                 # Flow state
├── .qwen/                  # Qwen configuration
├── .trae/                  # Trae configuration
└── test-all.sh             # Test runner script
```

## Directory Purposes

**sh/:**
- Purpose: Core shell scripts and Windows launchers
- Contains: All executable scripts (.sh and .bat)
- Key files: `wsha.sh` (largest, most complex), `wsh-fpatch.sh`, `wsh-real-ignore.sh`, `wsh-replace-cn-punc.sh`, `exec-git-bash.bat`

**bin/:**
- Purpose: Native Windows executables
- Contains: `tcping.exe` (TCP connectivity checker), `win-helper/` subdirectory
- Key files: `win-helper/win-helper.exe` (Git Bash runtime bridge)

**bin/win-helper/:**
- Purpose: Windows Git Bash helper source/build output
- Contains: Build scripts and compiled executable
- Key files: `win-helper.exe` (built binary)

**config/:**
- Purpose: Built-in configuration files
- Contains: Alias definitions and TCP ping presets
- Key files: `wsh-alias.txt` (primary alias config), `wsh-ping.txt` (TCP hosts)

**__test__/:**
- Purpose: Automated test suite
- Contains: Shell-based test scripts
- Key files: `wsha.test.sh` (33KB test suite), `wsh-fpatch.test.sh`, `test_utils.sh`

**scripts/:**
- Purpose: Build and installation scripts
- Contains: `init.bat` for PATH setup

**clink-lua-scripts/:**
- Purpose: Windows Clink shell auto-completion
- Contains: Lua scripts for command completion

**.claude/, .agent/, .codex/:**
- Purpose: Agent/AI assistant configurations (GSD framework, Codex, etc.)
- These are infrastructure for AI agents, not core functionality

## Key File Locations

**Entry Points:**
- `sh/exec-git-bash.bat`: Windows Git Bash invocation entry
- `sh/wsha.sh`: Core alias expansion logic
- `sh/w.bat`: Windows alias command entry
- `sh/w.sh`: Unix alias command entry
- `sh/wsh.bat`: Windows Git Bash launcher entry

**Configuration:**
- `config/wsh-alias.txt`: Built-in alias definitions
- `config/wsh-ping.txt`: TCP ping host presets

**Core Logic:**
- `sh/wsha.sh`: 1064 lines - alias expansion with wildcard matching, config caching
- `sh/wsh-fpatch.sh`: 286 lines - Git patch file extraction
- `sh/wsh-real-ignore.sh`: 67 lines - Git untrack utility
- `sh/wsh-replace-cn-punc.sh`: 101 lines - Chinese punctuation replacement

**Testing:**
- `__test__/wsha.test.sh`: 33KB comprehensive test suite
- `__test__/wsh-fpatch.test.sh`: 8KB patch extraction tests
- `test-all.sh`: Test runner that executes all `__test__/*.sh` files

**Build:**
- `package.json`: npm scripts for `init` and `build:win-helper`
- `bin/win-helper/build.bat`: Windows helper build script

## Naming Conventions

**Files:**
- Shell scripts: `snake_case.sh` (e.g., `wsh_real_ignore.sh`)
- Windows batch: `snake_case.bat` (e.g., `wsh.bat`)
- Core scripts prefixed with `wsh-` for Windows Shell utilities
- `wsha` = Windows Shell Alias
- Windows wrappers match Unix counterparts (e.g., `w.bat` wraps `w.sh`)

**Directories:**
- Lowercase with hyphens for functional dirs (`bin/`, `sh/`, `config/`)
- Underscores for special purposes (`__test__/`, `patch-files/`)

## Where to Add New Code

**New Shell Utility:**
- Primary implementation: `sh/<utility-name>.sh`
- Windows launcher (if needed): `sh/<utility-name>.bat`
- Tests: `__test__/<utility-name>.test.sh`
- Config (if needed): `config/` or documented for user-level config

**New Binary Utility:**
- Windows executable: `bin/<name>.exe` or `bin/<name>/`
- Source/build: `bin/<name>/` subdirectory with build scripts

**New Configuration:**
- Built-in defaults: `config/<name>.txt`
- Document in README.md for user-level override options

**New Test:**
- Test file: `__test__/<feature>.test.sh`
- Follow existing pattern: `bash "$test_file"` in test runner
- Reports auto-generate to `__test__/report/`

## Special Directories

**bin/win-helper/:**
- Purpose: Windows Git Bash runtime helper (Go binary)
- Generated: Yes (build output)
- Committed: Yes (includes source and build script)

**patch-files/:**
- Purpose: Default output directory for wsh-fpatch script
- Generated: Yes (when wsh-fpatch runs without -o option)
- Committed: No (in .gitignore)

**__test__/report/:**
- Purpose: Auto-generated test execution reports
- Generated: Yes (when tests run)
- Committed: Yes (sample reports may be committed)

**tmp-home/, tmp-work/:**
- Purpose: Temporary directories for testing
- Generated: Yes
- Committed: No (in .gitignore)

---

*Structure analysis: 2026-04-13*
