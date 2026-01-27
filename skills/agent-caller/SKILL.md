---
name: agent-caller
description: 统一的 Agent 调用工具，供各角色 Agent 在执行任务时调用其他 Agent
---

# Agent 调用工具

统一的 Agent 调用工具脚本，供各角色 Agent 在执行任务时使用，用于调用其他 Agent。

## 快速开始

### Linux/macOS

```bash
# 基本用法
bash skills/agent-caller/call-agent.sh <agent名称> <skill目录名> <任务描述> [超时时间(秒)]
```

### Windows

```powershell
# 基本用法（位置参数，与 shell 脚本一致）
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 <agent名称> <skill目录名> <任务描述> [超时时间(秒)]

# 或者使用命名参数
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 -AgentName <agent名称> -SkillDir <skill目录名> -TaskDesc <任务描述> [-Timeout <超时时间(秒)>]
```

## 使用场景

各角色 Agent 在执行任务时，如果需要调用其他 Agent，可以使用此工具：

- 产品总监调用产品经理、技术总监
- 产品经理调用开发专员、测试专员
- 技术总监调用技术骨干、开发专员
- 技术骨干调用开发专员
- 测试总监调用测试专员

## 使用方法

### 基本用法

**Linux/macOS:**
```bash
bash skills/agent-caller/call-agent.sh <agent名称> <skill目录名> <任务描述> [超时时间(秒)]
```

**Windows:**
```powershell
# 使用位置参数（推荐，与 shell 脚本一致）
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 <agent名称> <skill目录名> <任务描述> [超时时间(秒)]

# 或使用命名参数
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 -AgentName <agent名称> -SkillDir <skill目录名> -TaskDesc <任务描述> [-Timeout <超时时间(秒)>]
```

### 参数说明

- `agent名称`: 要调用的 Agent 名称（如：产品经理、技术总监、开发专员等）
- `skill目录名`: 对应的 skill 目录名（如：product-manager、tech-director、developer等）
- `任务描述`: 要执行的任务描述
- `超时时间`: 可选，默认 600 秒

### 使用示例

**Linux/macOS:**
```bash
# 产品总监调用产品经理编写PRD
bash skills/agent-caller/call-agent.sh "产品经理" "product-manager" "根据产品规划编写PRD文档" 600

# 产品经理调用开发专员进行开发
bash skills/agent-caller/call-agent.sh "开发专员" "developer" "根据详细设计实现功能代码" 1800

# 技术骨干调用开发专员修复Bug
bash skills/agent-caller/call-agent.sh "开发专员" "developer" "根据问题分析修复Bug" 600

# 测试总监调用测试专员编写测试用例
bash skills/agent-caller/call-agent.sh "测试专员" "tester" "编写测试用例" 600
```

**Windows:**
```powershell
# 产品总监调用产品经理编写PRD（使用位置参数）
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 "产品经理" "product-manager" "根据产品规划编写PRD文档" 600

# 产品经理调用开发专员进行开发
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 "开发专员" "developer" "根据详细设计实现功能代码" 1800

# 技术骨干调用开发专员修复Bug
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 "开发专员" "developer" "根据问题分析修复Bug" 600

# 测试总监调用测试专员编写测试用例
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 "测试专员" "tester" "编写测试用例" 600
```

## 功能特性

1. **流式输出**: 实时显示 Agent 执行进度和工具调用信息
2. **超时控制**: 支持设置超时时间，防止无限等待
3. **日志保存**: 自动保存执行日志到 `.vibe/docs/agent_output_*.jsonl`
4. **错误处理**: 完善的错误处理和日志记录

## 输出说明

- 实时显示 Agent 执行进度
- 显示工具调用信息
- 保存完整的执行日志到 `.vibe/docs/agent_output_*.jsonl`
- 返回执行结果（成功/失败）

## 注意事项

1. **统一使用**: 所有角色 Agent 都使用此统一工具调用其他 Agent
2. **超时设置**: 根据任务复杂度合理设置超时时间
3. **参数顺序**: 严格按照参数顺序传递，agent名称和skill目录名要匹配
4. **路径**: 脚本路径相对于项目根目录，确保在正确的工作目录下执行

## 在各角色中的使用

各角色 Agent 在执行任务时，如果需要调用其他 Agent，直接使用此工具：

**Linux/macOS:**
```bash
# 在任何 Agent 的执行过程中
bash skills/agent-caller/call-agent.sh <目标agent> <skill目录> <任务> [超时]
```

**Windows:**
```powershell
# 在任何 Agent 的执行过程中（使用位置参数）
powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 <目标agent> <skill目录> <任务> [超时]
```

工具会自动处理调用、日志记录和错误处理。

## 平台支持

- **Linux/macOS**: 使用 `call-agent.sh` (Bash 脚本)
- **Windows**: 使用 `call-agent.ps1` (PowerShell 脚本)

两个脚本功能完全一致，提供相同的接口和输出格式。

### Windows 使用说明

在 Windows 上使用 PowerShell 脚本时，如果遇到执行策略限制，可以使用以下方式：

1. **临时绕过执行策略**（推荐）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File skills\agent-caller\call-agent.ps1 ...
   ```

2. **设置当前会话的执行策略**：
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
   .\skills\agent-caller\call-agent.ps1 ...
   ```
