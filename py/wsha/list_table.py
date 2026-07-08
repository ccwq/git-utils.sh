"""Render wsha alias list as a terminal-friendly table."""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from typing import Iterable, List


@dataclass(frozen=True)
class AliasListEntry:
    """最小渲染数据，避免表格层依赖 wsha core 的 Alias 类型。"""

    key: str
    command: str
    kind: str


GROUP_TITLES = {
    "normal": "普通 alias",
    "wildcard": "通配 alias",
    "block": "block command",
}


def classify_alias(key: str, is_block: bool) -> str:
    if is_block:
        return "block"
    if "*" in key:
        return "wildcard"
    return "normal"


def terminal_width(default: int = 100) -> int:
    return shutil.get_terminal_size((default, 24)).columns


def truncate_text(text: str, width: int) -> str:
    if width <= 0:
        return ""
    if len(text) <= width:
        return text
    if width <= 3:
        return "." * width
    return text[: width - 3] + "..."


def render_alias_table(entries: Iterable[AliasListEntry], width: int | None = None) -> str:
    rows = list(entries)
    if not rows:
        return "[wsha] no alias found."

    table_width = max(40, width or terminal_width())
    alias_width = min(max([len("alias")] + [len(row.key) for row in rows]), 28)
    command_width = max(12, table_width - alias_width - 7)
    divider = f"+-{'-' * alias_width}-+-{'-' * command_width}-+"
    header = f"| {'alias'.ljust(alias_width)} | {'command'.ljust(command_width)} |"

    lines: List[str] = []
    for kind in ("normal", "wildcard", "block"):
        group_rows = sorted((row for row in rows if row.kind == kind), key=lambda row: row.key.lower())
        if not group_rows:
            continue

        if lines:
            lines.append("")
        lines.append(f"[{GROUP_TITLES[kind]}]")
        lines.append(divider)
        lines.append(header)
        lines.append(divider)
        for row in group_rows:
            key = truncate_text(row.key, alias_width).ljust(alias_width)
            command = truncate_text(row.command, command_width).ljust(command_width)
            lines.append(f"| {key} | {command} |")
        lines.append(divider)

    return "\n".join(lines)
