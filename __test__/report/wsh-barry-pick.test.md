# 测试报告: wsh-barry-pick.test.sh

- **测试时间**: 2026-06-02 10:17:26
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_show_help_without_arguments | PASS | 0.364s |  |
| test_show_help_with_short_option | PASS | 0.392s |  |
| test_show_help_with_long_option | PASS | 0.554s |  |
| test_reject_dirty_worktree | PASS | 1.286s |  |
| test_merge_without_exclude_config | PASS | 1.991s |  |
| test_apply_exclude_config | PASS | 2.694s |  |
| test_nothing_to_commit_after_exclude | PASS | 2.163s |  |
| test_apply_gitignore_like_exclude_config | PASS | 3.971s |  |
| test_exclude_config_comment_lines | PASS | 2.782s |  |
| test_restore_existing_file_to_head_when_excluded | PASS | 3.126s |  |
| test_restore_existing_directory_to_head_when_excluded | PASS | 3.947s |  |
| test_merge_conflict_without_exclude | PASS | 2.952s |  |
| test_excluded_file_conflict_does_not_block_squash_merge | PASS | 4.503s |  |
| test_excluded_directory_conflict_does_not_block_squash_merge | PASS | 5.436s |  |
| test_mixed_excluded_and_unexcluded_conflicts_keep_only_unexcluded_conflict | PASS | 4.304s |  |
| test_all_conflicts_excluded_can_finish_with_nothing_to_commit | PASS | 4.888s |  |
| test_excluded_delete_and_rename_keep_current_branch_state | PASS | 3.878s |  |

## 统计汇总
- **总计**: 17
- **通过**: 17
- **失败**: 0
