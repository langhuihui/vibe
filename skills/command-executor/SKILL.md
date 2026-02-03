````markdown
---
name: 命令执行与错误处理规范
description: 命令执行规范（防阻塞、跨平台、超时）+ 错误分类、处理策略与升级路径，所有执行命令或处理错误的Agent均需遵循
---

# 目的与整合说明

本 Skill 整合**命令执行规范**与**错误处理规范**，统一处理执行与错误问题。

- **命令执行**：定义跨操作系统的命令执行规范，防止阻塞命令导致系统无限等待，确保命令在不同平台上正确执行。
- **错误处理**：定义统一的错误分类、记录格式、处理策略与升级路径，确保各角色在遇到问题时有清晰的处理策略。

**核心原则：防阻塞、跨平台、可超时；错误可分类、可追溯、可升级**

> 任何终端命令执行前必须评估阻塞风险和系统兼容性。
>
> **铁律：NO BLOCKING COMMANDS WITHOUT TIMEOUT OR BACKGROUND MODE**

# 适用场景
- 所有需要执行终端命令的 Agent
- 测试执行、构建运行、服务启动
- 文件操作、环境检查、依赖安装
- 任何 Agent 执行过程中遇到错误、需决定重试或升级策略
- 需要记录和追踪问题

# 操作系统检测（必须首先执行）

## 检测方法

在执行任何系统相关命令前，**必须先检测操作系统**：

```bash
# 通用检测方法
uname -s 2>/dev/null || echo "Windows"
```

### 检测结果与平台映射

| uname 输出 | 平台 | 变量设置 |
|-----------|------|----------|
| Darwin | macOS | `OS_TYPE=macos` |
| Linux | Linux | `OS_TYPE=linux` |
| MINGW* / MSYS* / CYGWIN* | Windows (Git Bash) | `OS_TYPE=windows` |
| 命令失败 | Windows (CMD/PowerShell) | `OS_TYPE=windows` |

## 平台特定命令对照表

### 文件系统操作

| 操作 | macOS/Linux | Windows (CMD) | Windows (PowerShell) |
|------|-------------|---------------|----------------------|
| 列出文件 | `ls -la` | `dir` | `Get-ChildItem` |
| 查看文件 | `cat file` | `type file` | `Get-Content file` |
| 删除文件 | `rm file` | `del file` | `Remove-Item file` |
| 删除目录 | `rm -rf dir` | `rmdir /s /q dir` | `Remove-Item -Recurse dir` |
| 创建目录 | `mkdir -p dir` | `mkdir dir` | `New-Item -ItemType Directory dir` |
| 复制文件 | `cp src dst` | `copy src dst` | `Copy-Item src dst` |
| 移动文件 | `mv src dst` | `move src dst` | `Move-Item src dst` |
| 查找文件 | `find . -name "*.txt"` | `dir /s *.txt` | `Get-ChildItem -Recurse -Filter *.txt` |
| 搜索内容 | `grep "text" file` | `findstr "text" file` | `Select-String "text" file` |

### 进程和网络操作

| 操作 | macOS | Linux | Windows |
|------|-------|-------|---------|
| 查看端口占用 | `lsof -i :PORT` | `ss -tlnp \| grep PORT` 或 `netstat -tlnp` | `netstat -ano \| findstr PORT` |
| 杀死进程 | `kill -9 PID` | `kill -9 PID` | `taskkill /F /PID PID` |
| 按名称杀进程 | `pkill -f name` | `pkill -f name` | `taskkill /F /IM name.exe` |
| 查看进程 | `ps aux` | `ps aux` | `tasklist` |
| 环境变量 | `export VAR=val` | `export VAR=val` | `set VAR=val` (CMD) / `$env:VAR=val` (PS) |
| 路径分隔符 | `/` | `/` | `\` (但 `/` 在大多数工具中也可用) |

### 包管理器

| 平台 | 包管理器 | 安装示例 |
|------|---------|----------|
| macOS | Homebrew | `brew install jq` |
| Ubuntu/Debian | apt | `sudo apt install jq` |
| CentOS/RHEL | yum/dnf | `sudo yum install jq` |
| Windows | Chocolatey | `choco install jq` |
| Windows | Scoop | `scoop install jq` |
| Windows | winget | `winget install jqlang.jq` |

# 阻塞命令处理（核心规范）

## 阻塞命令识别

### 高风险阻塞命令列表

| 类别 | 命令示例 | 阻塞原因 |
|------|----------|----------|
| **服务器启动** | `npm run dev`, `npm start`, `cargo run`, `python -m http.server`, `go run main.go`, `rails server`, `flask run` | 持续运行，等待请求 |
| **监听模式** | `npm test --watch`, `cargo watch`, `tsc --watch`, `nodemon` | 持续监听文件变化 |
| **持续测试** | `cargo test` (有些情况), `pytest` (某些插件), `jest --watch` | 可能等待输入或持续运行 |
| **交互式命令** | `npm init`, `git commit` (无 -m), `ssh`, `mysql`, `psql` | 等待用户输入 |
| **长时间操作** | `docker build` (大型镜像), `npm install` (大型项目), `cargo build` (首次编译) | 可能超时 |
| **网络等待** | `curl` (慢服务), `wget` (大文件), `git clone` (大仓库) | 网络延迟 |

### 阻塞检测规则

```
IF 命令包含以下模式 THEN 标记为潜在阻塞:
  - "run dev" | "run start" | "run serve"
  - "server" | "serve" | "listen"
  - "--watch" | "-w" (监听标志)
  - "nodemon" | "supervisor" | "pm2 start"
  - 无参数的 "cargo run" | "go run" | "python app.py"
  - 数据库客户端命令（mysql, psql, mongo, redis-cli）
  
