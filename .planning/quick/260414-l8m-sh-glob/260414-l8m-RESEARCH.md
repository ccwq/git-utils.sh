# Quick Task 260414-l8m: sh/wsha.sh 目录glob支持 - Research

**Task:** 修改 sh/wsha.sh 和相关文档以支持新的目录glob配置结构
**Researched:** 2026-04-14
**Domain:** Shell脚本配置加载 + Python/Shell实现对齐
**Confidence:** HIGH

## Summary

Python版本已完成目录glob支持（parse_dir + 前缀类型），Shell版本需对齐。主要变更点：

1. **配置路径**: `wsh-alias.txt` 单文件 -> `wsh-alias/*.txt` 目录glob
2. **前缀解析**: 新增 `&foo` (sequential) 和 `|foo` (or) 前缀识别
3. **执行分支**: 根据prefix_type选择执行策略

**Primary recommendation:** 在 `load_single_config_file` 之前增加 `load_config_dir` 函数，修改 `load_config` 的spec格式支持目录源，同时修改 `parse_config_line` 支持前缀解析。

## 当前实现差异

| 功能 | Python (已完成) | Shell (待修改) |
|------|-----------------|----------------|
| 配置路径 | `wsh-alias/*.txt` 目录 | `wsh-alias.txt` 单文件 |
| 前缀支持 | `&foo`, `\|foo` | 无 |
| 文件过滤 | 跳过 `_` 前缀文件 | 全部加载 |
| 分桶索引 | 有 | 有 |

## 需要修改的核心函数

### 1. 新增 `load_config_dir` 函数

```bash
# 加载目录中的所有 *.txt 文件，跳过 _ 前缀文件
load_config_dir() {
    local dir_path="$1"
    local fail_on_duplicate="$2"
    local source_name="$3"

    if [[ -z "$dir_path" ]] || [[ ! -d "$dir_path" ]]; then return 0; fi

    # glob 获取 *.txt 文件（1层深）
    local -a txt_files=()
    for f in "$dir_path"/*.txt; do
        [[ -f "$f" ]] && txt_files+=("$f")
    done

    # 按字母序排序
    local sorted_files=()
    IFS=$'\n' sorted_files=($(sort <<< "${txt_files[*]}"))
    unset IFS

    local file
    for file in "${sorted_files[@]}"; do
        local basename="${file##*/}"
        # 跳过 _ 前缀文件
        [[ "$basename" == _* ]] && continue
        load_single_config_file "$file" "$fail_on_duplicate" "$source_name" || return 1
    done
    return 0
}
```

### 2. 修改 `parse_config_line` 支持前缀

当前输出: `alias<TAB>template`
需要输出: `alias<TAB>template<TAB>prefix_type`

```bash
# 在 alias_name 解析之后，检查 & 或 | 前缀
local prefix_type="normal"
if [[ "$alias_name" == &* ]]; then
    prefix_type="sequential"
    alias_name="${alias_name:1}"
elif [[ "$alias_name" == \|* ]]; then
    prefix_type="or"
    alias_name="${alias_name:1}"
fi

# 返回时通过全局变量
_PARSED_PREFIX="$prefix_type"
```

### 3. 修改全局数据结构

需要新增数组存储 prefix_type：

```bash
declare -a ALIAS_PREFIX_TYPES=()  # 新增

# build_alias_metadata 中补充
ALIAS_PREFIX_TYPES[$idx]="$_PARSED_PREFIX"
```

### 4. 修改 `load_config` 的 spec 格式

当前: `config_path|fail_on_duplicate|source_name`
需要支持: `config_path|fail_on_duplicate|source_name|is_dir`

```bash
for spec in "${config_specs[@]}"; do
    IFS='|' read -r _spec_path _spec_dup _spec_source _spec_dir <<< "$spec"
    if [[ "$_spec_dir" == "dir" ]]; then
        load_config_dir "$_spec_path" "$_spec_dup" "$_spec_source" || return 1
    else
        load_single_config_file "$_spec_path" "$_spec_dup" "$_spec_source" || return 1
    fi
done
```

### 5. 修改配置路径变量

