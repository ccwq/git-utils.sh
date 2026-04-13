"""Alias matching with metadata building, bucket indexing, and best match finding."""

from dataclasses import dataclass
from typing import Optional
from .config import AliasEntry
from .matching import get_tokens, match_token_pattern, match_double_star_remainder


@dataclass
class AliasMetadata:
    """Pre-computed metadata for an alias."""
    name: str
    template: str
    tokens: list[str]  # tokenized alias name
    alias_count: int
    double_token_index: int  # -1=none, -2=multiple, >=0=position
    wildcard_weight: int
    literal_chars: int
    first_token_mode: str  # "literal" or "wildcard"
    first_token_lower: str
    config_path: str
    source_name: str
    line_no: int


def build_alias_metadata(entry: AliasEntry) -> AliasMetadata:
    """
    Build metadata for a single alias entry.

    Per shell L216-267 (build_alias_metadata):
    1. Tokenize alias name using get_tokens()
    2. Compute alias_count: len(tokens)
    3. Find double_token_index: -1=none, -2=multiple, >=0=position
    4. Compute wildcard_weight: ** = 1000, * = 1 each
    5. Compute literal_chars: non-wildcard characters
    6. Determine first_token_mode: "literal" if first token has no *, else "wildcard"
    7. Set first_token_lower: first token lowercased
    """
    alias_name = entry.name
    template = entry.template
    config_path = entry.config_path
    source_name = entry.source_name
    line_no = entry.line_no

    # Tokenize alias name
    _tokens = get_tokens(alias_name)
    alias_tokens = _tokens if isinstance(_tokens, list) else list(_tokens)
    alias_count = len(alias_tokens)

    double_token_index = -1
    wildcard_weight = 0
    first_token_mode = "wildcard"
    first_token_lower = ""

    if alias_count > 0:
        first_token = alias_tokens[0]
        if '*' not in first_token:
            first_token_mode = "literal"
            first_token_lower = first_token.lower()

    # Count wildcards per token
    for ti, token in enumerate(alias_tokens):
        if '**' in token:
            if double_token_index == -1:
                double_token_index = ti
            else:
                # Multiple ** makes alias invalid
                double_token_index = -2
            wildcard_weight += 1000
        elif '*' in token:
            # Count single * wildcards (each * adds 1)
            # But be careful: if token is just "*", that's 1 wildcard
            # Shell code does: tmp="${tmp#*\*}" in a loop to count
            tmp = token
            while '*' in tmp:
                tmp = tmp.replace('*', '', 1)
                wildcard_weight += 1

    # Compute literal_chars: characters that are not *, **, or spaces
    # Strip all wildcards and spaces, count remaining
    stripped = alias_name.replace('**', '').replace('*', '').replace(' ', '')
    literal_chars = len(stripped)

    return AliasMetadata(
        name=alias_name,
        template=template,
        tokens=alias_tokens,
        alias_count=alias_count,
        double_token_index=double_token_index,
        wildcard_weight=wildcard_weight,
        literal_chars=literal_chars,
        first_token_mode=first_token_mode,
        first_token_lower=first_token_lower,
        config_path=config_path,
        source_name=source_name,
        line_no=line_no,
    )


