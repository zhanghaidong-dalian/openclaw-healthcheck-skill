#Requires -Version 5.1
<#
.SYNOPSIS
    OpenClaw Windows安全基线检查脚本
.DESCRIPTION
    检查Windows系统是否符合安全基线要求
.VERSION
    3.0.0
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [string]$BaselineLevel = "standard",
    [switch]$ExportReport
)

$ErrorActionPreference = "Continue"

Write-Host "🔐 OpenClaw Windows安全基线检查" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "检查时间: $(Get-Date)"
Write-Host "基线级别: $BaselineLevel"
Write-Host "自动修复: $(if ($AutoFix) { '启用' } else { '禁用' })"
Write-Host ""

# 定义检查项
$checkItems = @()
$findings = @()
$fixedIssues = @()

# 检查项1: UAC启用状态
$checkItems += @{
    id = "UAC-001"
    category = "账户控制"
    name = "UAC已启用"
    description = "用户账户控制(UAC)应始终启用"
    severity = "High"
    check = {
        $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
        if ($reg.EnableLUA -eq 1) {
            return @{ passed = $true; value = "已启用" }
        } else {
            return @{ passed = $false; value = "已禁用"; recommendation = "启用UAC以防止未授权的更改" }
        }
    }
    fix = {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1
        return $true
    }
}

# 检查项2: UAC管理员提示行为
$checkItems += @{
    id = "UAC-002"
    category = "账户控制"
    name = "UAC管理员提示"
    description = "UAC应在管理员操作时提示同意"
    severity = "Medium"
    check = {
        $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
        if ($reg.ConsentPromptBehaviorAdmin -in @(2, 5)) {
            return @{ passed = $true; value = "安全设置 ($($reg.ConsentPromptBehaviorAdmin))" }
        } else {
            return @{ passed = $false; value = "当前设置 ($($reg.ConsentPromptBehaviorAdmin))"; recommendation = "设置为'提示同意'或'提示凭证'" }
        }
    }
    fix = {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 2
        return $true
    }
}

# 检查项3: Windows Defender启用
$checkItems += @{
    id = "DEFENDER-001"
    category = "防病毒"
    name = "Windows Defender启用"
    description = "Windows Defender应启用并运行"
    severity = "Critical"
    check = {
        try {
            $status = Get-MpComputerStatus -ErrorAction Stop
            if ($status.AntivirusEnabled -and $status.RealTimeProtectionEnabled) {
                return @{ passed = $true; value = "启用 + 实时保护" }
            } else {
                return @{ passed = $false; value = "Defender: $($status.AntivirusEnabled), 实时保护: $($status.RealTimeProtectionEnabled)"; recommendation = "启用Windows Defender和实时保护" }
            }
        } catch {
            return @{ passed = $false; value = "无法检测"; recommendation = "检查Windows Defender服务状态" }
        }
    }
}

# 检查项4: 防火墙启用
$checkItems += @{
    id = "FIREWALL-001"
    category = "防火墙"
    name = "Windows防火墙启用"
    description = "所有网络配置文件应启用防火墙"
    severity = "Critical"
    check = {
        $profiles = Get-NetFirewallProfile
        $allEnabled = ($profiles | Where-Object { $_.Enabled -eq $false }).Count -eq 0
        if ($allEnabled) {
            return @{ passed = $true; value = "所有配置文件已启用" }
        } else {
            $disabled = ($profiles | Where-Object { $_.Enabled -eq $false } | Select-Object -ExpandProperty Name) -join ", "
            return @{ passed = $false; value = "$disabled 未启用"; recommendation = "启用所有防火墙配置文件" }
        }
    }
    fix = {
        Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
        return $true
    }
}

# 检查项5: 自动更新启用
$checkItems += @{
    id = "UPDATE-001"
    category = "更新"
    name = "自动更新启用"
    description = "Windows自动更新应启用"
    severity = "High"
    check = {
        $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
        if ($null -eq $reg -or $reg.NoAutoUpdate -ne 1) {
            return @{ passed = $true; value = "已启用" }
        } else {
            return @{ passed = $false; value = "已禁用"; recommendation = "启用自动更新以获取安全补丁" }
        }
    }
}

# 检查项6: 密码策略 - 最小长度
$checkItems += @{
    id = "PASSWORD-001"
    category = "密码策略"
    name = "密码最小长度"
    description = "密码最小长度应至少为12个字符"
    severity = "High"
    check = {
        try {
            $policy = net accounts | Select-String "Minimum password length"
            $length = [int]($policy -replace ".*:\s*", "")
            if ($length -ge 12) {
                return @{ passed = $true; value = "$length 字符" }
            } else {
                return @{ passed = $false; value = "$length 字符"; recommendation = "设置密码最小长度为12或更多" }
            }
        } catch {
            return @{ passed = $false; value = "无法检测"; recommendation = "使用secpol.msc配置密码策略" }
        }
    }
}

