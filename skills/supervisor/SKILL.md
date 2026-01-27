---
name: supervisor
description: Coordinates product iteration workflow by automatically scheduling role agents and managing iteration cycles. Use when starting a new iteration, coordinating multi-role tasks, or managing product development workflows.
---

# 产品迭代调度器

协调各角色 Agent 执行产品迭代任务，管理迭代流程。**Supervisor 只调用 Director 级别的角色**（产品总监、技术总监、测试总监），Director 会自己决定调用下一级的角色，形成层级调用链。

## 快速开始

启动迭代流程：

```javascript
// Supervisor 只调用 Director 级别的角色
// 例如：规划阶段调用产品总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/product-director 根据迭代目标制定产品规划文档\"",
    cwd: "<当前工作目录>"
  }
})
// 产品总监会自己决定是否调用产品经理等下一级角色
```

## 使用场景

- 启动新的产品迭代周期
- 协调多角色完成复杂任务
- 自动化产品开发流程
- 管理迭代进度和阶段推进

## 工作方式

Supervisor 通过读取迭代计划，根据当前阶段调用相应的 **Director 级别角色**。Director 会自己决定调用下一级的角色，形成层级调用链。

**角色层级**：
- **Director 级别**（Supervisor 直接调用）：
  - 产品总监 (product-director)
  - 技术总监 (tech-director)
  - 测试总监 (test-director)
- **Manager/Lead 级别**（由 Director 调用）：
  - 产品经理 (product-manager) - 由产品总监调用
  - 技术骨干 (tech-lead) - 由技术总监调用
- **执行级别**（由 Manager/Lead 调用）：
  - 开发专员 (developer) - 由产品经理/技术骨干调用
  - 测试专员 (tester) - 由测试总监调用

**工作流程**：
1. 读取 `.vibe/docs/迭代计划.md` 获取当前阶段
2. 根据阶段使用 `agent-caller` 工具（通过 MCP）调用相应的 Director 级别角色
3. Director 会自己决定是否调用下一级角色，形成层级调用链
4. 完成当前阶段后，等待人工更新迭代计划进入下一阶段

**调用方式**：
Supervisor **只调用 Director 级别角色**，例如：

```javascript
// 规划阶段：调用产品总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/product-director 根据迭代目标制定产品规划文档\"",
    cwd: "<当前工作目录>"
  }
})
// 产品总监会自己决定是否调用产品经理

// 设计阶段：调用产品总监和技术总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/product-director 审批PRD文档\"",
    cwd: "<当前工作目录>"
  }
})
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/tech-director 评审PRD的技术可行性\"",
    cwd: "<当前工作目录>"
  }
})
// 产品总监会调用产品经理编写PRD，技术总监会调用技术骨干进行详细设计
```

详细说明请参考 `skills/agent-caller/SKILL.md`。

## 工作流程

### 1. 初始化迭代计划

创建或更新 `.vibe/docs/迭代计划.md`：

```markdown
# 迭代计划 - v1.0.0

## 迭代目标
{填写迭代目标}

## 当前阶段
规划

## 任务分配
| 角色 | 任务 | 状态 |
|------|------|------|
| 产品总监 | | pending |
| 产品经理 | | pending |
| 技术总监 | | pending |
| 技术骨干 | | pending |
| 开发专员 | | pending |
| 测试总监 | | pending |
| 测试专员 | | pending |
```

### 2. 启动迭代流程

根据迭代计划中的当前阶段，使用 `agent-caller`（通过 MCP）调用相应的 **Director 级别角色**：

