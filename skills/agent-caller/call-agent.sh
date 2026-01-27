#!/bin/bash

# Agent 调用工具脚本
# 供各角色 Agent 在执行任务时使用，用于调用其他 Agent

set -euo pipefail

# 获取项目根目录（脚本在 skills/agent-caller/ 目录下）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 切换到项目根目录
cd "${PROJECT_ROOT}"

# 配置（相对于项目根目录）
VIBE_DIR=".vibe"
DOCS_DIR="${VIBE_DIR}/docs"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 调用 Agent 执行任务
# 参数: $1=agent名称, $2=skill目录名, $3=任务描述, $4=超时时间(秒)
call_agent() {
    local agent_name="$1"
    local skill_dir="$2"
    local task_desc="$3"
    local timeout="${4:-600}"
    
    log_info "调用 Agent: ${agent_name}"
    log_info "任务: ${task_desc}"
    log_info "超时: ${timeout}秒"
    
    # 构建任务描述
    local full_task="/${agent_name} /${skill_dir} /agent-caller ${task_desc}"
    
    # 调用 agent，使用流式 JSON 格式输出
    local output_file="${DOCS_DIR}/agent_output_$(date +%Y%m%d_%H%M%S).jsonl"
    local exit_code=0
    
    log_info "开始流式执行 Agent..."
    
    # 使用流式 JSON 输出，逐行处理
    # 使用 codebuddy (cbc) 命令，-y 参数在非交互模式下必需
    timeout "${timeout}" cbc -p -y --output-format stream-json "${full_task}" 2>&1 | \
    while IFS= read -r line; do
        # 保存每一行到输出文件
        echo "${line}" >> "${output_file}"
        
        # 跳过空行
        [ -z "${line}" ] && continue
        
        # 解析 JSON 行并显示进度
        if command -v jq >/dev/null 2>&1; then
            local line_type=$(echo "${line}" | jq -r '.type // empty' 2>/dev/null || echo "")
            local line_subtype=$(echo "${line}" | jq -r '.subtype // empty' 2>/dev/null || echo "")
            
            case "${line_type}" in
                "assistant")
                    # 显示 assistant 消息（简化显示）
                    local content=$(echo "${line}" | jq -r '.message.content[0].text // empty' 2>/dev/null || echo "")
                    if [ -n "${content}" ] && [ ${#content} -lt 200 ]; then
                        echo "${content}"
                    fi
                    ;;
                "tool_call")
                    if [ "${line_subtype}" = "started" ]; then
                        # 显示工具调用信息
                        local tool_name=$(echo "${line}" | jq -r '.tool_call | keys[0] // empty' 2>/dev/null || echo "")
                        if [ -n "${tool_name}" ]; then
                            log_info "🔧 工具调用: ${tool_name}"
                        fi
                    elif [ "${line_subtype}" = "completed" ]; then
                        log_success "✅ 工具调用完成"
                    fi
                    ;;
            esac
        fi
    done || exit_code=$?
    
    echo ""  # 换行
    
    # 检查退出码
    if [ $exit_code -eq 124 ]; then
        log_error "Agent 执行超时 (${timeout}秒)"
        log_warn "输出已保存到: ${output_file}"
        return 1
    elif [ $exit_code -ne 0 ]; then
        log_error "Agent 执行失败 (退出码: ${exit_code})"
        log_warn "输出已保存到: ${output_file}"
        return 1
    fi
    
    log_success "Agent 执行完成"
    log_info "输出已保存到: ${output_file}"
    return 0
}

# 主函数
main() {
    log_info "Agent 调用工具启动"
    
    # 解析命令行参数
    if [ $# -lt 3 ]; then
        log_error "参数不足"
        echo "用法: $0 <agent名称> <skill目录名> <任务描述> [超时时间(秒)]"
        echo ""
        echo "示例:"
        echo "  $0 产品经理 product-manager \"编写PRD文档\" 600"
        echo "  $0 技术总监 tech-director \"进行技术评审\" 600"
        echo "  $0 开发专员 developer \"实现功能代码\" 1800"
        echo "  $0 测试专员 tester \"编写测试用例\" 600"
        exit 1
    fi
    
    local agent_name="$1"
    local skill_dir="$2"
    local task_desc="$3"
    local timeout="${4:-600}"
    
    # 初始化目录
    mkdir -p "${DOCS_DIR}"
    
    # 调用指定的 Agent
    call_agent "${agent_name}" "${skill_dir}" "${task_desc}" "${timeout}"
    
    local result=$?
    
    case $result in
        0)
            log_success "任务执行成功"
            ;;
        *)
            log_warn "任务执行完成，但可能有异常"
            ;;
    esac
    
    log_info "调用工具结束"
    return $result
}

# 执行主函数
main "$@"
