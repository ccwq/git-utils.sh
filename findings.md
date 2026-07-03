# 发现与决策

## 需求
- 用户要求调查 `w ll` 延迟问题，同时不能破坏已经很快的 `w tping` 路径。
- 用户允许为了精确排查临时打印时间戳，但要求事后删除。
- 用户澄清 `setx` 仍然有作用：首次没有缓存时应写入，但环境变量或 HKCU 缓存已经存在时不应再写。

## 调查发现
- `ll` alias 定义在 `sh/config/wsh-alias/default.txt`：`ll wsh.bat ls -lah`。
- `w ll` 展开链路是 `wsha.bat -> wsh.bat ls -lah -> exec-git-bash.bat -lc ...`。
- 直接 Git Bash 执行 `ls -lah` 很快，诊断时约 `345-357ms`。
- 修复前 `w ll` 和直接 `wsh.bat ls -lah` 都很慢，约 `31-32s`。
- `exec-git-bash.bat` 内临时时间戳显示延迟发生在 `setx GIT_BASH "%GIT_BASH%"`，大约从 `15:36:16` 卡到 `15:36:47`。
- `reg query HKCU\Environment /v GIT_BASH` 很快，通常只有几十毫秒，读取缓存不是瓶颈。
- `where git` 在当前环境也足够快，诊断时约 `94ms`。
- `w tping -qq` 保持快速，是因为 `wsha-core.py` 在 Windows 下把 `wsh <*.sh>` 展开成直接调用 Git Bash：`C:\Program Files\Git\bin\bash.exe ...tping.sh`。

## 技术决策
| 决策 | 理由 |
|------|------|
| 在 `exec-git-bash.bat` 使用 `SHOULD_CACHE_GIT_BASH=0/1` | 区分路径来自已有缓存，还是来自本次重新发现。 |
| 只有继承环境和 HKCU 缓存都未命中后，才设置 `SHOULD_CACHE_GIT_BASH=1` | 精确匹配“首次发现后写缓存”的语义。 |
| 保留 HKCU 缓存读取 | 读取成本低，且保留已有用户级缓存行为。 |
| 保持 `w tping` 的直接 Git Bash 路径 | 避免经过较慢的 `exec-git-bash.bat` 链路，保留即时输出。 |

## 问题与处理
| 问题 | 处理 |
|------|------|
| `setx` 让每次 `exec-git-bash.bat` 调用多出约 30 秒 | 改成只在首次发现 Git Bash 时条件执行。 |
| 完全移除 `setx` 会丢掉缓存写入目的 | 用 `SHOULD_CACHE_GIT_BASH` 恢复条件写入。 |
| 时间戳诊断会污染正常输出 | 根因确认后删除全部临时调试输出。 |

## 相关资源
- `sh/exec-git-bash.bat`：Git Bash 启动器和缓存逻辑。
- `sh/wsha-core.py`：Windows 下 `wsh <*.sh>` 的快路径规范化。
- `sh/config/wsh-alias/default.txt`：`ll`、`tping` 等 alias 定义。
- `sh/tping.sh`：用于验证直接 Git Bash 行为的 HTTP(S) 探测脚本。

## 验证快照
- `exec-git-bash.bat --print-path`：修复后 `60.59ms`。
- `exec-git-bash.bat -lc "true"`：修复后 `358.06ms`。
- `w ll`：修复后 `523.31ms`。
- `w ll` 真实输出已验证，能快速列出仓库根目录。
- `w tping -qq` 静态展开已验证：`"C:\Program Files\Git\bin\bash.exe" E:\project\self.project\git-utils.sh\sh/tping.sh qq.com 443`。

## 视觉/浏览器发现
- 不适用。本次 wrapper 排障没有使用浏览器或图片信息。