```javascript
// 规划阶段：调用产品总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/product-director 根据迭代目标制定产品规划文档\"",
    cwd: "<当前工作目录>"
  }
})
// 产品总监会自己决定是否调用产品经理

// 设计阶段：调用产品总监和技术总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/product-director 审批PRD并协调产品设计工作\"",
    cwd: "<当前工作目录>"
  }
})
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/tech-director 评审PRD技术可行性并协调技术设计工作\"",
    cwd: "<当前工作目录>"
  }
})
// 产品总监会调用产品经理编写PRD，技术总监会调用技术骨干进行详细设计

// 开发阶段：调用技术总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/tech-director 协调开发工作\"",
    cwd: "<当前工作目录>"
  }
})
// 技术总监会调用技术骨干和开发专员

// 测试阶段：调用测试总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/test-director 制定测试策略并协调测试工作\"",
    cwd: "<当前工作目录>"
  }
})
// 测试总监会调用测试专员执行测试
```

### 3. 监控执行

Director 级别的 Agent 会自动：
- 执行任务并决定是否需要调用下一级 Agent（Manager/Lead 或执行级别）
- 显示实时执行进度
- 保存执行日志到 `.vibe/docs/agent_output_*.jsonl`
- 形成层级调用链：Director → Manager/Lead → 执行级别

### 4. 处理阶段推进

当 Director 级别的 Agent 完成当前阶段的任务后：
1. 查看迭代计划文档了解当前状态
2. 更新迭代计划中的当前阶段到下一阶段
3. 使用 `agent-caller`（通过 MCP）调用下一阶段的 Director 级别角色

## Agent 调用流程

Supervisor 使用统一的 `agent-caller` 工具（通过 MCP）**只调用 Director 级别角色**。Director 在执行过程中会自己决定调用下一级角色，形成层级调用链。

**调用层级**：
```
Supervisor
  └─ Director 级别（Supervisor 直接调用）
      ├─ 产品总监 (product-director)
      │   └─ 产品经理 (product-manager) → 开发专员 (developer)
      ├─ 技术总监 (tech-director)
      │   └─ 技术骨干 (tech-lead) → 开发专员 (developer)
      └─ 测试总监 (test-director)
          └─ 测试专员 (tester)
```

**调用方式**：
- Supervisor 根据迭代计划中的当前阶段，使用 `agent-caller`（通过 MCP）调用相应的 Director 级别角色
- Director 在执行任务时，如果需要调用下一级角色，使用 `call_mcp_tool` 调用 rebebuca MCP 的 `start_agent_task` 方法
- Director 自己决定调用流程，不需要返回 next_step JSON
- **禁止跨层级调用**：Supervisor 不直接调用 Manager/Lead 或执行级别的角色

详细说明请参考 `skills/agent-caller/SKILL.md`。

## 迭代阶段

根据迭代计划中的当前阶段，调用相应的 **Director 级别角色**：

| 阶段 | Supervisor 调用的 Director | 主要任务 | 推进条件 |
|------|---------------------------|----------|----------|
| 规划 | 产品总监 | 产品规划、需求优先级 | 产品规划文档存在且人类确认 |
| 设计 | 产品总监、技术总监 | PRD、技术方案、详细设计 | 三份文档均存在且人类确认 |
| 开发 | 技术总监 | 功能代码、单元测试 | 代码审查通过（无blocking问题） |
| 测试 | 测试总监 | 测试报告、Bug列表 | 通过率≥95%且无P0 Bug |
| 验收 | 产品总监 | 验收结果 | 验收通过且人类确认 |

**注意**：Supervisor 只调用 Director 级别角色，Director 会自己决定调用下一级角色。

## 核心文档

| 文档 | 路径 | 说明 |
|------|------|------|
| 迭代计划 | `.vibe/docs/迭代计划.md` | 当前迭代目标和状态 |
| 决策记录 | `.vibe/docs/决策记录.md` | 人类决策历史 |
| 进度总览 | `.vibe/docs/进度总览.md` | 各角色任务状态 |
| 步骤返回规范 | `.vibe/docs/步骤返回规范.md` | Agent 返回格式规范 |

## 错误处理

`agent-caller` 工具会自动处理以下情况：

1. **超时处理**：Agent 执行超时
   - 记录错误日志
   - 保存输出到 `.vibe/docs/agent_output_*.jsonl`
   - 返回错误状态

