---
name: supervisor
description: Coordinates product iteration workflow by automatically scheduling role agents and managing iteration cycles. Use when starting a new iteration, coordinating multi-role tasks, or managing product development workflows.
---

# 产品迭代调度器

协调各角色 Agent 执行产品迭代任务，管理迭代流程。根据迭代计划中的当前阶段，调用相应的初始 Agent，Agent 会自己决定后续的调用流程。

## 快速开始

启动迭代流程：

```bash
# 使用 agent-caller 根据迭代计划调用初始 Agent
# 例如：规划阶段调用产品总监
bash skills/agent-caller/call-agent.sh "产品总监" "product-director" "根据迭代目标制定产品规划文档" 600
```

## 使用场景

- 启动新的产品迭代周期
- 协调多角色完成复杂任务
- 自动化产品开发流程
- 管理迭代进度和阶段推进

## 工作方式

Supervisor 通过读取迭代计划，根据当前阶段调用相应的初始 Agent。Agent 在执行过程中会自己决定调用其他 Agent，形成递归调用链。

**工作流程**：
1. 读取 `.vibe/docs/迭代计划.md` 获取当前阶段
2. 根据阶段使用 `agent-caller` 工具调用相应的初始 Agent
3. Agent 会自己决定后续的调用流程，递归调用其他 Agent
4. 完成当前阶段后，等待人工更新迭代计划进入下一阶段

**调用方式**：
使用统一的 `agent-caller` 工具调用 Agent，例如：

```bash
# 规划阶段：调用产品总监
bash skills/agent-caller/call-agent.sh "产品总监" "product-director" "根据迭代目标制定产品规划文档" 600

# 设计阶段：调用产品经理
bash skills/agent-caller/call-agent.sh "产品经理" "product-manager" "根据产品规划文档，编写详细的PRD文档" 900
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

根据迭代计划中的当前阶段，使用 `agent-caller` 调用相应的初始 Agent：

```bash
# 规划阶段
bash skills/agent-caller/call-agent.sh "产品总监" "product-director" "根据迭代目标制定产品规划文档" 600

# 设计阶段
bash skills/agent-caller/call-agent.sh "产品经理" "product-manager" "根据产品规划文档，编写详细的PRD文档" 900

# 开发阶段
bash skills/agent-caller/call-agent.sh "开发专员" "developer" "根据详细设计文档，实现功能代码和单元测试" 1800
```

### 3. 监控执行

Agent 会自动：
- 执行任务并决定是否需要调用其他 Agent
- 显示实时执行进度
- 保存执行日志到 `.vibe/docs/agent_output_*.jsonl`

### 4. 处理阶段推进

当 Agent 完成当前阶段的任务后：
1. 查看迭代计划文档了解当前状态
2. 更新迭代计划中的当前阶段到下一阶段
3. 使用 `agent-caller` 调用下一阶段的初始 Agent

## Agent 调用流程

Supervisor 使用统一的 `agent-caller` 工具调用 Agent。Agent 在执行过程中可以自己决定调用其他 Agent，形成递归调用链。

**调用方式**：
- 根据迭代计划中的当前阶段，使用 `agent-caller` 调用相应的初始 Agent
- Agent 在执行任务时，如果需要调用其他 Agent，使用 `bash skills/agent-caller/call-agent.sh` 工具
- Agent 自己决定调用流程，不需要返回 next_step JSON

详细说明请参考 `skills/agent-caller/SKILL.md`。

## 迭代阶段

根据迭代计划中的当前阶段，调用相应的初始 Agent：

| 阶段 | 主要任务 | 推进条件 |
|------|----------|----------|
| 规划 | 产品规划、需求优先级 | 产品规划文档存在且人类确认 |
| 设计 | PRD、技术方案、详细设计 | 三份文档均存在且人类确认 |
| 开发 | 功能代码、单元测试 | 代码审查通过（无blocking问题） |
| 测试 | 测试报告、Bug列表 | 通过率≥95%且无P0 Bug |
| 验收 | 验收结果 | 验收通过且人类确认 |

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

1. **使用 agent-caller**：启动迭代流程时使用 `agent-caller` 工具，根据迭代计划调用初始 Agent
2. **Agent 自主调用**：Agent 在执行过程中自己决定调用其他 Agent，使用统一的 agent-caller 工具
3. **阶段推进**：完成当前阶段后，需要人工更新迭代计划中的当前阶段，然后使用 `agent-caller` 调用下一阶段的初始 Agent
4. **文档更新**：Agent 执行后应更新对应的文档（迭代计划、进度总览等）
5. **禁止手动执行**：绝对禁止亲自执行任何具体工作，所有工作必须通过调用 Agent 完成

## 示例输出

**正常执行**：
```
[INFO] Agent 调用工具启动
[INFO] 调用 Agent: 产品总监
[INFO] 任务: 根据迭代目标制定产品规划文档
[INFO] 超时: 600秒
[INFO] 开始流式执行 Agent...
🔧 工具调用: writeToolCall
✅ 工具调用完成
[SUCCESS] Agent 执行完成
[SUCCESS] 任务执行成功
```

**执行失败**：
```
[ERROR] Agent 执行超时 (600秒)
[WARN] 输出已保存到: .vibe/docs/agent_output_*.jsonl
[WARN] 任务执行完成，但可能有异常
```

## 详细流程

详细的迭代流程、阶段推进条件、任务状态定义等，请参考：
- 迭代流程详情：见项目文档或相关规范
- Agent 调用工具：`skills/agent-caller/SKILL.md`
- 决策请求格式：`.vibe/docs/决策记录.md`