IF 命令可能需要用户输入 THEN 标记为潜在阻塞:
  - "npm init" (无 -y)
  - "git commit" (无 -m)
  - "ssh" (无密钥配置)
```

## 阻塞命令处理策略

### 策略1：后台模式启动（推荐用于服务器）

```bash
# macOS/Linux
nohup npm run dev > /tmp/server.log 2>&1 &
echo $! > /tmp/server.pid
sleep 2  # 等待启动
cat /tmp/server.log | head -20  # 查看启动日志

# 验证是否启动成功
if curl -s http://localhost:3000/health > /dev/null; then
    echo "服务器启动成功"
else
    echo "服务器启动失败，查看日志："
    cat /tmp/server.log
fi
```

```powershell
# Windows PowerShell
Start-Process -NoNewWindow -FilePath "npm" -ArgumentList "run dev" -RedirectStandardOutput "server.log"
Start-Sleep -Seconds 2
Get-Content server.log -Head 20
```

### 策略2：超时控制（推荐用于测试和构建）

```bash
# macOS/Linux - 使用 timeout 命令
timeout 300 npm test  # 5分钟超时
timeout 600 cargo build  # 10分钟超时

# macOS 可能需要 gtimeout (brew install coreutils)
gtimeout 300 npm test

# 或使用后台 + 等待
npm test &
PID=$!
sleep 300 && kill $PID 2>/dev/null &  # 5分钟后杀死
wait $PID
EXIT_CODE=$?
```

```powershell
# Windows PowerShell
$job = Start-Job { npm test }
$result = Wait-Job $job -Timeout 300
if ($result.State -eq 'Running') {
    Stop-Job $job
    Write-Host "测试超时"
} else {
    Receive-Job $job
}
```

### 策略3：非交互模式（推荐用于安装和初始化）

```bash
# 使用 -y 或 --yes 跳过交互
npm init -y
yarn init -y
pip install package --yes
apt install package -y

# Git 提交必须带消息
git commit -m "commit message"

# 使用 expect 处理必须交互的情况（最后手段）
```

### 策略4：预检查 + 条件执行

```bash
# 检查端口是否被占用，避免启动失败阻塞
check_port() {
    local port=$1
    if [ "$(uname)" = "Darwin" ]; then
        lsof -i :$port > /dev/null 2>&1
    elif [ "$(uname)" = "Linux" ]; then
        ss -tlnp | grep ":$port " > /dev/null 2>&1
    else
        netstat -ano | findstr ":$port " > /dev/null 2>&1
    fi
}

if check_port 3000; then
    echo "端口 3000 已被占用，请先关闭占用进程"
    exit 1
fi

