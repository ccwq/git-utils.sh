# 测试核心工具分层

`__test__/core` 放测试运行基础设施和领域 helper。具体测试文件只保留用例函数、Given/When/Then 注释、断言和 `main()` 执行顺序。

## 文件边界

- `test_utils.sh`：通用测试框架，包含日志、计时、结果记录和报告生成。它不应包含某个命令族的业务 fixture。
- `wsha_helpers.sh`：`wsha` 专用测试 DSL，包含配置 fixture、`run_wsha*` runner、输出清理和 `wsha` 测试沙箱管理。
- `../test_utils.sh`：兼容 shim，只负责 source `core/test_utils.sh`，避免一次性迁移其它测试脚本。

## Fixture 命名

`wsha` fixture 使用具名函数，不再使用 `write_config "$file" "$mode"` 这种字符串 mode 分发。

示例：

```sh
write_wsha_normal_config "$config_file"
write_wsha_grep_chain_config "$config_file"
write_wsha_block_bash_config "$config_file"
```

这样用例文件能直接表达测试数据意图，新增 fixture 时也更容易搜索引用。

## 用例文件规则

- `wsha.test.sh` 保留手写 `main()` 执行顺序，不做自动发现。
- 不抽取统一的测试结束模板，避免改变当前脚本测试风格。
- 新增 shell 测试用例前继续使用中文 Given/When/Then/防回归注释。
