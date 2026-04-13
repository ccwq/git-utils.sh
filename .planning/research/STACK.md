# Stack Research

**Domain:** Python CLI Tool (wsha reimplementation)
**Researched:** 2026-04-13
**Confidence:** MEDIUM (verified via GitHub/official sources, web search unavailable)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Click** | 8.3.2 (2026-04) | CLI framework | Composable, decorator-based, sensible defaults. Industry standard for Python CLI tools (17.4k stars). Supports subcommands, auto-help, lazy loading. |
| **uv** | 0.11.6 (2026-04) | Package manager | 10-100x faster than pip. Supports `uvx wsha` (run without install), global install via `uv tool install`, and standard pip installation. Replaces pip/pipx/poetry. |
| **pyproject.toml** | Standard | Project config | Modern Python project standard. Defines `[project.scripts]` entry point for CLI installation. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **fnmatch** | stdlib | Wildcard matching | `*`, `**`, `?` pattern matching for alias expansion (wsha core feature) |
| **re** | stdlib | Regex scoring | Token scoring algorithm for alias ranking |
| **pathlib** | stdlib | Path handling | Cross-platform config and cache path resolution |
| **shutil** | stdlib | File operations | Cache management, file copying |
| **stat** | stdlib | File timestamps | Cache validation via mtime comparison |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **uv** | Dev environment & packaging | `uv sync` for dependencies, `uv run` for testing |
| **pytest** | Unit testing | Verify Python impl matches shell behavior via existing test suite |
| **pytest-xdist** | Parallel test execution | Speed up test runs |

## Installation

```bash
# Core dependencies
uv add click

# Dev dependencies
uv add --dev pytest pytest-xdist

# Install wsha globally (replaces pipx)
uv tool install .

# Or install for development
uv sync

# Run without installing
uvx wsha w <alias>

# Or in development mode
uv run wsha w <alias>
```

### pyproject.toml Entry Point

```toml
[project]
name = "wsha"
version = "1.0.0"
description = "Wildcard alias expansion CLI tool"
requires-python = ">=3.10"

[project.scripts]
wsha = "wsha.cli:main"
w = "wsha.cli:main"  # Short alias
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| Click | **Typer** | When team prefers type hints and less boilerplate. Typer 0.24.1 builds on Click. Use Typer if Python-first DX is priority over fine-grained control. |
| Click | **argparse** | When zero external dependencies required. argparse is stdlib but verbose (requires 3x more code than Click for subcommands). |
| uv | **pip** | Legacy compatibility only. pip is 10-100x slower and lacks virtualenv management. |
| uv | **pipx** | uv replaces pipx with `uv tool install`. Use pipx only if uv unavailable. |
| uv | **poetry** | Poetry is slower (pure Python). uv handles both package management AND tool installation. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **argparse for complex CLIs** | Verbose boilerplate for subcommands. Requires manual help formatting, argument grouping. | Click |
| **optparse** | Deprecated, replaced by argparse in Python 3.2. | argparse or Click |
| ** Cement** | Unmaintained (last release 2019). Not compatible with Python 3.10+. | Click |
| **docopt** | Abandoned project. Outdated pattern-based approach. | Click or Typer |
| **poetry + pipx combo** | Two tools when uv handles both. Poetry slow, pipx adds overhead. | uv alone |

## Stack Patterns by Variant

**If Windows Git Bash is primary platform:**
- Use `pathlib` for all path operations (handles Git Bash path quirks)
- Test with Windows line endings (`\r\n`) - use `text=True` everywhere
- Entry point batch wrapper handled by uv tool installation

**If supporting Python 3.8-3.9:**
- Use `typing.get_args()` instead of `|` union syntax (3.10+)
- Avoid `from __future__ import annotations` where possible for perf

**If matching existing wsha.sh behavior exactly:**
- Shell returns strings, Python returns typed objects - need conversion layer
- `eval` equivalent in Python: `subprocess.run()` with `shell=True` or token array execution

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Click 8.3.2 | Python 3.7+ | Active development, stable API |
| uv 0.11.6 | Python 3.8+ | Requires Python 3.8+ for full features |
| wsha (this project) | Python 3.10+ | Project constraint per existing docs |

## Project Structure Recommendation

```
wsha-python/
├── pyproject.toml          # Project config + entry points
├── uv.lock                 # Lockfile (commit to repo)
├── src/
│   └── wsha/
│       ├── __init__.py
│       ├── cli.py          # Click CLI setup, main entry
│       ├── config.py       # Config loading & caching
│       ├── match.py        # Wildcard matching & scoring
│       ├── expand.py       # Template variable expansion
│       └── execute.py      # Command execution
├── tests/
│   └── test_wsha.py        # pytest tests
└── .venv/                  # Virtual env (not committed)
```

**Alternative (single module for simplicity):**

```
wsha/
├── pyproject.toml
├── wsha.py                 # Single-file CLI (250-400 lines)
└── tests/
    └── test_wsha.py
```

**Recommendation:** Use single-module `wsha.py` initially. The existing wsha.sh is 1064 lines with parallel arrays - Python should achieve same functionality in 250-400 lines due to native dict/list support. Move to `src/` layout only if complexity grows beyond 800 lines.

## Sources

- [Click GitHub](https://github.com/pallets/click) — Version 8.3.2 confirmed (2026-04-03)
- [Typer GitHub](https://github.com/tiangolo/typer) — Version 0.24.1 confirmed (2026-02-21)
- [uv GitHub](https://github.com/astral-sh/uv) — Version 0.11.6 confirmed (2026-04-09)
- [uv Project Layout Docs](https://docs.astral.sh/uv/concepts/projects/layout/) — pyproject.toml structure
- [argparse stdlib](https://docs.python.org/3/library/argparse.html) — When to use vs third-party

---
*Stack research for: wsha Python CLI tool*
*Researched: 2026-04-13*
