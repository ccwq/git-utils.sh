# External Integrations

**Analysis Date:** 2026-04-13

## Shell Environments

**Git Bash (Windows):**
- Used as primary shell on Windows
- Launched via `bin/win-helper/win-helper.exe` or `sh/exec-git-bash.bat`
- Path resolution priority: env var `GIT_BASH` > registry cache > `where git` > default install

## Command Aliases (External Tools)

The project uses alias configuration (`config/wsh-alias.txt`) to invoke external tools:

**AI/Agent Tools:**
- `agent-browser` - Browser automation (npm package)
- `@openai/codex` - Codex CLI
- `@google/gemini-cli` - Gemini CLI
- `@anthropic-ai/claude-code` - Claude Code
- `opencode-ai` - OpenCode AI
- `browser-use` - Browser use tool (via `uvx`)
- `gsd-pi` - GSD tool

**Development Tools:**
- `lazygit` - Terminal UI for Git
- `docker` / `podman` - Container tools
- `code` - VS Code editor

**Node.js Package Execution:**
- Uses `pnpx` to execute packages without permanent installation
- Examples: `pnpx agent-browser`, `pnpx @openai/codex`

## File Storage

**Local Configurations:**
- `config/wsh-alias.txt` - User alias definitions
- `config/wsh-ping.txt` - TCP ping presets
- User config: `$HOME/.config/wsh-alias.txt` (Linux) / `%USERPROFILE%\.config\wsh-alias.txt` (Windows)
- Project config: `$PWD/.config/wsh-alias.txt` (Linux) / `%CD%\.config\wsh-alias.txt` (Windows)

## Terminal Enhancement

**Clink (Windows):**
- Lua scripts in `clink-lua-scripts/` provide auto-completion
-覆盖: `w`/`wsha`, `wsh`, `wsh-ping`, `wsh-fpatch`, `wsh-real-ignore`, `wsh-replace-cn-punc`
- Usage: `dofile("path/to/git-utils.lua")` or set `CLINK_PATH` environment variable

## Windows-Specific Integrations

**win-helper (Rust binary):**
- Located at `bin/win-helper/win-helper.exe`
- Parses Git Bash path and launches bash processes
- No external Rust crate dependencies
- Uses Windows native API for process creation

**tcping.exe:**
- TCP connectivity testing tool
- Located at `bin/tcping.exe`
- Wrapped by `sh/wsh-ping.bat`

## Environment Variables Used

**Built-in:**
- `APP_HOME` - Project root absolute path
- `APP_SH` - sh directory absolute path
- `APP_CONFIG` - config directory absolute path

**External:**
- `GIT_BASH` - Override Git Bash path discovery
- `WSHA_CONFIG_FILE` - Custom alias config file path
- `CLINK_PATH` - Clink scripts directory
- `CDPORT` - CDP port for browser automation

## CI/CD & Testing

**Test Infrastructure:**
- `__test__/` - Shell-based test scripts
- `test-all.sh` - Test runner
- Generates Markdown reports in `__test__/report/`

**No external CI service detected** - Tests run locally via `npm test` or `./test-all.sh`

## Dependencies

**Direct npm packages referenced via aliases:**
- `agent-browser`
- `@openai/codex`
- `@google/gemini-cli`
- `@anthropic-ai/claude-code`
- `opencode-ai`
- `gsd-pi`
- `browser-use`

---

*Integration audit: 2026-04-13*