```bash
# 原来
builtin_config="$APP_HOME/config/wsh-alias.txt"
user_config="$HOME/.config/wsh-alias.txt"
local_config="$(pwd)/.config/wsh-alias.txt"

# 改为目录
builtin_config_dir="$APP_HOME/config/wsh-alias"
user_config_dir="$HOME/.config/wsh-alias"
local_config_dir="$(pwd)/.config/wsh-alias"

# load_config 调用时
load_config "multi" \
    "$builtin_config_dir|false|内置|dir" \
    "$user_config_dir|false|用户级|dir" \
    "$local_config_dir|false|项目级|dir"
```

### 6. 命令执行分支 (invoke_cmd 或新增)

当前: `invoke_cmd` 直接执行
需要: 根据 prefix_type 选择执行策略

```bash
# 新增执行链处理
execute_chain() {
    local prefix_type="$1"
    shift
    local -a cmd_tokens=("$@")

    case "$prefix_type" in
        sequential)
            # &foo: 依次执行，遇见错误停止
            local cmd_str="${cmd_tokens[*]}"
            $cmd_str || exit $?
            ;;
        or)
            # |foo: 依次执行，遇见成功停止
            local cmd_str="${cmd_tokens[*]}"
            $cmd_str && exit 0 || true
            ;;
        *)
            invoke_cmd "${cmd_tokens[*]}"
            ;;
    esac
}
```

## 文档更新

需要更新 `show_help()` 函数中的配置说明：

```bash
Config priority:
  1. config/wsh-alias/*.txt  (APP_HOME)
  2. $HOME/.config/wsh-alias/*.txt
  3. $PWD/.config/wsh-alias/*.txt

Rules:
  - Same alias: first wins (loaded alphabetically)
  - Files starting with '_' are ignored
  - Prefix & for sequential execution (stop on error)
  - Prefix | for or execution (stop on success)
```

## 兼容性注意事项

1. **现有配置文件**: `config/wsh-alias.txt` 已移至 `config/wsh-alias/main.txt`，无需额外迁移
2. **缓存格式**: `WSHA_CACHE_VERSION` 需更新为 `'v3'` 以避免旧缓存格式问题
3. **WSHA_CONFIG_FILE**: 单文件模式保持兼容（如果指向的是文件而非目录）
4. **Windows Git Bash glob**: `for f in "$dir"/*.txt` 在 Git Bash 中正常工作

## 测试验证点

```bash
# 1. 目录加载测试
mkdir -p /tmp/test-wsha
echo 'test-alias echo hello' > /tmp/test-wsha/main.txt
WSHA_CONFIG_FILE=/tmp/test-wsha w alias

# 2. 前缀测试
echo '&chain-a echo A' > /tmp/test-wsha/chain.txt
echo '&chain-b echo B' >> /tmp/test-wsha/chain.txt
WSHA_CONFIG_FILE=/tmp/test-wsha w chain-a  # 应该执行

# 3. _ 前缀文件跳过
echo 'skip-me echo skip' > /tmp/test-wsha/_skip.txt
# 验证 skip-me 不被加载

# 4. 字母序测试
echo 'zulu echo zulu' > /tmp/test-wsha/zulu.txt
echo 'alpha echo alpha' > /tmp/test-wsha/alpha.txt
# 验证 alpha 优先生效（先加载）
```

## 实施步骤

1. 在 `load_single_config_file` 之前新增 `load_config_dir`
2. 修改 `parse_config_line` 输出 prefix_type，修改 `_PARSED_TEMPLATE` -> `_PARSED_PREFIX`
3. 新增 `ALIAS_PREFIX_TYPES` 数组
4. 修改 `load_config` 中的 spec 解析和调用逻辑
5. 修改 `main` 中的配置路径为目录
6. 更新 `WSHA_CACHE_VERSION` 为 `'v3'`
7. 新增 `execute_chain` 处理前缀执行
8. 更新 `show_help` 文档

## Open Questions

1. **prefix_type 执行时机**: 目前模板展开后执行，是否需要在展开前判断 prefix 决定是否继续？
   - Python版目前存储了 prefix_type 但未实现执行分支，仅解析
   - Quick task 260414-k5k 仅完成了解析层，前缀执行链未实现

2. **别名覆盖逻辑**: Python版 first-wins，Shell版已实现相同逻辑，无需改动
