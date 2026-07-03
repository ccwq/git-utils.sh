# 测试报告: wsh-barry-pick.test.sh

- **测试时间**: 2026-07-03 11:27:13
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_show_help_without_arguments | PASS | 0.195s |  |
| test_show_help_with_short_option | PASS | 0.175s |  |
| test_show_help_with_long_option | PASS | 0.178s |  |
| test_reject_dirty_worktree | PASS | 0.656s |  |
| test_merge_without_exclude_config | PASS | 1.504s |  |
| test_apply_exclude_config | PASS | 1.821s |  |
| test_nothing_to_commit_after_exclude | PASS | 2.269s |  |
| test_apply_gitignore_like_exclude_config | PASS | 3.131s |  |
| test_invalid_exclude_paths_are_ignored | PASS | 2.604s |  |
| test_exclude_config_comment_lines | PASS | 2.161s |  |
| test_restore_existing_file_to_head_when_excluded | PASS | 2.187s |  |
| test_restore_existing_directory_to_head_when_excluded | PASS | 2.343s |  |
| test_merge_conflict_without_exclude | PASS | 1.625s |  |
| test_excluded_file_conflict_does_not_block_squash_merge | PASS | 2.577s |  |
| test_excluded_directory_conflict_does_not_block_squash_merge | PASS | 2.920s |  |
| test_mixed_excluded_and_unexcluded_conflicts_keep_only_unexcluded_conflict | PASS | 2.574s |  |
| test_all_conflicts_excluded_can_finish_with_nothing_to_commit | PASS | 4.423s |  |
| test_excluded_delete_and_rename_keep_current_branch_state | PASS | 2.404s |  |

## 统计汇总
- **总计**: 18
- **通过**: 18
- **失败**: 0
