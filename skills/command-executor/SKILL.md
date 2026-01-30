---
name: 命令执行防阻塞
description: 当执行可能长时间运行的命令、需要防止阻塞时使用
---

# 目的
提供命令执行的最佳实践，避免因命令阻塞导致整个流程卡住。

# 适用场景
- 编译/构建项目
- 运行测试
- 启动开发服务器
- 安装依赖
- 任何可能长时间运行的命令

# 防阻塞策略

## 策略1：超时控制
对于可能耗时较长的命令，使用 `timeout` 限制执行时间：

```bash
# 编译命令，最多 5 分钟
timeout 300 pnpm build

# 测试命令，最多 3 分钟
timeout 180 pnpm test

# cargo 编译，最多 10 分钟
timeout 600 cargo build --release
```

## 策略2：非交互模式
所有命令必须添加非交互标志，避免等待用户输入：

| 工具 | 非交互标志 |
|------|-----------|
| pnpm/npm | `--yes`, `-y` |
| npx | `--yes` |
| apt | `-y` |
| pip | `--yes`, `-y` |
| cargo | 默认非交互 |
| git | `--no-edit`, `-m "msg"` |
| rsync | `--no-progress` |

示例：
```bash
# 正确
npx --yes create-react-app my-app
pnpm install --frozen-lockfile

# 错误（可能阻塞）
npx create-react-app my-app
```

## 策略3：后台服务管理
启动服务器时，使用后台执行 + PID 记录：

```bash
# 1. 先检测端口是否被占用
lsof -i :3000 | grep LISTEN

# 2. 如果占用，终止现有进程
kill $(lsof -t -i:3000) 2>/dev/null || true

# 3. 后台启动并记录 PID
nohup pnpm dev > /tmp/dev-server.log 2>&1 &
echo $! > /tmp/dev-server.pid

# 4. 等待服务就绪（最多 30 秒）
timeout 30 bash -c 'until curl -s http://localhost:3000 > /dev/null; do sleep 1; done'
```

## 策略4：端口检测
启动任何网络服务前必须检测端口：

```bash
# 检测端口是否可用
check_port() {
  local port=$1
  if lsof -i :$port | grep -q LISTEN; then
    echo "端口 $port 已被占用"
    return 1
  fi
  return 0
}

# 或者获取占用进程
lsof -i :8080 -t  # 返回 PID

# 终止占用进程
kill -9 $(lsof -t -i:8080) 2>/dev/null || true
```

## 策略5：禁用分页器
避免命令输出进入分页模式：

```bash
# Git
git --no-pager log
git --no-pager diff

# 或设置环境变量
GIT_PAGER=cat git log

# 其他命令追加 | cat
command | cat
```

## 策略6：流式输出而非缓冲
对于长时间命令，确保输出不被缓冲：

```bash
# 使用 unbuffer
unbuffer pnpm test

# 或使用 stdbuf
stdbuf -oL -eL pnpm test

# Python 禁用缓冲
PYTHONUNBUFFERED=1 python script.py
```

# 常见场景处理

## 编译项目
```bash
# Node.js 项目
timeout 300 pnpm build 2>&1 | tail -50

# Rust 项目
timeout 600 cargo build --release 2>&1 | tail -100

# 失败时查看完整日志
pnpm build > /tmp/build.log 2>&1 || (cat /tmp/build.log && exit 1)
```

## 运行测试
```bash
# 单元测试（限时 3 分钟）
timeout 180 pnpm test --watchAll=false

# 特定测试文件
timeout 60 pnpm test -- path/to/test.spec.ts --watchAll=false

# Rust 测试
timeout 300 cargo test --no-fail-fast -- --nocapture
```

## 启动开发服务器
```bash
# 1. 终止现有服务
kill $(lsof -t -i:3000) 2>/dev/null || true

# 2. 后台启动
pnpm dev &
DEV_PID=$!

# 3. 等待就绪
sleep 5
curl -s http://localhost:3000 > /dev/null && echo "服务已启动"

# 4. 完成后清理
kill $DEV_PID 2>/dev/null || true
```

## 安装依赖
```bash
# Node.js
timeout 120 pnpm install --frozen-lockfile

# Python
timeout 120 pip install -r requirements.txt --quiet

# Rust
timeout 300 cargo fetch
```

# 阻塞恢复

当命令已经阻塞时：

1. **终止当前命令**：Ctrl+C 或发送 SIGINT
2. **检查后台进程**：`ps aux | grep <command>`
3. **终止相关进程**：`pkill -f <pattern>`
4. **清理端口**：`kill $(lsof -t -i:<port>)`

# 执行前检查清单

在执行任何命令前，检查：

- [ ] 是否需要超时控制？
- [ ] 是否有非交互标志？
- [ ] 是否会启动持久服务？（需后台执行）
- [ ] 是否会使用端口？（需检测端口）
- [ ] 是否可能使用分页器？（需禁用）
- [ ] 预计执行时间是否超过 30 秒？

# 命令模板

## 安全编译
```bash
timeout ${TIMEOUT:-300} ${BUILD_CMD:-pnpm build} 2>&1 | tee /tmp/build.log | tail -30
```

## 安全测试
```bash
timeout ${TIMEOUT:-180} ${TEST_CMD:-pnpm test} --watchAll=false 2>&1 | tail -50
```

## 安全启动服务
```bash
PORT=${PORT:-3000}
kill $(lsof -t -i:$PORT) 2>/dev/null || true
${START_CMD:-pnpm dev} &
timeout 30 bash -c "until curl -s http://localhost:$PORT > /dev/null 2>&1; do sleep 1; done"
```

# 注意事项
- 默认超时时间根据任务类型调整
- 后台服务完成任务后必须清理
- 保留关键命令的日志用于排查
- 优先使用 pnpm 而非 npm
