#!/bin/sh

# Given：当前位于一个 Git 仓库中，工作区与暂存区保持干净，并传入目标分支名称作为来源分支。
# When：用户执行该脚本，对目标分支执行 squash merge，并按来源分支中的 .squash-exclude 排除指定路径。
# Then：脚本应先校验参数与仓库状态，再完成 squash merge，必要时恢复被排除文件，并在无可提交内容时给出明确提示。
# 防回归：避免在脏工作区误执行 merge、遗漏排除配置处理，或在全部排除场景下残留错误的 staged 结果。

set -e
EXCLUDE_CONFIG=".squash-exclude"   # 约定来源分支中的配置文件名
SCRIPT_NAME=$(basename "$0")

show_help() {
  echo "使用方法: $SCRIPT_NAME <target-branch>"
  echo ""
  echo "该脚本用于对目标分支执行 git merge --squash，并根据来源分支中的 .squash-exclude"
  echo "排除指定路径；命中排除规则的路径会恢复为当前分支 HEAD 状态。"
  echo ""
  echo "参数:"
  echo "  target-branch      要执行 squash merge 的来源分支名称。"
  echo ""
  echo "选项:"
  echo "  -h, --help         显示此帮助信息并退出。"
  echo ""
  echo "前置条件:"
  echo "  1. 当前目录必须位于 Git 仓库中。"
  echo "  2. 工作区与暂存区必须保持干净。"
  echo ""
  echo "示例:"
  echo "  $SCRIPT_NAME feature-no-exclude"
  echo "  $SCRIPT_NAME feature-with-exclude"
}

if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

case "$1" in
  -h|--help)
    show_help
    exit 0
    ;;
  -*)
    echo "Error: unknown option '$1'."
    echo ""
    show_help
    exit 1
    ;;
esac

TARGET_BRANCH="$1"

cleanup_temp_files() {
  rm -f "$EXCLUDE_FILE" "$NORMALIZED_EXCLUDE_FILE" "$EXCLUDED_UNMERGED_FILE"
}

normalize_exclude_rules() {
  local source_file="$1"
  local target_file="$2"
  local line=""
  local normalized_line=""

  : > "$target_file"

  while IFS= read -r line || [ -n "$line" ]; do
    normalized_line=$(printf "%s" "$line" | tr -d '\r')

    # 去掉前后空白，避免仅空格的行变成无效 pathspec
    normalized_line=$(printf "%s" "$normalized_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # 跳过空行，避免把无效 pathspec 传给 git restore
    if [ -z "$normalized_line" ]; then
      continue
    fi

    # 支持注释行，便于按文档对规则做分组说明
    case "$normalized_line" in
      \#*)
        continue
        ;;
    esac

    # 支持接近 .gitignore 的根路径写法，例如 /docs -> docs
    case "$normalized_line" in
      /*)
        normalized_line=${normalized_line#/}
        ;;
    esac

    printf "%s\n" "$normalized_line" >> "$target_file"
  done < "$source_file"

  # 始终排除配置文件自身，避免把 .squash-exclude 带入当前分支
  if ! grep -qxF "$EXCLUDE_CONFIG" "$target_file" 2>/dev/null; then
    printf "%s\n" "$EXCLUDE_CONFIG" >> "$target_file"
  fi
}

has_unmerged_paths() {
  git diff --name-only --diff-filter=U | grep -q .
}

resolve_excluded_unmerged_paths() {
  local rule=""
  local path=""

  : > "$EXCLUDED_UNMERGED_FILE"

  while IFS= read -r rule || [ -n "$rule" ]; do
    [ -n "$rule" ] || continue
    git diff --name-only --diff-filter=U -- "$rule" 2>/dev/null || true
  done < "$NORMALIZED_EXCLUDE_FILE" | sort -u > "$EXCLUDED_UNMERGED_FILE"

  if [ ! -s "$EXCLUDED_UNMERGED_FILE" ]; then
    return 0
  fi

  while IFS= read -r path || [ -n "$path" ]; do
    [ -n "$path" ] || continue

    # 冲突路径若命中 exclude，则明确采用当前分支（ours/HEAD）版本。
    if git cat-file -e "HEAD:$path" 2>/dev/null; then
      git checkout --ours -- "$path"
      git add -- "$path"
    else
      rm -rf -- "$path" 2>/dev/null || true
      git rm --cached --ignore-unmatch --quiet -- "$path" 2>/dev/null || true
    fi
  done < "$EXCLUDED_UNMERGED_FILE"
}

apply_exclusions() {
  echo "Applying exclusions..."
  normalize_exclude_rules "$EXCLUDE_FILE" "$NORMALIZED_EXCLUDE_FILE"

  # 先消化命中 exclude 的 unmerged 冲突，再统一把这些路径恢复到当前分支 HEAD。
  resolve_excluded_unmerged_paths
  git restore --source=HEAD --staged --worktree --pathspec-from-file="$NORMALIZED_EXCLUDE_FILE"
}

if [ -z "$TARGET_BRANCH" ]; then
  echo "Error: missing target branch."
  echo ""
  show_help
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree or index is not clean."
  exit 1
fi

# 从来源分支提取排除配置（merge 前，不污染工作区）
EXCLUDE_FILE=$(mktemp)
NORMALIZED_EXCLUDE_FILE=$(mktemp)
EXCLUDED_UNMERGED_FILE=$(mktemp)
trap cleanup_temp_files EXIT

if git show "${TARGET_BRANCH}:${EXCLUDE_CONFIG}" > "$EXCLUDE_FILE" 2>/dev/null; then
  echo "Found exclude config in ${TARGET_BRANCH}:${EXCLUDE_CONFIG}"
else
  echo "No exclude config found in source branch, proceeding without exclusions."
  > "$EXCLUDE_FILE"   # 置空，后续 -s 判断会跳过
fi

set +e
git merge --squash "$TARGET_BRANCH"
merge_exit=$?
set -e

had_unmerged_conflicts=0
if [ "$merge_exit" -ne 0 ] && has_unmerged_paths; then
  had_unmerged_conflicts=1
fi

if [ -s "$EXCLUDE_FILE" ]; then
  apply_exclusions
fi

remaining_unmerged_conflicts=0
if has_unmerged_paths; then
  remaining_unmerged_conflicts=1
fi

if [ "$merge_exit" -ne 0 ]; then
  if [ "$had_unmerged_conflicts" -eq 1 ] && [ "$remaining_unmerged_conflicts" -eq 0 ]; then
    echo "Resolved excluded conflicts by keeping current branch state."
  else
    exit "$merge_exit"
  fi
fi

echo "Current status:"
git status --short

if git diff --cached --quiet; then
  echo "Nothing to commit after applying excludes."
  exit 0
fi
