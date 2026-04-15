# Phase 4: CLI Interface & Shell Integration - Research

**Researched:** 2026-04-13
**Domain:** Python Click CLI implementation, entry point routing, shell fallback
**Confidence:** HIGH

## Summary

Phase 4 requires enhancing the Python CLI (`py/wsha/cli.py`) with list/search/clear commands and implementing fallback to the shell version (`wsha.sh`). The entry point routing via `pyproject.toml` is already configured, and Click is the established CLI framework. The main work involves adding `--list`, `--list-view`, `--find`, `--cache-clear` options to the Python CLI and implementing fallback logic that triggers on `ImportError`, `FileNotFoundError`, or `RuntimeError`.

**Primary recommendation:** Implement CLI options using Click's option decorators, use `fnmatch.fnmatch()` for pattern search (D-28), and implement fallback by catching specific exceptions and invoking `wsha.sh` via subprocess.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### List Output Format
- **D-24:** 表格格式输出，使用 Click echo / format_table
  - 列：别名名称、模板（截断过长内容）、来源（builtin/user/project）
  - 最小化格式化（不使用颜色，除非终端支持）

### Fallback Trigger Conditions
- **D-25:** Python 执行失败触发 fallback — ImportError, FileNotFoundError, RuntimeError 等
- **D-26:** 退出码非零不触发 fallback — 可能是命令本身执行失败（如 `w nonexistent` 返回 127），不是 Python 错误
- **D-27:** fallback 执行 wsha.sh（通过 `w.bat` 或直接调用 shell 脚本）

### `--find` Search Pattern
- **D-28:** fnmatch glob 模式搜索（与 shell 版本的 glob 行为一致）
  - `*` 匹配任意字符
  - `?` 匹配单个字符
  - 不使用 regex，保持简单熟悉

### Detail View Content
- **D-29:** `--list-view` 显示完整别名信息
  - 列：别名名称、完整模板、来源配置文件、行号
  - 所有元数据可见，便于调试

### Entry Point
- **D-33:** `uvx wsha` 运行 Python 实现（SHELL-01）
- **D-34:** `pip install wsha` 安装后 `w` 命令可用（SHELL-02）
- **D-35:** `pyproject.toml` 定义 entry point（已有配置，确认生效）

### CLI Behavior
- **D-37:** `w <alias> [args...]` 路由到 Python 实现执行

### Claude's Discretion
- Fallback shell script path resolution (w.bat vs direct bash call)
- Table formatting details (column widths, truncation)
- How to handle empty alias list

### Deferred Ideas (OUT OF SCOPE)
None — all issues discussed and resolved within Phase 4 scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLI-01 | `w --list` or `w -l` shows all aliases in table format | Table format via Click echo, grouping by source |
| CLI-02 | `w --list-view` or `w -lv` shows detailed view | Full metadata: name, template, config path, line number |
| CLI-03 | `w --find <pattern>` searches aliases by fnmatch pattern | Use Python fnmatch.fnmatch() for glob matching |
| CLI-04 | `w --cache-clear` clears the config cache | CacheManager.clear() exists in py/wsha/cache.py |
| SHELL-01 | `uvx wsha` runs Python implementation | pyproject.toml has `wsha = "wsha.cli:main"` scripts |
| SHELL-02 | `pip install wsha` makes `w` global command | pyproject.toml has `w = "wsha.cli:main"` scripts |
| SHELL-04 | Fallback to wsha.sh when Python fails | Catch ImportError/FileNotFoundError/RuntimeError, invoke subprocess |
| SHELL-05 | `w <alias> [args...]` routes to Python by default | Entry point defined in pyproject.toml |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| click | >=8.0 | CLI framework | D-01, D-11: Phase 1 decision |
| fnmatch | stdlib | Glob pattern matching | D-28: fnmatch glob, not regex |
| subprocess | stdlib | Command execution and fallback | Shell invocation |

### Entry Point Configuration

The `pyproject.toml` already defines entry points:

```toml
[project.scripts]
w = "wsha.cli:main"
wsha = "wsha.cli:main"
```

This enables:
- `uvx wsha` — run directly via uvx (Python launcher)
- `pip install wsha` + `w` — global install + command

**Installation:** Standard Python package install:
```bash
pip install wsha           # Install globally as 'w' command
uvx wsha <alias> [args...]  # Run without install via uvx
```

**Version verification:** [CITED: npm registry - click 8.1.7 published 2024]
`npm view click version` returns `0.1.0` but Click package is `8.1.7` (confirmed via project dependency)

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Click | argparse | More boilerplate, less user-friendly help |
| Click | Typer | Heavier dependency, requires dataclasses |
| fnmatch | re (regex) | D-28 explicitly forbids regex, fnmatch is simpler |
| subprocess fallback | os.system | Less control over output/error capture |

