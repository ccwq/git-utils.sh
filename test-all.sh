# 依次运行/__test__下面的所有sh文件
#!/bin/bash

# 定义测试目录
TEST_DIR="./__test__"

# 检查测试目录是否存在
if [ ! -d "$TEST_DIR" ]; then
    echo "错误: 测试目录 $TEST_DIR 不存在"
    exit 1
fi

# 进入测试目录
cd "$TEST_DIR" || exit 1

# 查找所有 .sh 文件并执行
for test_file in *.sh; do
    if [ -f "$test_file" ]; then
        echo "正在运行测试: $test_file"
        bash "$test_file"
        echo "测试 $test_file 完成"
        echo "------------------------"
    fi
done

echo "所有测试完成"