2. **执行失败**：Agent 返回非 0 退出码
   - 记录错误信息
   - 保存错误输出供排查
   - 返回错误状态

3. **执行成功**：Agent 正常完成
   - 保存执行日志
   - 返回成功状态

## 角色职责

| 角色 | 能力 | 限制 |
|------|------|------|
| 产品总监 | 规划、审批PRD、优先级 | 不写PRD |
| 产品经理 | 写PRD、跟进、验收、业务调研 | 不做战略决策 |
| 技术总监 | 架构、选型、技术评审 | 不写代码 |
| 技术骨干 | 详设、排查、代码审查、技术调研 | 只排查不修复 |
| 开发专员 | 编码、测试、修Bug | 难题求助骨干 |
| 测试总监 | 测试策略、质量评估 | 不执行测试 |
| 测试专员 | 用例、执行、提Bug | 不修Bug |

## 注意事项

1. **只调用 Director 级别**：Supervisor **只调用 Director 级别角色**（产品总监、技术总监、测试总监），不直接调用 Manager/Lead 或执行级别的角色
2. **层级调用**：Director 会自己决定调用下一级角色，形成层级调用链：Director → Manager/Lead → 执行级别
3. **使用 agent-caller**：启动迭代流程时使用 `agent-caller` 工具（通过 MCP），根据迭代计划调用相应的 Director 级别角色
4. **Director 自主调用**：Director 在执行过程中自己决定调用下一级角色，使用 `call_mcp_tool` 调用 rebebuca MCP 的 `start_agent_task` 方法
5. **阶段推进**：完成当前阶段后，需要人工更新迭代计划中的当前阶段，然后使用 `agent-caller`（通过 MCP）调用下一阶段的 Director 级别角色
6. **文档更新**：Agent 执行后应更新对应的文档（迭代计划、进度总览等）
7. **禁止手动执行**：绝对禁止亲自执行任何具体工作，所有工作必须通过调用 Agent 完成
8. **MCP 调用格式**：使用 `call_mcp_tool` 时，command 参数格式为：`agent -p --force --output-format stream-json --stream-partial-output "/${skillDir} ${taskDesc}"`，cwd 参数设置为当前工作目录

## 示例调用

**Supervisor 调用 Director 级别角色**：

```javascript
// 规划阶段：调用产品总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/product-director 根据迭代目标制定产品规划文档\"",
    cwd: "/Users/dexter/project/vibe"
  }
})
// 产品总监会自己决定是否调用产品经理

// 设计阶段：调用产品总监和技术总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/product-director 审批PRD并协调产品设计工作\"",
    cwd: "/Users/dexter/project/vibe"
  }
})
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/tech-director 评审PRD技术可行性并协调技术设计工作\"",
    cwd: "/Users/dexter/project/vibe"
  }
})
// 产品总监会调用产品经理编写PRD，技术总监会调用技术骨干进行详细设计

// 测试阶段：调用测试总监（Director 级别）
call_mcp_tool({
  server: "rebebuca",
  toolName: "start_agent_task",
  arguments: {
    command: "agent -p --force --output-format stream-json --stream-partial-output \"/test-director 制定测试策略并协调测试工作\"",
    cwd: "/Users/dexter/project/vibe"
  }
})
// 测试总监会调用测试专员执行测试
```

**注意**：Supervisor 不直接调用产品经理、技术骨干、开发专员、测试专员等非 Director 级别角色，这些角色由对应的 Director 调用。

MCP 服务器会自动处理任务执行、日志记录和错误处理。执行结果和日志由 MCP 服务器管理。

## 详细流程

详细的迭代流程、阶段推进条件、任务状态定义等，请参考：
- 迭代流程详情：见项目文档或相关规范
- Agent 调用工具：`skills/agent-caller/SKILL.md`
- 决策请求格式：`.vibe/docs/决策记录.md`