class AliasMatcher:
    """
    Manages alias metadata and finding best match with bucket indexing.

    Bucket indexing (per shell L270-288):
    - _buckets_literal: maps first token literal -> list of alias indexes
    - _buckets_wildcard: list of indexes where first token has wildcard

    Scoring formula (per shell L870, MATCH-06):
    score = alias_count * 10000 + literal_chars * 100 - wildcard_weight
    """

    def __init__(self):
        self._aliases: list[AliasMetadata] = []
        self._buckets_literal: dict[str, list[int]] = {}  # first_token -> [indexes]
        self._buckets_wildcard: list[int] = []

    def add_alias(self, entry: AliasEntry) -> None:
        """
        Add an alias and build its metadata.

        Per shell L216-267 and L270-288:
        1. Build metadata for entry
        2. If first_token_mode == 'literal': add to _buckets_literal[first_token_lower]
        3. Else: add to _buckets_wildcard
        """
        meta = build_alias_metadata(entry)
        idx = len(self._aliases)
        self._aliases.append(meta)

        if meta.first_token_mode == "literal":
            bucket_key = meta.first_token_lower
            if bucket_key not in self._buckets_literal:
                self._buckets_literal[bucket_key] = []
            self._buckets_literal[bucket_key].append(idx)
        else:
            self._buckets_wildcard.append(idx)

    def find_best_match(
        self, input_tokens: list[str]
    ) -> Optional[tuple[str, str, list[str], str, int]]:
        """
        Find best matching alias for input tokens.

        Per shell L788-879 and MATCH-06:
        1. Build candidate list from bucket index (first token literal matches + wildcard bucket)
        2. For each candidate:
           - Validate token count compatibility
           - Match each alias token against input tokens
           - Track captures and wildcard count
        3. Compute score: alias_count * 10000 + literal_chars * 100 - wildcard_weight
        4. Select highest scoring match

        Returns: (matched_alias, template, captures, rest_capture, args_start) or None
        """
        input_count = len(input_tokens)

        best_alias = ""
        best_template = ""
        best_captures: list[str] = []
        best_rest_capture = ""
        best_args_start = 0
        best_score = -1

        # Build candidate indexes
        candidate_indexes: list[int] = []
        if input_count > 0:
            first_token_lower = input_tokens[0].lower()
            if first_token_lower in self._buckets_literal:
                candidate_indexes.extend(self._buckets_literal[first_token_lower])
        candidate_indexes.extend(self._buckets_wildcard)

        for ai in candidate_indexes:
            meta = self._aliases[ai]
            alias_count = meta.alias_count
            double_token_index = meta.double_token_index

            # Skip invalid aliases (multiple **)
            if double_token_index == -2:
                continue

            # Token count compatibility check
            if double_token_index == -1:
                # No ** - input must have at least as many tokens as alias
                if input_count < alias_count:
                    continue
            else:
                # Has ** - input must have at least (double_token_index + 1) tokens
                if input_count < double_token_index + 1:
                    continue

            # Additional check: ** must be at the last position (per shell L820-821)
            if double_token_index >= 0 and double_token_index != alias_count - 1:
                continue

            alias_tokens = meta.tokens
            ok = True
            wildcard_count = 0
            captures: list[str] = []
            rest_capture = ""
            input_consumed = 0

            # Match each alias token against input tokens
            for ti in range(alias_count):
                if ti == double_token_index:
                    # ** token - match remainder using match_double_star_remainder
                    remain_text = input_tokens[ti]
                    for ri in range(ti + 1, input_count):
                        remain_text += " " + input_tokens[ri]

                    match_result = match_double_star_remainder(alias_tokens[ti], remain_text)
                    if not match_result[0]:  # _DSTAR_OK
                        ok = False
                        break
                    # match_result is (ok, captures, rest)
                    captures.extend(match_result[1])  # _DSTAR_CAPTURES
                    rest_capture = match_result[2]  # _DSTAR_REST
                    wildcard_count += 1000
                    input_consumed = input_count
                    continue

                # Regular token - match against input token
                if ti >= input_count:
                    ok = False
                    break

                match_result = match_token_pattern(alias_tokens[ti], input_tokens[ti])
                if not match_result[0]:  # _MATCH_OK
                    ok = False
                    break
                captures.extend(match_result[1])  # _MATCH_CAPTURES
                wildcard_count += match_result[2]  # _MATCH_WILDCARDS
                input_consumed = ti + 1

            if not ok:
                continue

            # Compute score per MATCH-06 formula
            score = alias_count * 10000 + meta.literal_chars * 100 - wildcard_count

            if score > best_score:
                best_score = score
                best_alias = meta.name
                best_template = meta.template
                best_captures = list(captures)
                best_rest_capture = rest_capture
                best_args_start = input_consumed

        if best_score < 0:
            return None

        return (best_alias, best_template, best_captures, best_rest_capture, best_args_start)


# Module-level function for convenience
def find_best_match(
    input_tokens: list[str], aliases: list[AliasEntry]
) -> Optional[tuple[str, str, list[str], str, int]]:
    """
    Find best matching alias for input tokens from a list of AliasEntry.

    Convenience wrapper that creates an AliasMatcher, adds all aliases,
    and finds the best match.

    Returns: (matched_alias, template, captures, rest_capture, args_start) or None
    """
    matcher = AliasMatcher()
    for entry in aliases:
        matcher.add_alias(entry)
    return matcher.find_best_match(input_tokens)