# 安全启动
nohup npm run dev &
```

## 超时时间建议

| 操作类型 | 建议超时 | 说明 |
|----------|----------|------|
| 单元测试 | 5 分钟 | 单个测试文件 |
| 集成测试 | 10 分钟 | 完整测试套件 |
| 构建 (增量) | 5 分钟 | 增量编译 |
| 构建 (完整) | 15 分钟 | 首次或完整构建 |
| 依赖安装 | 10 分钟 | npm/pip/cargo install |
| 服务器启动 | 30 秒 | 等待服务就绪 |
| 网络请求 | 30 秒 | curl/wget 单次请求 |

# 命令执行检查清单

## 执行前检查（必须）

```markdown
- [ ] 已检测操作系统类型
- [ ] 命令兼容当前操作系统
- [ ] 已评估阻塞风险
- [ ] 阻塞命令已添加超时或后台处理
- [ ] 交互式命令已添加非交互参数
- [ ] 路径分隔符正确
```

## 命令模板

### 安全执行命令的通用模板

```bash
#!/bin/bash
# 命令执行安全模板

# 1. 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)
echo "检测到操作系统: $OS_TYPE"

# 2. 设置超时命令
if [ "$OS_TYPE" = "macos" ]; then
    # macOS 需要 coreutils
    TIMEOUT_CMD="gtimeout"
    if ! command -v gtimeout &> /dev/null; then
        TIMEOUT_CMD="perl -e 'alarm shift; exec @ARGV' --"
    fi
else
    TIMEOUT_CMD="timeout"
fi

# 3. 执行命令示例（带超时）
echo "执行测试..."
$TIMEOUT_CMD 300 npm test
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    echo "命令执行超时"
    exit 1
elif [ $EXIT_CODE -ne 0 ]; then
    echo "命令执行失败，退出码: $EXIT_CODE"
    exit $EXIT_CODE
fi

echo "命令执行成功"
```

# 常见问题场景处理

## 场景1：启动开发服务器并测试

**错误做法**（会阻塞）：
```bash
npm run dev  # 阻塞！永远不会返回
curl http://localhost:3000  # 永远不会执行
```

**正确做法**：
```bash
# 后台启动
nohup npm run dev > /tmp/dev-server.log 2>&1 &
SERVER_PID=$!

# 等待服务就绪（最多 30 秒）
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo "服务器就绪"
        break
    fi
    sleep 1
done

# 执行测试
curl http://localhost:3000/api/test

# 完成后清理
kill $SERVER_PID 2>/dev/null
```

## 场景2：运行可能超时的测试

**错误做法**（可能无限等待）：
```bash
cargo test  # 某些测试可能卡住
```

**正确做法**：
```bash
# 使用超时
timeout 300 cargo test -- --test-threads=1 2>&1 | tee test-output.log
EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 124 ]; then
    echo "测试超时，查看日志: test-output.log"
    exit 1
fi
```

## 场景3：安装依赖

**错误做法**（可能请求输入）：
```bash
npm init  # 会请求用户输入
```

**正确做法**：
```bash
npm init -y  # 使用默认值
npm install --yes  # 自动确认
pip install -r requirements.txt --no-input
```

## 场景4：检查端口（跨平台）

```bash
check_port_in_use() {
    local port=$1
    case "$(uname -s)" in
        Darwin)
            lsof -i :$port -sTCP:LISTEN > /dev/null 2>&1
            ;;
        Linux)
            ss -tlnp 2>/dev/null | grep -q ":$port " || \
            netstat -tlnp 2>/dev/null | grep -q ":$port "
            ;;
        *)  # Windows
            netstat -ano 2>/dev/null | grep -q ":$port "
            ;;
    esac
}

if check_port_in_use 3000; then
    echo "端口 3000 已被占用"
else
    echo "端口 3000 可用"
