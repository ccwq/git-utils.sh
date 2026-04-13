"""Tests for cli.py helper functions: show_list_table, show_list_view, find_aliases."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'py'))

import pytest
from io import StringIO
from unittest.mock import patch
from wsha.config import AliasEntry


def make_entry(name, template, source_name='builtin', config_path='/cfg/wsh-alias.txt', line_no=1):
    return AliasEntry(name, template, config_path, source_name, line_no)


class TestFindAliases:
    """Tests for find_aliases() - fnmatch glob search."""

    def test_find_matching_glob(self):
        from wsha.cli import find_aliases
        e = make_entry('ab', 'pnpx agent-browser')
        results = find_aliases([e], 'a*')
        assert results == [e]

    def test_find_no_match(self):
        from wsha.cli import find_aliases
        e = make_entry('ab', 'pnpx agent-browser')
        results = find_aliases([e], 'xyz')
        assert results == []

    def test_find_exact_match(self):
        from wsha.cli import find_aliases
        e = make_entry('git-push', 'git push')
        results = find_aliases([e], 'git-push')
        assert results == [e]

    def test_find_multiple_matches(self):
        from wsha.cli import find_aliases
        entries = [make_entry('ab', 'cmd1'), make_entry('ac', 'cmd2'), make_entry('bd', 'cmd3')]
        results = find_aliases(entries, 'a*')
        assert len(results) == 2
        assert entries[0] in results
        assert entries[1] in results

    def test_find_empty_list(self):
        from wsha.cli import find_aliases
        results = find_aliases([], 'a*')
        assert results == []


class TestShowListTable:
    """Tests for show_list_table() - table format grouped by source."""

    def test_empty_aliases_shows_no_alias(self, capsys):
        from wsha.cli import show_list_table
        show_list_table([], {})
        out = capsys.readouterr().out
        assert '[wsha] no alias found.' in out

    def test_table_shows_source_header(self, capsys):
        from wsha.cli import show_list_table
        e = make_entry('ab', 'pnpx agent-browser', 'builtin', '/cfg/wsh-alias.txt', 1)
        show_list_table([e], {'builtin': '/cfg/wsh-alias.txt'})
        out = capsys.readouterr().out
        assert '[builtin]' in out

    def test_table_shows_alias_name(self, capsys):
        from wsha.cli import show_list_table
        e = make_entry('myalias', 'some command', 'builtin', '/cfg', 1)
        show_list_table([e], {'builtin': '/cfg'})
        out = capsys.readouterr().out
        assert 'myalias' in out

    def test_table_truncates_long_template(self, capsys):
        from wsha.cli import show_list_table
        long_template = 'x' * 70  # 超过 60 字符
        e = make_entry('ab', long_template, 'builtin', '/cfg', 1)
        show_list_table([e], {'builtin': '/cfg'})
        out = capsys.readouterr().out
        assert '...' in out
        # 确认没有输出完整 70 字符模板
        assert long_template not in out

    def test_table_no_truncate_for_short_template(self, capsys):
        from wsha.cli import show_list_table
        short_template = 'git push'
        e = make_entry('gp', short_template, 'builtin', '/cfg', 1)
        show_list_table([e], {'builtin': '/cfg'})
        out = capsys.readouterr().out
        assert short_template in out

    def test_table_groups_by_source(self, capsys):
        from wsha.cli import show_list_table
        e1 = make_entry('a1', 'cmd1', 'builtin', '/builtin.txt', 1)
        e2 = make_entry('u1', 'cmd2', 'user', '/user.txt', 1)
        sources = {'builtin': '/builtin.txt', 'user': '/user.txt'}
        show_list_table([e1, e2], sources)
        out = capsys.readouterr().out
        assert '[builtin]' in out
        assert '[user]' in out


class TestShowListView:
    """Tests for show_list_view() - detailed metadata view."""

    def test_empty_aliases_shows_no_alias(self, capsys):
        from wsha.cli import show_list_view
        show_list_view([], {})
        out = capsys.readouterr().out
        assert '[wsha] no alias found.' in out

    def test_view_shows_source_header(self, capsys):
        from wsha.cli import show_list_view
        e = make_entry('ab', 'pnpx agent-browser', 'builtin', '/cfg/wsh-alias.txt', 5)
        show_list_view([e], {'builtin': '/cfg/wsh-alias.txt'})
        out = capsys.readouterr().out
        assert '[builtin]' in out

    def test_view_shows_template(self, capsys):
        from wsha.cli import show_list_view
        e = make_entry('ab', 'pnpx agent-browser', 'builtin', '/cfg', 5)
        show_list_view([e], {'builtin': '/cfg'})
        out = capsys.readouterr().out
        assert 'Template:' in out
        assert 'pnpx agent-browser' in out

    def test_view_shows_source_name(self, capsys):
        from wsha.cli import show_list_view
        e = make_entry('ab', 'cmd', 'builtin', '/cfg', 5)
        show_list_view([e], {'builtin': '/cfg'})
        out = capsys.readouterr().out
        assert 'Source:' in out
        assert 'builtin' in out

    def test_view_shows_config_with_lineno(self, capsys):
        from wsha.cli import show_list_view
        e = make_entry('ab', 'cmd', 'builtin', '/cfg/wsh-alias.txt', 42)
        show_list_view([e], {'builtin': '/cfg/wsh-alias.txt'})
        out = capsys.readouterr().out
        assert 'Config:' in out
        assert ':42' in out