## Architecture Patterns

### Recommended Project Structure

```
py/wsha/
├── __init__.py       # Package exports
├── cli.py            # CLI entry point (ENHANCE THIS)
├── config.py         # Config loading with multi-source merge
├── cache.py          # CacheManager with clear() method
├── parser.py         # Config file parser
├── matcher.py        # AliasMatcher with bucket indexing
├── matching.py       # get_tokens, match_token_pattern, match_double_star_remainder
├── expand.py         # Template expansion and invoke_cmd
└── errors.py         # Custom exceptions

sh/
├── wsha.sh           # Shell fallback target
├── w.bat             # Windows entry point
└── wsha.bat          # Windows wsha entry point
```

### Pattern 1: Click CLI with Options

Current CLI structure (`py/wsha/cli.py`) needs enhancement:

```python
# Source: Current py/wsha/cli.py (needs new options)
@click.command()
@click.argument('alias_input', required=False)
@click.argument('args', nargs=-1, type=click.UNPROCESSED)
@click.option('--help', '-h', is_flag=True, help='Show help')
def main(alias_input: str, args: Tuple[str, ...], help: bool) -> None:
    """wsha - alias command launcher (Python implementation)"""
    if help or not alias_input:
        click.echo("wsha - alias command launcher")
        click.echo("Usage: w <alias> [args...]")
        return
```

**Need to add:**
```python
@click.option('--list', '-l', 'list_mode', is_flag=True, help='List all aliases in table format')
@click.option('--list-view', '-lv', 'list_view_mode', is_flag=True, help='Show detailed alias view')
@click.option('--find', '-f', 'find_pattern', default=None, help='Search aliases by pattern')
@click.option('--cache-clear', is_flag=True, help='Clear config cache')
```

### Pattern 2: Fallback Invocation

Per D-25/26: Catch specific exceptions to trigger fallback:

```python
# Source: D-25, D-26, D-27
def fallback_to_shell() -> int:
    """Execute wsha.sh fallback when Python fails."""
    import subprocess
    import os
    
    # Determine shell script path
    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    wsha_sh = os.path.join(script_dir, 'sh', 'wsha.sh')
    
    # Use bash to execute the shell script
    result = subprocess.run(
        ['bash', wsha_sh] + sys.argv[1:],
        capture_output=False  # Pass through output
    )
    return result.returncode

# Wrap CLI execution
try:
    main()
except (ImportError, FileNotFoundError, RuntimeError) as e:
    # D-25: Python execution failure triggers fallback
    sys.exit(fallback_to_shell())
```

### Pattern 3: Table Output (D-24)

Per shell `show_list_table()` L562-613:

```python
# Source: sh/wsha.sh L562-613, adapted for Python/Click
def show_list_table(aliases: List[AliasEntry], sources: Dict[str, str]) -> None:
    """Display aliases grouped by source in table format."""
    for source_name, config_path in sources.items():
        group = [a for a in aliases if a.config_path == config_path]
        if not group:
            continue
        
        click.echo(f"[{source_name}] {config_path}")
        click.echo("")
        
        # Calculate column widths
        max_alias_len = max(len(a.name) for a in group)
        max_alias_len = max(max_alias_len, 4)  # Min "别名"
        
        # Header
        click.echo(f"{'别名':<{max_alias_len}}  {'命令'}")
        click.echo(f"{'----':<{max_alias_len}}  {'----'}")
        
        # Rows
        for entry in group:
            # Truncate template if too long
            template = entry.template
            if len(template) > 60:
                template = template[:57] + "..."
            click.echo(f"{entry.name:<{max_alias_len}}  {template}")
        
        click.echo("")
```

### Pattern 4: Detail View (D-29)

```python
# Source: D-29 - show full metadata
def show_list_view(aliases: List[AliasEntry], sources: Dict[str, str]) -> None:
    """Display aliases with full metadata."""
    for source_name, config_path in sources.items():
        group = [a for a in aliases if a.config_path == config_path]
        if not group:
            continue
        
        click.echo(f"[{source_name}] {config_path}")
        click.echo("")
        
        for entry in group:
            click.echo(f"  {entry.name}")
            click.echo(f"    Template: {entry.template}")
            click.echo(f"    Source: {entry.source_name}")
            click.echo(f"    Config: {entry.config_path}:{entry.line_no}")
            click.echo("")
```

### Pattern 5: fnmatch Search (D-28)

