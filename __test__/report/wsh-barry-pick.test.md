# 测试报告: wsh-barry-pick.test.sh

- **测试时间**: 2026-07-15 16:54:39
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_show_help_without_arguments | PASS | 0.215s |  |
| test_show_help_with_short_option | PASS | 0.231s |  |
| test_show_help_with_long_option | PASS | 0.230s |  |
| test_reject_dirty_worktree | PASS | 0.805s |  |
| test_merge_without_exclude_config | PASS | 1.528s |  |
| test_apply_exclude_config | PASS | 2.189s |  |
| test_nothing_to_commit_after_exclude | PASS | 1.792s |  |
| test_apply_gitignore_like_exclude_config | PASS | 3.599s |  |
| test_invalid_exclude_paths_are_ignored | PASS | 2.658s |  |
| test_exclude_config_comment_lines | PASS | 2.222s |  |
| test_restore_existing_file_to_head_when_excluded | PASS | 2.015s |  |
| test_restore_existing_directory_to_head_when_excluded | PASS | 2.540s |  |
| test_merge_conflict_without_exclude | PASS | 1.622s |  |
| test_excluded_file_conflict_does_not_block_squash_merge | PASS | 2.669s |  |
| test_excluded_directory_conflict_does_not_block_squash_merge | PASS | 3.023s |  |
| test_mixed_excluded_and_unexcluded_conflicts_keep_only_unexcluded_conflict | PASS | 3.038s |  |
| test_all_conflicts_excluded_can_finish_with_nothing_to_commit | PASS | 2.648s |  |
| test_excluded_delete_and_rename_keep_current_branch_state | PASS | 2.429s |  |

## 统计汇总
- **总计**: 18
- **通过**: 18
- **失败**: 0
