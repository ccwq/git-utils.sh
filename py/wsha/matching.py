"""Tokenization and wildcard matching engine for wsha.

This module provides the core pattern matching primitives that power alias expansion:
- get_tokens(): Split text into tokens by whitespace, no glob expansion
- match_token_pattern(): Match a glob pattern against a single token
- match_double_star_remainder(): Match ** patterns and extract remainder

These functions mirror the shell implementation in sh/wsha.sh L625-775.
"""

from __future__ import annotations

import re
from typing import List, Tuple


def get_tokens(text: str) -> List[str]:
    """Split text into tokens by whitespace, no glob expansion.

    Mimics the shell get_tokens() function (sh/wsha.sh L625-640).
    Unlike shlex.split(), this does not handle quotes or escape sequences -
    it simply splits on whitespace boundaries.

    Args:
        text: Input string to tokenize

    Returns:
        List of non-empty tokens

    Example:
        >>> get_tokens('px* foo bar')
        ['px*', 'foo', 'bar']
        >>> get_tokens('  multiple   spaces   ')
        ['multiple', 'spaces']
        >>> get_tokens('')
        []
    """
    if not text:
        return []
    # Python str.split() naturally handles whitespace splitting without
    # any glob expansion (unlike shell word splitting with glob enabled)
    tokens = text.split()
    return tokens


def match_token_pattern(pattern: str, token: str) -> Tuple[bool, List[str], int]:
    """Match a glob pattern against a single token with wildcard support.

    Mirrors the shell match_token_pattern() function (sh/wsha.sh L648-708).

    Behavior:
    - No wildcards: case-insensitive string comparison
    - Has wildcards (*): translate glob to regex, handle greedy matching

    Args:
        pattern: Glob pattern (e.g., "px*", "foo*bar")
        token: Token to match against pattern

    Returns:
        Tuple of (match_ok, captures, wildcard_count):
        - match_ok: True if pattern matches token
        - captures: List of strings captured by * in pattern
        - wildcard_count: Number of wildcards used

    Example:
        >>> ok, caps, wc = match_token_pattern('px*', 'pxhttp-server')
        >>> ok
        True
        >>> 'http-server' in caps[0]
        True
    """
    captures: List[str] = []
    wildcard_count = 0

    # No wildcards: case-insensitive literal comparison
    if '*' not in pattern:
        pattern_lower = pattern.lower()
        token_lower = token.lower()
        if pattern_lower == token_lower:
            return (True, [], 0)
        return (False, [], 0)

    # Has wildcards: build regex from glob pattern
    # Split pattern by * to extract literal parts
    parts = pattern.split('*')
    regex_parts: List[str] = []

    for i, part in enumerate(parts):
        # Escape special regex characters in literal parts
        if part:
            # Escape regex special characters: . [ ^ $ + ? { } | ( )
            escaped = re.escape(part)
            regex_parts.append(escaped)
        # Add capture group for wildcard position (except after last part)
        if i < len(parts) - 1:
            regex_parts.append('(.*?)')
            wildcard_count += 1

    # Build full regex pattern
    regex_str = '^' + ''.join(regex_parts) + '$'

    # Replace lazy (.*?) with greedy (.*) - bash =~ doesn't support lazy
    # But Python re.match can be greedy, so we use .* directly for simplicity
    # Actually, let's keep the lazy .*? and let Python handle it properly
    # For consistent behavior with shell (greedy), we use .* instead of .*?
    regex_str = regex_str.replace('(.*?)', '(.*)')

    try:
        match = re.match(regex_str, token, re.IGNORECASE)
        if match:
            captures = [g for g in match.groups() if g is not None]
            return (True, captures, wildcard_count)
    except re.error:
        pass

    return (False, [], wildcard_count)


def match_double_star_remainder(
    pattern: str, input_text: str
) -> Tuple[bool, List[str], str]:
    """Match a pattern containing ** against full input text.

    Mirrors the shell match_double_star_remainder() function (sh/wsha.sh L716-775).

    The ** wildcard captures all remaining text after the prefix (before **)
    up to the suffix (after **). This is a two-step match:
    1. Build regex from head and tail parts
    2. Extract remainder that ** captures

    Args:
        pattern: Pattern with ** (e.g., "s**", "g** remote", "** foo")
        input_text: Full input text to match

    Returns:
        Tuple of (match_ok, head_captures, rest_capture):
        - match_ok: True if pattern matches
        - head_captures: Captures from wildcards before **
        - rest_capture: Everything captured by **

    Example:
        >>> ok, caps, rest = match_double_star_remainder('s**', 'ls -l')
        >>> ok
        True
        >>> rest
        'ls -l'
    """
    # Find ** position in pattern
    dstar_idx = pattern.find('**')
    if dstar_idx < 0:
        return (False, [], "")

    head = pattern[:dstar_idx]
    tail = pattern[dstar_idx + 2 :]

    # Build regex for head and tail parts
    # Escape special chars, then replace * with capture groups
    def build_glob_regex(part: str) -> str:
        """Convert a glob pattern part to regex with capture groups."""
        if not part:
            return ""
        # Escape regex special characters first
        escaped = re.escape(part)
        # Replace escaped \* with actual capture group pattern
        # (our escaped version would be \\* at this point if there was a literal *)
        # Since we're dealing with parts split from **, handle any remaining *
        regex = escaped.replace(r'\*', '(.*?)')
        return regex

    head_regex = build_glob_regex(head)
    tail_regex = build_glob_regex(tail)

    # Count wildcards in head for capture group tracking
    head_star_count = head.count('*')

    # Build full regex: ^head_regex(.*?)tail_regex$
    # The middle (.*?) captures the ** remainder
    full_regex = '^' + head_regex + '(.*?)' + tail_regex + '$'

    # Replace lazy (.*?) with greedy (.*) for shell-compatible behavior
    full_regex = full_regex.replace('(.*?)', '(.*)')

    try:
        match = re.search(full_regex, input_text, re.IGNORECASE)
        if match:
            groups = match.groups()
            # Groups before last are head captures, last is the ** remainder
            if groups:
                head_captures = list(groups[:-1]) if len(groups) > 1 else []
                rest_capture = groups[-1] if groups else ""
                # Filter out empty head captures
                head_captures = [c for c in head_captures if c is not None]
                return (True, head_captures, rest_capture or "")
    except re.error:
        pass

    return (False, [], "")
