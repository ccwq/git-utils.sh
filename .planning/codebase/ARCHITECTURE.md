# Architecture

**Analysis Date:** 2026-04-13

## Pattern Overview

**Overall:** Utility Script Collection with Cross-Platform Windows Git Bash Abstraction

**Key Characteristics:**
- Shell scripts (.sh) with Windows batch file (.bat) wrappers for cross-platform support
- Primary purpose: Enhance Windows Git Bash experience and provide Git-related utilities
- Entry point pattern: Windows uses batch files that invoke `exec-git-bash.bat` or `win-helper.exe`, Unix-like systems directly execute shell scripts
- Configuration-driven alias expansion with wildcard support

## Layers

**Shell Scripts (Core Logic):**
- Purpose: Cross-platform utility implementations
- Location: `sh/`
- Contains: Git helpers, alias expansion, file processing
- Depends on: Standard Unix tools (sed, git, grep, awk)

**Windows Launchers (Platform Abstraction):**
- Purpose: Windows-specific entry points that resolve Git Bash and invoke shell scripts
- Location: `sh/*.bat`
- Contains: Batch files that wrap shell script invocations
- Depends on: `bin/win-helper/win-helper.exe` (if available), `exec-git-bash.bat`

**Binary Utilities:**
- Purpose: Provide Windows-native functionality (TCP ping, Git Bash helper)
- Location: `bin/`
- Contains: `tcping.exe`, `win-helper/` directory

**Configuration Layer:**
- Purpose: User-customizable alias and preset configurations
- Location: `config/`, `$HOME/.config/`, `$PWD/.config/`

## Data Flow

**wsha (Alias Expansion) Flow:**

1. User invokes `w <alias> [args...]` via Windows batch or `bash sh/wsha.sh` on Unix
2. Script loads alias configs from three sources with priority merge
3. Config cached to `~/.cache/wsha/*.cache.sh` with file timestamp validation
4. Input tokenized and matched against alias patterns using bucket indexing
5. Best match selected by scoring: `alias_count * 10000 + literal_chars * 100 - wildcard_weight`
6. Template variables (`$1`, `$2`, `$$`) replaced with captured values
7. `--` placeholder or append logic applied for runtime args
8. Command executed via `eval` or normalized token array

**wsh (Git Bash Launcher) Flow:**

1. User invokes `wsh [args...]` via `sh/wsh.bat`
2. Batch file checks for `bin/win-helper/win-helper.exe` (preferred)
3. Falls back to `exec-git-bash.bat` path resolution logic
4. Git Bash resolved via: inherited env -> HKCU registry cache -> `where git` relative -> default install paths
5. Git Bash path cached in registry for subsequent calls
6. Command passed to Git Bash for execution

**wsh-fpatch (Patch Extraction) Flow:**

1. Parse commit arguments and filter options (`-i`, `-e`)
2. Verify running in Git repository
3. Determine diff mode: single commit vs current worktree, or two commits
4. Collect changed files via `git diff --name-only` and `git ls-files`
5. Apply include/exclude filters based on glob patterns
6. Copy current worktree versions of changed files to output directory preserving structure

## Key Abstractions

**win-helper (Windows Runtime Bridge):**
- Purpose: Native Windows executable to launch Git Bash with proper path handling
- Examples: `bin/win-helper/win-helper.exe`
- Pattern: Binary that wraps Git Bash invocation, fallback when batch insufficient

**exec-git-bash (Git Bash Resolver):**
- Purpose: Batch script to locate and invoke Git Bash on Windows
- Examples: `sh/exec-git-bash.bat`
- Pattern: Multi-strategy Git Bash discovery with registry caching

**wsha (Alias Launcher):**
- Purpose: Configuration-driven command expansion with wildcard matching
- Examples: `sh/wsha.sh` (core), `sh/w.bat` (Windows entry), `sh/w.sh` (Unix entry)
- Pattern: Config parsing -> tokenization -> pattern matching -> template expansion -> execution

**wsh-real-ignore (Git Untrack Helper):**
- Purpose: Remove files from Git tracking while preserving local content
- Examples: `sh/wsh-real-ignore.sh`
- Pattern: `git rm --cached` + `.gitignore` append

## Entry Points

**Windows Git Bash Execution:**
- Location: `sh/exec-git-bash.bat`
- Triggers: Direct command or indirectly via `wsh.bat`, `wsha.bat`, `w.bat`
- Responsibilities: Resolve Git Bash path, set up environment, invoke command

**WSHA Alias Launcher:**
- Location: `sh/wsha.sh` (core), `sh/w.bat` (Windows), `sh/w.sh` (Unix symlink)
- Triggers: User invokes `w <alias>` or `wsha <alias>`
- Responsibilities: Load config, match alias, expand template, execute command

**wsh Git Bash Launcher:**
- Location: `sh/wsh.bat`
- Triggers: User invokes `wsh [command]`
- Responsibilities: Launch interactive Git Bash or execute single command

**wsh-ping TCP Checker:**
- Location: `sh/wsh-ping.bat`
- Triggers: User invokes `wsh-ping` or `wsh-ping <host> <port> [options]`
- Responsibilities: Read presets, invoke `bin/tcping.exe`

## Error Handling

**Strategy:** Exit codes with descriptive messages to stderr

**Patterns:**
- `git rm --cached --ignore-unmatch` - Silently handle untracked files
- `if [ $? -eq 0 ]` - Check command success before subsequent operations
- `2>/dev/null` - Suppress unwanted error output where appropriate
- Graceful degradation: `win-helper.exe` missing -> fallback to batch path resolution

## Cross-Cutting Concerns

**Logging:** Echo statements to stdout/stderr, no structured logging framework

**Validation:**
- Git repository check via `git rev-parse --show-toplevel`
- File existence checks before processing
- Windows carriage return removal (`tr -d '\r'`)

**Authentication:** Not applicable (no auth in this codebase)

---

*Architecture analysis: 2026-04-13*
