# 测试环境搭建与运行手册

本文档说明如何在新的设备上（Windows Git Bash 环境）重建测试环境并运行测试。

## 1. 前置要求

- **操作系统**: Windows (推荐) / Linux / macOS
- **终端**: Git Bash (Windows) 或其他 POSIX 兼容 Shell
- **依赖**: 
  - `git`
  - `bash`

## 2. 环境初始化

克隆项目后，需要初始化子模块以获取 ShellSpec 测试框架。

```bash
# 如果是首次克隆项目
git clone <repository_url>
cd git-utils.sh

# 初始化并更新子模块
git submodule update --init --recursive
```

或者，如果你是手动添加依赖：

```bash
git submodule add https://github.com/shellspec/shellspec .vendor/shellspec
```

## 3. 目录结构说明

- `sh/`: 存放源代码脚本（如 `wsh-real-ignore.sh`）。
- `__test__/`: 存放测试用例（`*_spec.sh`）。
- `.vendor/`: 存放第三方依赖（ShellSpec）。
- `.shellspec`: ShellSpec 配置文件，指定了默认测试目录为 `__test__`。

## 4. 运行测试

在 Git Bash 或 WSL 终端中，执行以下命令运行所有测试：

```bash
./.vendor/shellspec/shellspec
```

**注意**: 如果你在 Windows 的 PowerShell 中尝试运行，可能会报错。请确保使用 `bash` 来执行：

```bash
bash ./.vendor/shellspec/shellspec
```

### 预期输出示例

```text
Running: /bin/sh [bash 4.4.23(1)-release]
...
sh/wsh-real-ignore.sh
  show_help
    outputs help message
  main
    adds file to .gitignore if git rm succeeds
    skips adding if already in .gitignore
    handles git rm failure

Finished in 0.12 seconds (user 0.05 seconds, sys 0.09 seconds)
4 examples, 0 failures
```

## 5. 编写新测试

在 `__test__` 目录下创建新的 `*_spec.sh` 文件。
测试文件应包含被测脚本：

```shell
Describe 'Script Name'
  Include ../sh/script_name.sh
  
  It 'does something'
    When call function_name
    The output should eq "expected"
  End
End
```

注意：被测脚本需要将执行逻辑封装在 `main` 函数中，并使用 `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` 守卫，以便测试框架加载。