fi
```

# 错误处理

## 命令执行失败

```bash
# 捕获退出码和输出
OUTPUT=$(command 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "命令失败 (退出码: $EXIT_CODE)"
    echo "错误信息: $OUTPUT"
    # 记录到错误日志
    echo "[$(date)] 命令失败: $EXIT_CODE - $OUTPUT" >> /tmp/errors.log
fi
```

## 超时处理

```bash
timeout 60 long_running_command
if [ $? -eq 124 ]; then
    echo "命令超时，可能原因："
    echo "1. 命令执行时间超过预期"
    echo "2. 命令陷入无限循环"
    echo "3. 网络请求无响应"
    # 清理可能遗留的进程
    pkill -f "long_running_command" 2>/dev/null
fi
```

# 错误分类与处理策略

## 按严重程度

| 级别 | 代码 | 含义 | 默认处理 |
|------|------|------|----------|
| CRITICAL | E1 | 系统级错误，无法继续 | 立即停止，上报人类 |
| HIGH | E2 | 阻塞当前任务 | 重试 1 次，失败则升级 |
| MEDIUM | E3 | 影响部分功能 | 重试 2 次，失败则记录继续 |
| LOW | E4 | 轻微问题 | 记录并继续 |

## 按错误类型

| 类型 | 代码 | 描述 | 示例 |
|------|------|------|------|
| EXECUTION | T1 | 命令执行失败 | 编译错误、测试失败 |
| TIMEOUT | T2 | 操作超时 | 网络超时、构建超时 |
| RESOURCE | T3 | 资源问题 | 文件不存在、权限不足 |
| LOGIC | T4 | 逻辑错误 | 方案不可行、设计缺陷 |
| DEPENDENCY | T5 | 依赖问题 | 缺少前置文档、等待他人 |
| **BLOCKING** | T6 | **命令阻塞** | **服务器启动、监听模式、无限等待** |
| **PLATFORM** | T7 | **平台不兼容** | **操作系统命令不兼容** |
| UNKNOWN | T9 | 未知错误 | 无法分类的错误 |

## 错误记录格式

```markdown
## ERROR-{YYYYMMDD-HHMMSS}
- **级别**: CRITICAL | HIGH | MEDIUM | LOW
- **类型**: EXECUTION | TIMEOUT | RESOURCE | LOGIC | DEPENDENCY | BLOCKING | PLATFORM | UNKNOWN
- **角色**: {发生错误的 Agent}
- **任务**: {正在执行的任务}
- **错误信息**: {详细错误}
- **上下文**: {相关文件、命令等}
- **已尝试**: {已尝试的解决方法}
- **状态**: 待处理 | 处理中 | 已解决 | 已升级
- **处理方式**: {最终如何处理}
```

## 处理策略

### 策略0：3次失败质疑架构

**铁律：同一问题修复3次仍失败，必须质疑架构**

- 停止修复，标记为架构级问题，升级到技术总监/人类决策。
- 禁止“再试一次”“这次换个方法”；必须记录已尝试方法并升级。

### 策略1：自动重试

适用于网络超时(T2)、临时执行失败(T1)、资源暂时不可用(T3)。最大重试 3 次，重试间隔指数退避(5s/15s/45s)，重试前检查错误是否可能为临时性。

### 策略2：上下文补充后重试

适用于信息不足导致的失败。步骤：分析缺少什么信息 → 从文档或代码获取 → 补充上下文后重试。

### 策略3：升级处理

升级路径：开发专员→技术骨干→技术总监→人类；测试专员→测试总监→人类；产品经理→产品总监→人类。触发条件：重试 N 次仍失败、错误超出当前角色能力、需要决策或授权。

### 策略4：阻塞等待

适用于依赖其他任务(T5)、需人类决策、需外部资源。记录 BLOCKED-{ID}：等待什么、原因、预计解除条件、超时。

## 错误恢复检查清单

错误解决后：验证问题已解决；更新错误记录状态；检查遗留影响；如有价值则总结经验。

## 度量指标

| 指标 | 计算方式 | 告警阈值 |
|------|----------|----------|
| 错误率 | 错误数/总任务数 | > 20% |
| 重试成功率 | 重试成功数/总重试数 | < 50% |
| 平均解决时间 | 总解决时间/错误数 | > 30分钟 |
| 升级率 | 升级数/错误数 | > 30% |

# 与其他 Skill 的集成

## 在测试专员中
- 测试前检测系统类型
- 测试命令必须带超时
- 服务器启动使用后台模式

## 在开发专员中
- 构建命令添加超时
- 开发服务器后台启动
- 清理僵尸进程

## 在 supervisor-fix 中
- 所有测试循环命令带超时
- 检测阻塞后触发熔断
- 记录命令执行耗时

## 在 Supervisor 中
- 监控所有 Agent 的错误
- 统计错误率，触发熔断
- 协调升级处理

## 在各角色 Skill 中
- 按本规范分类错误
- 按本规范选择处理策略
- 按本规范记录错误

# 注意事项

- **所有命令执行前必须先检测操作系统**
- **潜在阻塞命令必须使用超时或后台模式**
- **交互式命令必须添加非交互参数**
- **服务器类命令必须后台启动，并验证就绪状态**
- **命令失败时记录详细错误信息**
- **定期清理后台进程，避免资源泄漏**
- **超时时间要合理，既不能太短导致误判，也不能太长导致等待**
- **错误记录要包含足够上下文，便于他人理解**
- **升级时要带上已尝试的方法，避免重复劳动**
- **严重错误必须立即处理，不能积压**
- **定期回顾错误记录，发现系统性问题**

````
