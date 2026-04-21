#!/usr/bin/env python3
"""Tests for wsha Python config system."""

import os
import sys
import tempfile
import time
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(__file__).rsplit('/', 1)[0])

from wsha import parse_line, parse_file, ConfigParseError, DuplicateAliasError
from wsha import CacheManager, load_config, AliasEntry


def test_parse_unquoted_alias():
    """Test parsing unquoted alias."""
    result = parse_line("fox firefox", "test.txt", 1)
    assert result == ("fox", "firefox"), f"Got {result}"


def test_parse_quoted_alias():
    """Test parsing quoted alias with spaces."""
    result = parse_line('"pcodex l" echo codex-last', "test.txt", 1)
    assert result == ("pcodex l", "echo codex-last"), f"Got {result}"


def test_parse_comment_line():
    """Test that comment lines are skipped."""
    result = parse_line("# this is a comment", "test.txt", 1)
    assert result is None


def test_parse_empty_line():
    """Test that empty lines are skipped."""
    result = parse_line("", "test.txt", 1)
    assert result is None
    result = parse_line("   ", "test.txt", 1)
    assert result is None


def test_parse_error_no_target():
    """Test error when alias has no target."""
    try:
        parse_line("lonely_alias", "test.txt", 1)
        assert False, "Should have raised ConfigParseError"
    except ConfigParseError as e:
        assert "has no target command" in str(e)
        assert e.line_no == 1


def test_parse_error_invalid_quoted():
    """Test error for invalid quoted syntax."""
    try:
        parse_line('"incomplete', "test.txt", 1)
        assert False, "Should have raised ConfigParseError"
    except ConfigParseError as e:
        assert "invalid quoted alias syntax" in str(e)


def test_parse_file_with_errors():
    """Test parsing file with errors shows line numbers."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("# valid\n")
        f.write("good_alias echo command\n")
        f.write("bad_alias\n")  # Error: no target
        f.write("another good one echo test\n")
        temp_path = f.name

    try:
        aliases, errors = parse_file(temp_path)
        assert len(aliases) == 2
        assert len(errors) == 1
        assert errors[0].line_no == 3
        assert errors[0].config_path == temp_path
    finally:
        os.unlink(temp_path)


def test_duplicate_alias_detection():
    """Test duplicate alias detection within single file via load_config."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("alias1 echo one\n")
        f.write("alias2 echo two\n")
        f.write("alias1 echo three\n")  # Duplicate
        temp_path = f.name

    try:
        # load_config with mode="single" enables fail_on_duplicate
        aliases, errors, sources = load_config(mode="single", config_path=temp_path, use_cache=False)
        # Should detect duplicate alias1
        assert len(errors) == 1
        assert isinstance(errors[0], DuplicateAliasError)
        assert errors[0].alias == "alias1"
    finally:
        os.unlink(temp_path)


def test_cache_clear():
    """Test cache clearing."""
    cache_mgr = CacheManager()
    cache_mgr.clear()

    # Create a temp cache
    cache_mgr.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    test_cache = cache_mgr.CACHE_DIR / "test.json"
    test_cache.write_text("{}")

    assert test_cache.exists()
    cache_mgr.clear()
    assert not test_cache.exists()


def test_cache_mtime_validation():
    """Test cache invalidation when config file changes."""
    cache_mgr = CacheManager()

    # Create temp config
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("test echo hello\n")
        temp_path = f.name

    try:
        # Load config with cache (mode="single" to use config_path)
        aliases1, errors1, _ = load_config(mode="single", config_path=temp_path, use_cache=True)

        # Modify file
        time.sleep(0.1)  # Ensure mtime differs
        with open(temp_path, 'a') as f:
            f.write("test2 echo world\n")

        # Load again - cache should be invalid
        aliases2, errors2, _ = load_config(mode="single", config_path=temp_path, use_cache=True)

        # Should have 2 aliases now (not cached)
        assert len(aliases2) == 2

    finally:
        os.unlink(temp_path)


def test_cache_corruption_recovery():
    """Test that corrupted cache is auto-deleted and recovers."""
    cache_mgr = CacheManager()

    # Create temp config
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("test echo hello\n")
        temp_path = f.name

    try:
        # Load once to create cache (mode="single")
        aliases1, errors1, _ = load_config(mode="single", config_path=temp_path, use_cache=True)

        # Corrupt the cache
        cache_file = cache_mgr.get_cache_file("single", [temp_path])
        cache_file.write_text("not valid json{{{")

        # Load again - should recover
        aliases2, errors2, _ = load_config(mode="single", config_path=temp_path, use_cache=True)

        # Should still work (cache was rebuilt)
        assert len(aliases2) == 1

    finally:
        os.unlink(temp_path)


def test_is_editable_install_detection():
    """Test is_editable_install() returns bool."""
    from wsha.config import is_editable_install
    result = is_editable_install()
    assert isinstance(result, bool), f"Expected bool, got {type(result)}"


def test_is_editable_install_pip_show():
    """Test is_editable_install() uses pip show output."""
    import subprocess as sp
    from wsha.config import is_editable_install
    result = is_editable_install()

    # 如果是 editable 安装，pip show 应该包含Editable project location
    if result:
        show_result = sp.run(["pip", "show", "wsha"], capture_output=True, text=True)
        assert "Editable project location:" in show_result.stdout


def main():
    """Run all tests."""
    tests = [
        test_parse_unquoted_alias,
        test_parse_quoted_alias,
        test_parse_comment_line,
        test_parse_empty_line,
        test_parse_error_no_target,
        test_parse_error_invalid_quoted,
        test_parse_file_with_errors,
        test_duplicate_alias_detection,
        test_cache_clear,
        test_cache_mtime_validation,
        test_cache_corruption_recovery,
        test_is_editable_install_detection,
        test_is_editable_install_pip_show,
    ]

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            print(f"PASS: {test.__name__}")
            passed += 1
        except Exception as e:
            print(f"FAIL: {test.__name__}: {e}")
            failed += 1

    print(f"\n{passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
