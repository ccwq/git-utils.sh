# 主要约束
- 使用中文
- 当前环境是windows, 优先通过 `sh\exec-git-bash.bat` 调用 Git Bash, 例如 `sh\exec-git-bash.bat .\foo\bar.sh`
    - `sh\exec-git-bash.bat` 会优先使用项目内置的 `bin\win-helper\win-helper.exe`
    - 如果 `win-helper.exe` 不存在, 再根据 `where.exe git` 获取 Git Bash 路径执行
- 脚本需要遵守/prompts/spec.md规范


# 同步
文档和测试的同步

- 对于test的更新存在如下约束
    - 如果需要对测试用例进行修改, 需要像我说明原因, 等我审批或者调整之后,才能继续
    - 新特性可以直接新增测试用例
- 当测试用例跑通之后, 再结合测试用例来更新文档
