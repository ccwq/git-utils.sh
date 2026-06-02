# 测试报告: wsh-barry-pick.test.sh

- **测试时间**: 2026-06-02 10:30:30
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_show_help_without_arguments | PASS | 0.444s |  |
| test_show_help_with_short_option | PASS | 0.445s |  |
| test_show_help_with_long_option | PASS | 0.330s |  |
| test_reject_dirty_worktree | PASS | 1.462s |  |
| test_merge_without_exclude_config | PASS | 2.749s |  |
| test_apply_exclude_config | PASS | 3.635s |  |
| test_nothing_to_commit_after_exclude | PASS | 2.753s |  |
| test_apply_gitignore_like_exclude_config | PASS | 4.619s |  |
| test_exclude_config_comment_lines | PASS | 3.657s |  |
| test_restore_existing_file_to_head_when_excluded | PASS | 3.384s |  |
| test_restore_existing_directory_to_head_when_excluded | PASS | 4.057s |  |
| test_merge_conflict_without_exclude | PASS | 2.976s |  |
| test_excluded_file_conflict_does_not_block_squash_merge | PASS | 4.869s |  |
| test_excluded_directory_conflict_does_not_block_squash_merge | PASS | 6.269s |  |
| test_mixed_excluded_and_unexcluded_conflicts_keep_only_unexcluded_conflict | PASS | 4.859s |  |
| test_all_conflicts_excluded_can_finish_with_nothing_to_commit | PASS | 4.760s |  |
| test_excluded_delete_and_rename_keep_current_branch_state | PASS | 3.666s |  |

## 统计汇总
- **总计**: 17
- **通过**: 17
- **失败**: 0
