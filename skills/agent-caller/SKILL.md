---
name: agent-caller
description: 统一的 Agent 调用工具，供各角色 Agent 在执行任务时调用其他 Agent
---

# Agent 调用工具

统一的 Agent 调用工具，供各角色 Agent 在执行任务时使用，用于调用其他 Agent。通过 MCP 工具调用 rebebuca 服务器的 start_agent_task 方法来启动 Agent 任务。

## 快速开始

在 Agent 执行过程中，使用 MCP 工具调用：

```javascript
// 调用 rebebuca MCP 的 start_agent_task 方法
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/${skillDir} ${taskDesc}\"",
    cwd: "<当前工作目录>"
  }
})
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

在 Agent 执行过程中，使用 `call_mcp_tool` 调用 rebebuca MCP 的 `start_agent_task` 方法：

```javascript
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: `agent -p --force --output-format stream-json --stream-partial-output "/${skillDir} ${taskDesc}"`,
    cwd: process.cwd()  // 或使用具体的工作目录路径
  }
})
```

### 参数说明

- `skillDir`: 对应的 skill 目录名（如：product-manager、tech-director、developer等）
- `taskDesc`: 要执行的任务描述
- `cwd`: 当前工作目录（通常是项目根目录）

### 使用示例

```javascript
// 产品总监调用产品经理编写PRD
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/product-manager 根据产品规划编写PRD文档\"",
    cwd: "/Users/dexter/project/vibe"
  }
})

// 产品经理调用开发专员进行开发
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/developer 根据详细设计实现功能代码\"",
    cwd: "/Users/dexter/project/vibe"
  }
})

// 技术骨干调用开发专员修复Bug
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/developer 根据问题分析修复Bug\"",
    cwd: "/Users/dexter/project/vibe"
  }
})

// 测试总监调用测试专员编写测试用例
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/tester 编写测试用例\"",
    cwd: "/Users/dexter/project/vibe"
  }
})
```

## 功能特性

1. **MCP 调用**: 通过 rebebuca MCP 服务器统一管理 Agent 任务执行
2. **流式输出**: 实时显示 Agent 执行进度和工具调用信息
3. **任务管理**: MCP 服务器负责任务的生命周期管理和超时控制
4. **日志保存**: 执行日志由 MCP 服务器管理

## 输出说明

- MCP 工具返回任务执行结果
- 实时显示 Agent 执行进度（通过流式输出）
- 显示工具调用信息
- 执行日志由 MCP 服务器管理

## 注意事项

1. **统一使用**: 所有角色 Agent 都使用此统一的 MCP 工具调用其他 Agent
2. **MCP 服务器**: 确保 rebebuca MCP 服务器已正确配置和启用
3. **工作目录**: 确保 `cwd` 参数设置为正确的工作目录（通常是项目根目录）
4. **命令格式**: command 参数必须严格按照格式：`agent -p --force --output-format stream-json --stream-partial-output "/${skillDir} ${taskDesc}"`

## 在各角色中的使用

各角色 Agent 在执行任务时，如果需要调用其他 Agent，使用 `call_mcp_tool` 调用 rebebuca MCP：

```javascript
// 在任何 Agent 的执行过程中
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: `agent -p --force --output-format stream-json --stream-partial-output "/${skillDir} ${taskDesc}"`,
    cwd: "<当前工作目录>"
  }
})
```

MCP 服务器会自动处理任务执行、日志记录和错误处理。