# 检查项7: 密码策略 - 复杂度
$checkItems += @{
    id = "PASSWORD-002"
    category = "密码策略"
    name = "密码复杂度"
    description = "应启用密码复杂度要求"
    severity = "High"
    check = {
        try {
            $policy = net accounts | Select-String "Password must meet complexity requirements"
            if ($policy -match "Yes") {
                return @{ passed = $true; value = "已启用" }
            } else {
                return @{ passed = $false; value = "未启用"; recommendation = "启用密码复杂度要求" }
            }
        } catch {
            return @{ passed = $false; value = "无法检测"; recommendation = "使用secpol.msc配置密码策略" }
        }
    }
}

# 检查项8: 密码策略 - 最长使用期限
$checkItems += @{
    id = "PASSWORD-003"
    category = "密码策略"
    name = "密码最长使用期限"
    description = "密码应定期更换(建议90天)"
    severity = "Medium"
    check = {
        try {
            $policy = net accounts | Select-String "Maximum password age"
            $days = [int]($policy -replace ".*:\s*", "")
            if ($days -le 90 -and $days -gt 0) {
                return @{ passed = $true; value = "$days 天" }
            } else {
                return @{ passed = $false; value = if ($days -eq 0) { "永不过期" } else { "$days 天" }; recommendation = "设置密码最长使用期限为90天" }
            }
        } catch {
            return @{ passed = $false; value = "无法检测" }
        }
    }
}

# 检查项9: 账户锁定策略
$checkItems += @{
    id = "LOCKOUT-001"
    category = "账户安全"
    name = "账户锁定策略"
    description = "应启用账户锁定以防止暴力破解"
    severity = "Medium"
    check = {
        try {
            $policy = net accounts | Select-String "Lockout threshold"
            $threshold = ($policy -replace ".*:\s*", "").Trim()
            if ($threshold -ne "Never" -and [int]$threshold -le 5) {
                return @{ passed = $true; value = "$threshold 次失败" }
            } else {
                return @{ passed = $false; value = $threshold; recommendation = "设置账户锁定阈值为5次或更少" }
            }
        } catch {
            return @{ passed = $false; value = "无法检测" }
        }
    }
}

# 检查项10: SMBv1禁用
$checkItems += @{
    id = "SMB-001"
    category = "服务安全"
    name = "SMBv1已禁用"
    description = "不安全的SMBv1协议应禁用"
    severity = "High"
    check = {
        $smb = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
        if ($smb.State -eq "Disabled") {
            return @{ passed = $true; value = "已禁用" }
        } else {
            return @{ passed = $false; value = "状态: $($smb.State)"; recommendation = "禁用SMBv1协议以防止攻击" }
        }
    }
    fix = {
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
        return $true
    }
}

# 检查项11: Telnet客户端禁用
$checkItems += @{
    id = "TELNET-001"
    category = "服务安全"
    name = "Telnet客户端已禁用"
    description = "Telnet客户端应禁用"
    severity = "Medium"
    check = {
        $telnet = Get-WindowsOptionalFeature -Online -FeatureName TelnetClient -ErrorAction SilentlyContinue
        if ($telnet.State -eq "Disabled") {
            return @{ passed = $true; value = "已禁用" }
        } else {
            return @{ passed = $false; value = "已启用"; recommendation = "禁用Telnet客户端" }
        }
    }
}

# 检查项12: 远程注册表禁用
$checkItems += @{
    id = "REGISTRY-001"
    category = "服务安全"
    name = "远程注册表服务已禁用"
    description = "RemoteRegistry服务应禁用"
    severity = "Medium"
    check = {
        $svc = Get-Service -Name RemoteRegistry -ErrorAction SilentlyContinue
        if ($svc -and $svc.StartType -eq "Disabled") {
            return @{ passed = $true; value = "已禁用" }
        } else {
            return @{ passed = $false; value = "启动类型: $($svc.StartType)"; recommendation = "禁用RemoteRegistry服务" }
        }
    }
    fix = {
        Set-Service -Name RemoteRegistry -StartupType Disabled
        Stop-Service -Name RemoteRegistry -Force -ErrorAction SilentlyContinue
        return $true
    }
}

# 检查项13: 来宾账户禁用
$checkItems += @{
    id = "ACCOUNT-001"
    category = "账户安全"
    name = "来宾账户已禁用"
    description = "来宾(Guest)账户应禁用"
    severity = "High"
    check = {
        $guest = Get-LocalUser -Name Guest -ErrorAction SilentlyContinue
        if ($guest -and $guest.Enabled -eq $false) {
            return @{ passed = $true; value = "已禁用" }
        } else {
            return @{ passed = $false; value = "已启用"; recommendation = "禁用来宾账户" }
        }
    }
    fix = {
        Disable-LocalUser -Name Guest
        return $true
    }
}

# 检查项14: 审计策略
$checkItems += @{
    id = "AUDIT-001"
    category = "审计"
    name = "登录事件审计"
    description = "应审计登录和注销事件"
    severity = "Medium"
    check = {
        try {
            $audit = auditpol /get /subcategory:"Logon" 2>$null
            if ($audit -match "Success and Failure") {
                return @{ passed = $true; value = "成功和失败" }
            } else {
                return @{ passed = $false; value = "未配置"; recommendation = "配置审计策略记录登录事件" }
            }
        } catch {
            return @{ passed = $false; value = "无法检测" }
        }
    }
}

