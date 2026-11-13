<!-- <psm-store version="1" next_id="0002" group_dimension="" /> -->
<!-- <psm id="0001" type="fact" status="active" positive="0" negative="0" created_at="2026-11-13T10:55:54Z" last_scored_at="" /> -->
`wsha_core.py` 通过保护 `~` 后的连续反斜杠并限制最终路径适配，使 `~`、`~\`、`~\\`、`~\\\` 和 `~/` 用户目录写法在 cmd、PowerShell 与 Git Bash 中解析到同一目录，同时保留 `-e` 场景的普通本地路径转换并排除 UNC 路径与 `/c` 开关。
