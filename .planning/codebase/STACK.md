# Technology Stack

**Analysis Date:** 2026-04-13

## Languages

**Primary:**
- Shell (Bash) - Core scripts for Linux/macOS/Windows Git Bash
- Batch (.bat) - Windows-specific entry points and wrappers

**Secondary:**
- Rust 2021 - Windows Git Bash runtime (`bin/win-helper/`)
- Lua - Clink auto-completion scripts (`clink-lua-scripts/`)

## Runtime

**Environment:**
- Git Bash (Windows) - Primary shell environment for Windows users
- Standard Bash (Linux/macOS)

**Package Manager:**
- pnpm 10.21.0 - Node.js package management
- Lockfile: Not committed to repository

## Frameworks

**Core:**
- Shell scripting (bash) - Primary implementation language
- Batch scripting - Windows-specific entry points

**Build/Dev:**
- Cargo (Rust) - Build system for `win-helper`
- npm/pnpm - Task running and script orchestration

## Key Dependencies

**Critical:**
- Git - Required dependency (must be installed)
- Git Bash - Recommended for Windows

**Infrastructure:**
- `bin/tcping.exe` - TCP connectivity testing tool (Windows)
- `bin/win-helper/win-helper.exe` - Rust binary for Windows Git Bash path resolution

## Project Structure

**Entry Points:**
- `sh/exec-git-bash.bat` - Windows Git Bash launcher
- `sh/w.bat` / `sh/wsha.bat` - Windows alias wrapper entry points
- `sh/w.sh` / `sh/wsha.sh` - Linux/macOS alias wrapper entry points

**Configuration:**
- `config/wsh-alias.txt` - Alias definitions
- `config/wsh-ping.txt` - TCP ping preset targets

**Scripts Location:**
- `sh/` - Main shell/batch script directory
- `scripts/init.bat` - Initialization script

**Testing:**
- `__test__/` - Test scripts directory
- `test-all.sh` - Test runner script

## Platform Requirements

**Development:**
- Git installed
- Bash shell (Linux/macOS) or Git Bash (Windows)

**Production:**
- Cross-platform: Windows, Linux, macOS
- Windows-specific: Git Bash, optional Clink for auto-completion

---

*Stack analysis: 2026-04-13*