# 检查项15: PowerShell执行策略
$checkItems += @{
    id = "PS-001"
    category = "PowerShell"
    name = "PowerShell执行策略"
    description = "PowerShell执行策略应设置为Restricted或AllSigned"
    severity = "Medium"
    check = {
        $policy = Get-ExecutionPolicy
        if ($policy -in @("Restricted", "AllSigned", "RemoteSigned")) {
            return @{ passed = $true; value = $policy }
        } else {
            return @{ passed = $false; value = $policy; recommendation = "设置执行策略为AllSigned或RemoteSigned" }
        }
    }
}

# 执行检查
Write-Host "【开始执行安全基线检查...】" -ForegroundColor Yellow
Write-Host ""

$passedCount = 0
$failedCount = 0
$totalCount = $checkItems.Count
$current = 0

foreach ($item in $checkItems) {
    $current++
    Write-Progress -Activity "安全基线检查" -Status "检查: $($item.name)" -PercentComplete (($current / $totalCount) * 100)
    
    Write-Host "[$($item.id)] $($item.name)" -NoNewline
    
    try {
        $result = & $item.check
        
        if ($result.passed) {
            Write-Host " ✅ 通过" -ForegroundColor Green
            $passedCount++
        } else {
            Write-Host " ❌ 失败" -ForegroundColor Red
            $failedCount++
            
            $finding = @{
                id = $item.id
                category = $item.category
                name = $item.name
                description = $item.description
                severity = $item.severity
                current_value = $result.value
                recommendation = $result.recommendation
            }
            $findings += $finding
            
            # 尝试自动修复
            if ($AutoFix -and $item.fix) {
                Write-Host "    🔧 尝试自动修复..." -NoNewline -ForegroundColor Yellow
                try {
                    $fixResult = & $item.fix
                    if ($fixResult) {
                        Write-Host " 成功" -ForegroundColor Green
                        $fixedIssues += $finding
                    }
                } catch {
                    Write-Host " 失败: $_" -ForegroundColor Red
                }
            }
        }
    } catch {
        Write-Host " ⚠️  错误: $_" -ForegroundColor Yellow
    }
}

Write-Progress -Activity "安全基线检查" -Completed

# 输出报告
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 安全基线检查报告" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "总检查项: $totalCount"
Write-Host "✅ 通过: $passedCount" -ForegroundColor Green
Write-Host "❌ 失败: $failedCount" -ForegroundColor Red
if ($AutoFix -and $fixedIssues.Count -gt 0) {
    Write-Host "🔧 已修复: $($fixedIssues.Count)" -ForegroundColor Yellow
}

$complianceRate = [math]::Round(($passedCount / $totalCount) * 100, 1)
Write-Host ""
Write-Host "合规率: $complianceRate%" -ForegroundColor $(if ($complianceRate -ge 90) { "Green" } elseif ($complianceRate -ge 70) { "Yellow" } else { "Red" })

# 显示失败项详情
if ($findings.Count -gt 0) {
    Write-Host ""
    Write-Host "【需要关注的问题】" -ForegroundColor Yellow
    Write-Host ""
    
    $criticalFindings = $findings | Where-Object { $_.severity -eq "Critical" }
    $highFindings = $findings | Where-Object { $_.severity -eq "High" }
    $mediumFindings = $findings | Where-Object { $_.severity -eq "Medium" }
    
    if ($criticalFindings) {
        Write-Host "🔴 Critical级别问题:" -ForegroundColor Red
        $criticalFindings | ForEach-Object {
            Write-Host "  [$($_.id)] $($_.name)"
            Write-Host "    当前: $($_.current_value)"
            Write-Host "    建议: $($_.recommendation)"
        }
        Write-Host ""
    }
    
    if ($highFindings) {
        Write-Host "🟠 High级别问题:" -ForegroundColor Yellow
        $highFindings | ForEach-Object {
            Write-Host "  [$($_.id)] $($_.name)"
            Write-Host "    建议: $($_.recommendation)"
        }
        Write-Host ""
    }
    
    if ($mediumFindings) {
        Write-Host "🟡 Medium级别问题:" -ForegroundColor DarkYellow
        $mediumFindings | ForEach-Object {
            Write-Host "  [$($_.id)] $($_.name)"
        }
        Write-Host ""
    }
}

# 导出报告
if ($ExportReport) {
    $report = @{
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        baseline_level = $BaselineLevel
        summary = @{
            total = $totalCount
            passed = $passedCount
            failed = $failedCount
            fixed = $fixedIssues.Count
            compliance_rate = $complianceRate
        }
        findings = $findings
    }
    
    $reportPath = "security-baseline-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "✅ 报告已保存: $reportPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "检查完成！" -ForegroundColor Green