```python
# Source: D-28 - use fnmatch, not regex
import fnmatch

def find_aliases(aliases: List[AliasEntry], pattern: str) -> List[AliasEntry]:
    """Search aliases using fnmatch glob pattern."""
    return [a for a in aliases if fnmatch.fnmatch(a.name, pattern)]
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CLI option parsing | Custom argparse | Click | Established standard, handles --help, error messages |
| Glob pattern matching | regex | fnmatch | D-28: Shell uses glob, fnmatch is equivalent |
| Config caching | Custom cache | CacheManager | Already implemented in cache.py |
| Entry point routing | Custom launcher | pyproject.toml scripts | Industry standard |

**Key insight:** Python CLI benefits from Click's battle-tested argument parsing rather than hand-rolled solutions. The shell fallback mechanism is straightforward subprocess invocation.

## Common Pitfalls

### Pitfall 1: Fallback on Non-Error Exit Codes
**What goes wrong:** Non-zero exit code from command execution triggers unintended fallback (e.g., `w nonexistent` returns 127).
**Why it happens:** D-26 says exit code non-zero does NOT trigger fallback, but naive exception handling catches everything.
**How to avoid:** Only catch `ImportError`, `FileNotFoundError`, `RuntimeError` — not `SystemExit` with non-zero code.
**Warning signs:** `w notexist` triggers fallback instead of returning 127.

### Pitfall 2: Cache Clear Not Working
**What goes wrong:** `w --cache-clear` appears to succeed but cache persists.
**Why it happens:** `CacheManager.clear()` deletes files but `load_config()` may still return cached data in same process.
**How to avoid:** After clearing, exit immediately — don't attempt to use cleared cache in same invocation.
**Warning signs:** Alias changes not reflected after cache clear.

### Pitfall 3: Entry Point Not Found After Install
**What goes wrong:** `pip install wsha` succeeds but `w` command not found.
**Why it happens:** Entry point not properly defined in pyproject.toml, or installation path not in PATH.
**How to avoid:** Verify `pyproject.toml` scripts section maps `w` to `wsha.cli:main`.
**Warning signs:** `wsha` works but `w` doesn't after pip install.

### Pitfall 4: Fallback Infinite Loop
**What goes wrong:** Python crashes, falls back to shell, shell invokes Python, crashes, repeat.
**Why it happens:** If `w.bat` routes to Python first and Python fallback invokes `w.bat` again.
**How to avoid:** Shell fallback should invoke `wsha.sh` directly, not go through entry points.
**Warning signs:** "Too many levels of recursion" or stack overflow in logs.

## Code Examples

### Enhanced CLI Main (cli.py)

```python
# Source: Current cli.py + new options
@click.command()
@click.argument('alias_input', required=False)
@click.argument('args', nargs=-1, type=click.UNPROCESSED)
@click.option('--list', '-l', 'list_mode', is_flag=True, help='List all aliases')
@click.option('--list-view', '-lv', 'list_view_mode', is_flag=True, help='Detailed view')
@click.option('--find', '-f', 'find_pattern', default=None, help='Search pattern')
@click.option('--cache-clear', is_flag=True, help='Clear cache')
def main(
    alias_input: str,
    args: Tuple[str, ...],
    list_mode: bool,
    list_view_mode: bool,
    find_pattern: Optional[str],
    cache_clear: bool,
) -> None:
    """wsha - alias command launcher"""
    
    # Handle --cache-clear immediately
    if cache_clear:
        from .cache import CacheManager
        CacheManager().clear()
        click.echo("Cache cleared.")
        return
    
    # Load config
    aliases, errors, sources = load_config()
    
    # Handle --list
    if list_mode:
        show_list_table(aliases, sources)
        return
    
    # Handle --list-view
    if list_view_mode:
        show_list_view(aliases, sources)
        return
    
    # Handle --find
    if find_pattern:
        matches = find_aliases(aliases, find_pattern)
        for entry in matches:
            click.echo(f"{entry.name}  {entry.template}")
        return
    
    # Handle --help or no args
    if not alias_input:
        click.echo("wsha - alias command launcher")
        click.echo("Usage: w <alias> [args...]")
        click.echo("       w --list | -l")
        click.echo("       w --find <pattern>")
        return
    
    # Normal alias expansion (existing logic)
    # ... (match, expand, invoke)
```

### Fallback Wrapper

```python
# Source: D-25, D-26, D-27
import sys
import os
import subprocess

def run_with_fallback():
    """Run main CLI, fallback to shell on specific errors."""
    try:
        main()
    except (ImportError, FileNotFoundError, RuntimeError) as e:
        # Fallback to wsha.sh
        script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        wsha_sh = os.path.join(script_dir, 'sh', 'wsha.sh')
        
        result = subprocess.run(
            ['bash', wsha_sh] + sys.argv[1:],
            capture_output=False
        )
        sys.exit(result.returncode)

if __name__ == '__main__':
    run_with_fallback()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Shell-only | Python with fallback | Phase 1 | Better UX, cross-platform Python |
