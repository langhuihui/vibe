# Agent 调用工具脚本 (PowerShell 版本)
# 供各角色 Agent 在执行任务时使用，用于调用其他 Agent

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$AgentName,
    
    [Parameter(Mandatory=$true, Position=1)]
    [string]$SkillDir,
    
    [Parameter(Mandatory=$true, Position=2)]
    [string]$TaskDesc,
    
    [Parameter(Mandatory=$false, Position=3)]
    [int]$Timeout = 600
)

# 设置错误处理
$ErrorActionPreference = 'Continue'

# 获取脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 获取项目根目录（脚本在 skills/agent-caller/ 目录下）
$ProjectRoot = (Get-Item $ScriptDir).Parent.Parent.FullName

# 切换到项目根目录
Set-Location $ProjectRoot

# 配置（相对于项目根目录）
$VibeDir = ".vibe"
$DocsDir = Join-Path $VibeDir "docs"

# 日志函数
function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor Blue
}

function Log-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor Green
}

function Log-Warn {
    param([string]$Message)
    Write-Host "[WARN] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERROR] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor Red
}

# 调用 Agent 执行任务
function Call-Agent {
    param(
        [string]$AgentName,
        [string]$SkillDir,
        [string]$TaskDesc,
        [int]$Timeout
    )
    
    Log-Info "调用 Agent: $AgentName"
    Log-Info "任务: $TaskDesc"
    Log-Info "超时: ${Timeout}秒"
    
    # 构建任务描述
    $fullTask = "/$AgentName /$SkillDir /agent-caller $TaskDesc"
    
    # 生成输出文件名
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputFile = Join-Path $DocsDir "agent_output_$timestamp.jsonl"
    
    Log-Info "开始流式执行 Agent..."
    
    $exitCode = 0
    $timedOut = $false
    
    try {
        # 创建输出流
        $outputStream = [System.IO.StreamWriter]::new($outputFile, $false, [System.Text.Encoding]::UTF8)
        
        # 配置进程启动信息
        # 使用 codebuddy (cbc) 命令，-y 参数在非交互模式下必需
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cbc"
        # 使用引号包裹任务描述，确保包含空格的内容正确传递
        $psi.Arguments = "-p -y --output-format stream-json `"$fullTask`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        
        # 启动进程
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        $process.Start() | Out-Null
        
        $startTime = Get-Date
        
        # 流式读取输出
        while (-not $process.HasExited) {
            # 检查超时
            if (((Get-Date) - $startTime).TotalSeconds -gt $Timeout) {
                $process.Kill()
                $timedOut = $true
                throw "Timeout"
            }
            
            # 读取标准输出
            if ($process.StandardOutput.Peek() -ge 0) {
                $line = $process.StandardOutput.ReadLine()
                if ($line) {
                    # 保存到文件
                    $outputStream.WriteLine($line)
                    $outputStream.Flush()
                    
                    # 解析并显示 JSON
                    try {
                        $json = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
                        if ($json) {
                            $lineType = $json.type
                            $lineSubtype = $json.subtype
                            
                            if ($lineType -eq "assistant") {
                                $content = $json.message.content[0].text
                                if ($content -and $content.Length -lt 200) {
                                    Write-Host $content
                                }
                            }
                            elseif ($lineType -eq "tool_call") {
                                if ($lineSubtype -eq "started") {
                                    $toolName = ($json.tool_call.PSObject.Properties | Select-Object -First 1).Name
                                    if ($toolName) {
                                        Log-Info "🔧 工具调用: $toolName"
                                    }
                                }
                                elseif ($lineSubtype -eq "completed") {
                                    Log-Success "✅ 工具调用完成"
                                }
                            }
                        }
                    }
                    catch {
                        # 忽略 JSON 解析错误
                    }
                }
            }
            
            Start-Sleep -Milliseconds 50
        }
        
        # 等待进程结束
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        
        # 读取剩余输出
        $remaining = $process.StandardOutput.ReadToEnd()
        if ($remaining) {
            $outputStream.Write($remaining)
        }
        
        # 读取错误输出
        $stderr = $process.StandardError.ReadToEnd()
        if ($stderr) {
            $outputStream.Write($stderr)
            Write-Host $stderr -ForegroundColor Red
        }
        
        $outputStream.Close()
    }
    catch {
        if ($timedOut) {
            Log-Error "Agent 执行超时 (${Timeout}秒)"
            Log-Warn "输出已保存到: $outputFile"
            if ($outputStream) {
                $outputStream.Close()
            }
            exit 1
        }
        else {
            Log-Error "Agent 执行失败: $($_.Exception.Message)"
            Log-Warn "输出已保存到: $outputFile"
            if ($outputStream) {
                $outputStream.Close()
            }
            exit 1
        }
    }
    
    # 检查退出码
    if ($exitCode -ne 0) {
        Log-Error "Agent 执行失败 (退出码: $exitCode)"
        Log-Warn "输出已保存到: $outputFile"
        return 1
    }
    
    Log-Success "Agent 执行完成"
    Log-Info "输出已保存到: $outputFile"
    return 0
}

# 主函数
function Main {
    Log-Info "Agent 调用工具启动"
    
    # 初始化目录
    if (-not (Test-Path $DocsDir)) {
        New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null
    }
    
    # 调用指定的 Agent
    $result = Call-Agent -AgentName $AgentName -SkillDir $SkillDir -TaskDesc $TaskDesc -Timeout $Timeout
    
    switch ($result) {
        0 {
            Log-Success "任务执行成功"
        }
        default {
            Log-Warn "任务执行完成，但可能有异常"
        }
    }
    
    Log-Info "调用工具结束"
    exit $result
}

# 执行主函数
Main
