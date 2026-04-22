# wsha-core.py 设计文档

**日期：** 2026-04-22
**目标：** 创建 `sh/wsha-core.py`，将 wsha.sh 的核心逻辑移植到 Python 实现

---

## 背景

当前 wsha.sh 实现了完整的别名展开逻辑，包含配置解析、通配符匹配、模板展开等功能。随着 Python 实现（py/wsha/）的存在，需要一个独立的 Python 核心模块来实现相同功能，而不依赖现有的 py/wsha 模块（后续会删除）。

---

## 设计目标

1. **独立实现** - 不引用 py/wsha 模块，独立完成所有核心功能
2. **CLI 接口** - 通过命令行调用，返回展开后的命令字符串
3. **保持兼容** - 配置格式、匹配逻辑与 wsha.sh 完全兼容
4. **缓存支持** - 提升性能，支持手动清理和自动过期

---

## 技术方案

### 文件结构

```
sh/
├── wsha-core.py    # 新增：Python 核心实现
├── wsha.sh         # 修改：调用 wsha-core.py
├── w.sh            # 修改：调用 wsha-core.py
└── w.bat           # 修改：调用 wsha-core.py
```

### wsha-core.py 职责

1. **配置加载**
   - 扫描 `config/wsh-alias/` 目录下的 `*.txt` 文件
   - 跳过 `_` 前缀文件
   - 按优先级加载：内置 > 用户 > 项目
   - 解析 alias 和 template 的映射关系

2. **别名匹配**
   - 支持 `*` 单 token 通配符
   - 支持 `**` 多 token 捕获
   - 按 score 评分选择最佳匹配
   - 优先 literal 首 token 分桶优化

3. **模板展开**
   - 替换 `$1`..`$N` 捕获变量
   - 替换 `$$` 为剩余输入
   - 处理 `--` 占位符插入运行时参数
   - 展开 `%VAR%` 环境变量

4. **Token 规范化**
   - 检测 `w.bat`、`wsha.bat`、`wsh.bat` 等调用
   - 根据操作系统添加必要的前缀（如 `bash`）
   - 处理 Docker/Podman 的 MSYS 环境变量

5. **缓存机制**
   - 缓存文件：`~/.cache/wsha/*.cache`
   - 过期时间：5 分钟
   - 支持 `w --clear` 清理缓存

### CLI 接口

```bash
# 基本用法
python sh/wsha-core.py <alias> [args...]

# 特殊参数
python sh/wsha-core.py --help        # 显示帮助
python sh/wsha-core.py --list        # 列出所有别名
python sh/wsha-core.py --clear       # 清理缓存
```

### 输出格式

- 成功：输出展开后的命令字符串（stdout）
- 未找到：输出原始输入（透传）
- 调试信息：输出到 stderr

---

## 实现细节

### 配置解析

```python
# 伪代码
def load_config():
    configs = []
    for dir in [APP_HOME/config, USER/config, PWD/config]:
        for file in sorted(glob("*.txt")):
            if not file.startswith('_'):
                configs.append(parse_file(file))
    return configs
```

### 匹配算法

```python
# 伪代码
def find_best_match(input_tokens):
    candidates = bucket_lookup(input_tokens[0])
    candidates += wildcard_candidates

    best = None
    best_score = -1

    for alias in candidates:
        score = calculate_score(alias, input_tokens)
        if score > best_score:
            best = alias
            best_score = score

    return best
```

### 缓存策略

```python
# 缓存文件命名
cache_key = hash(config_mtime + config_size)
cache_file = ~/.cache/wsha/{cache_key}.cache

# 过期检查
if cache_exists and not is_expired(cache_file, max_age=300):
    return load_from_cache()
else:
    result = parse_config()
    save_to_cache(result)
    return result
```

---

## Shell 脚本改造

### wsha.sh 改造

```bash
# 原有逻辑改为调用 Python
main() {
    if [[ "$1" == "--clear" ]]; then
        python "$APP_SH/wsha-core.py" --clear
        exit 0
    fi

    result=$(python "$APP_SH/wsha-core.py" "$@")
    if [[ -n "$result" ]]; then
        eval "$result"
    fi
}
```

### w.sh / w.bat 改造

类似地调用 wsha-core.py，设置 WSHA_ENTRY 环境变量。

---

## 兼容性要求

1. **配置格式** - 完全兼容现有 `config/wsh-alias/*.txt`
2. **匹配规则** - 与 wsha.sh 的评分算法一致
3. **模板展开** - 行为一致
4. **优先级** - 内置 < 用户 < 项目

---

## 验收标准

1. `python sh/wsha-core.py` 显示帮助信息
2. `python sh/wsha-core.py --list` 列出所有别名
3. `python sh/wsha-core.py --clear` 清理缓存
4. `python sh/wsha-core.py pcodex` 返回 `pnpx @openai/codex`
5. `python sh/wsha-core.py "bu test"` 返回 `uvx browser-use test`
6. `python sh/wsha-core.py not-exist` 返回 `not-exist`（透传）
7. Shell 脚本（w.sh, w.bat, wsha.sh）正常工作

---

## 后续计划

- 完成 wsha-core.py 实现
- 改造 wsha.sh、w.sh、w.bat
- 测试验证兼容性
- 删除 py/wsha 模块