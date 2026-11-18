"""Tests for the implicit word-boundary rule of match_double_star_remainder.

Background:
    The ** wildcard used to swallow the tail of the first token, so the alias
    "s**" matched "sls -l" and "skills" (capturing "kills"). The engine now
    requires a literal head in front of ** to match a complete token.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'py'))

from wsha.matching import match_double_star_remainder


class TestDoubleStarWordBoundary:
    """Word-boundary behaviour of the ** remainder capture."""

    def test_literal_head_requires_complete_token(self):
        # Given：模式 "s**" 在 ** 前有字面量头 "s"。
        # When：输入文本 "sls -l" 的首个 token 以 s 开头，但不是完整匹配。
        # Then：匹配失败并返回空捕获，避免字面量头吃掉 token 内部前缀。
        ok, caps, rest = match_double_star_remainder('s**', 'sls -l')
        assert ok is False
        assert caps == []
        assert rest == ''

    def test_literal_head_rejects_partial_first_token(self):
        # Given：模式 "s**" 在 ** 前有字面量头 "s"。
        # When：输入文本 "skills" 的首 token 只是以 s 开头。
        # Then：匹配失败，skills 不会被当成 s + kills。
        ok, caps, rest = match_double_star_remainder('s**', 'skills')
        assert ok is False
        assert caps == []
        assert rest == ''

    def test_literal_head_matches_complete_token(self):
        # Given：模式 "s**" 在 ** 前有字面量头 "s"。
        # When：输入文本 "s ls -l" 的首 token 恰好是 s。
        # Then：匹配成功，剩余内容被 ** 捕获。
        ok, caps, rest = match_double_star_remainder('s**', 's ls -l')
        assert ok is True
        assert caps == []
        assert rest == 'ls -l'

    def test_literal_head_capture_is_stripped(self):
        # Given：模式 "s**" 在 ** 前有字面量头 "s"。
        # When：输入文本 "s ls -l" 的首 token 恰好是 s。
        # Then：捕获内容去掉分隔空白，模板展开不会出现双空格。
        ok, caps, rest = match_double_star_remainder('s**', 's ls -l')
        assert ok is True
        assert not rest.startswith(' ')
        assert rest == 'ls -l'

    def test_empty_capture_at_end_of_input_is_accepted(self):
        # Given：模式 "s**" 在 ** 前有字面量头 "s"。
        # When：输入文本只有 "s"，** 捕获为空串（串尾即词边界）。
        # Then：正则层面匹配成功且 rest 为空，由调用方按空捕获规则拒绝并告警。
        ok, caps, rest = match_double_star_remainder('s**', 's')
        assert ok is True
        assert caps == []
        assert rest == ''

    def test_empty_head_is_unaffected(self):
        # Given：模式 "**" 位于模式开头，** 前没有字面量头。
        # When：输入文本 "ls -l"。
        # Then：行为不变，匹配成功并捕获全部剩余内容。
        ok, caps, rest = match_double_star_remainder('**', 'ls -l')
        assert ok is True
        assert caps == []
        assert rest == 'ls -l'

    def test_empty_head_with_suffix_is_unaffected(self):
        # Given：模式 "** foo" 位于模式开头，** 前没有字面量头。
        # When：输入文本 "ls foo"。
        # Then：行为不变，匹配成功并捕获 ** 之前的剩余内容。
        ok, caps, rest = match_double_star_remainder('** foo', 'ls foo')
        assert ok is True
        assert rest == 'ls'

    def test_prefix_suffix_pattern_word_boundary(self):
        # Given：模式 "prefix**suffix" 在 ** 前有字面量头 "prefix"。
        # When：输入文本 "prefixxsuffix" 中 prefix 只匹配了 token 的前半段。
        # Then：匹配失败，prefix 必须匹配完整 token。
        ok, caps, rest = match_double_star_remainder('prefix**suffix', 'prefixxsuffix')
        assert ok is False
        assert caps == []
        assert rest == ''

    def test_prefix_suffix_pattern_with_space_matches(self):
        # Given：模式 "prefix**suffix" 在 ** 前有字面量头 "prefix"。
        # When：输入文本 "prefix x suffix" 中 prefix 匹配了完整 token。
        # Then：匹配成功，** 捕获空白之后的剩余内容。
        ok, caps, rest = match_double_star_remainder('prefix**suffix', 'prefix x suffix')
        assert ok is True
        assert rest.strip() == 'x'
