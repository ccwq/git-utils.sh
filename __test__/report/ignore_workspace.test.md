# 测试报告: ignore_workspace.test.sh
测试时间: 2026-01-19 13:27:24


## 1. 环境准备
- 清理旧的测试环境: ignore_workspace_test_dir
- 创建测试目录并初始化 Git 仓库
- 创建测试文件 (file_to_ignore.txt) 和文件夹 (dir_to_ignore/file.txt)
- 提交初始代码到 Git 仓库
- **INFO**: 环境准备完成。

## 2. 测试用例 1: 忽略单个文件
- 执行操作: 忽略 file_to_ignore.txt
- 验证: 检查文件是否还存在于磁盘
- ✅ **PASS**: 文件保留在磁盘
- 验证: 检查文件是否已从 Git 索引移除
- ✅ **PASS**: 文件已从 Git 索引移除
- 验证: 检查 .gitignore 是否包含该文件
- ✅ **PASS**: 文件已添加到 .gitignore

## 3. 测试用例 2: 忽略文件夹
- 执行操作: 忽略 dir_to_ignore
- 验证: 检查文件夹是否还存在于磁盘
- ✅ **PASS**: 文件夹保留在磁盘
- 验证: 检查文件夹内容是否已从 Git 索引移除
- ✅ **PASS**: 文件夹内容已从 Git 索引移除
- 验证: 检查 .gitignore 是否包含该文件夹
- ✅ **PASS**: 文件夹已添加到 .gitignore

## 4. 结束
- 清理测试目录
- **INFO**: 所有测试通过！

**测试结果: ✅ 全部通过**