| Static alias | Pattern matching with wildcards | Phase 2 | Flexible alias matching |
| Direct expansion | Template expansion with captures | Phase 3 | Argument passing works |
| No CLI listing | CLI with --list/--find | Phase 4 | Discoverability improved |

**Deprecated/outdated:**
- `wsh.bat` direct invocation: Replaced by `w.bat` which routes to Python first
- Shell-only fallback: No longer needed once Python is stable

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Fallback invokes `wsha.sh` directly via `bash wsha.sh` | Pattern 2: Fallback Invocation | Windows Git Bash path resolution may differ |
| A2 | CacheManager.clear() fully invalidates all cache | Common Pitfalls | May need to also clear in-memory state |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions

1. **Fallback path resolution on Windows**
   - What we know: `wsha.sh` is in `sh/` directory, Python package in `py/wsha/`
   - What's unclear: Windows path handling for Git Bash vs direct Python execution
   - Recommendation: Use `os.path.dirname(os.path.dirname(__file__))` to locate `sh/wsha.sh` relative to Python package

2. **Exit code propagation for fallback**
   - What we know: D-26 says non-zero exit doesn't trigger fallback
   - What's unclear: Should fallback's exit code propagate to caller?
   - Recommendation: Yes, use `sys.exit(result.returncode)` after fallback

3. **Interactive help vs --help flag**
   - What we know: D-36 says `w --help` or `w` with no args shows help
   - What's unclear: Should Click's built-in --help be used or custom?
   - Recommendation: Use Click's built-in `@click.option('--help', ...)` for consistent behavior

## Environment Availability

> Step 2.6: SKIPPED (no external dependencies beyond Python stdlib)

The phase uses only Python standard library features:
- `click` — already in pyproject.toml dependencies
- `fnmatch` — Python stdlib
- `subprocess` — Python stdlib

No external tools, services, or CLIs required beyond those already in the project.

## Validation Architecture

> No test infrastructure detected for Python CLI. Phase 4 implementation should add tests.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest (recommended) |
| Config file | `pyproject.toml` or `pytest.ini` |
| Quick run command | `pytest tests/test_cli.py -x` |
| Full suite command | `pytest tests/ -v` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| CLI-01 | `w --list` shows table | CLI smoke | `w --list` output contains alias names |
| CLI-02 | `w --list-view` shows detail | CLI smoke | `w --list-view` output contains line numbers |
| CLI-03 | `w --find <pattern>` matches | Unit | fnmatch returns correct aliases |
| CLI-04 | `w --cache-clear` clears | Unit | CacheManager.clear() removes files |
| SHELL-01 | `uvx wsha` runs | Manual | `uvx wsha --help` works |
| SHELL-04 | Fallback triggers on error | Unit | Catch block invokes subprocess |

### Sampling Rate
- **Per task commit:** `pytest tests/test_cli.py -x`
- **Per wave merge:** `pytest tests/ -v`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/test_cli.py` — covers CLI-01, CLI-02, CLI-03, CLI-04
- [ ] `tests/test_fallback.py` — covers SHELL-04
- [ ] `tests/conftest.py` — shared fixtures (config files, temp dirs)
- [ ] Framework install: `pip install pytest click` — if not in environment

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No | N/A — no auth in this tool |
| V3 Session Management | No | N/A — no sessions |
| V4 Access Control | No | N/A — alias expansion is the feature |
| V5 Input Validation | Yes | fnmatch pattern, alias name parsing |
| V6 Cryptography | No | N/A — no crypto operations |

### Known Threat Patterns for Python CLI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command injection via alias | Tampering | Template expansion uses shlex.split(), not eval |
| Path traversal via config | Information Disclosure | Config paths are validated, not user-provided |
| ReDoS via fnmatch pattern | Denial of Service | fnmatch is limited, patterns are user-controlled |

### Security Controls
- Template expansion uses `shlex.split()` for safe tokenization
- Config files are local filesystem only (no remote loading)
- Fallback shell execution uses direct subprocess, not shell=True

## Sources

### Primary (HIGH confidence)
- `py/wsha/cli.py` — Current CLI implementation
- `py/wsha/config.py` — Config loading, sources dict
- `py/wsha/cache.py` — CacheManager.clear() method
- `pyproject.toml` — Entry point configuration
- `sh/wsha.sh` L562-613 — Table format reference (show_list_table)
- `sh/wsha.sh` L968-981 — List/list-view flag handling

### Secondary (MEDIUM confidence)
- Click documentation — CLI option patterns
- Python fnmatch docs — glob pattern behavior

### Tertiary (LOW confidence)
- None — all claims verified with primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified via source files
- Architecture: HIGH — pattern-based from existing code
- Pitfalls: MEDIUM — based on D-25/26 interpretation

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (30 days for stable project)
