#Requires -Version 5.1
<#
.SYNOPSIS
    OpenClaw Windows CVE漏洞检查脚本
.DESCRIPTION
    检查Windows系统是否存在已知CVE漏洞
.VERSION
    3.0.0
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$ExportJson
)

$ErrorActionPreference = "Continue"

Write-Host "🔐 OpenClaw Windows CVE漏洞检查" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "检查时间: $(Get-Date)"
Write-Host ""

# 获取系统信息
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$osVersion = [System.Version]$osInfo.Version
$buildNumber = [int]$osInfo.BuildNumber

Write-Host "系统信息:" -ForegroundColor Yellow
Write-Host "  OS: $($osInfo.Caption)"
Write-Host "  版本: $($osInfo.Version)"
Write-Host "  构建号: $buildNumber"
Write-Host ""

# CVE检查结果
$cveResults = @()

# CVE-2023-36745 - Windows远程代码执行 (示例)
$cveResults += @{
    cve_id = "CVE-2023-36745"
    title = "Windows远程代码执行漏洞"
    cvss = 8.8
    risk_level = "Critical"
    affected_versions = @("Windows 10", "Windows 11", "Windows Server 2019", "Windows Server 2022")
    check = {
        # 检查是否安装了相关补丁
        $hotfix = Get-HotFix | Where-Object { $_.HotFixID -match "KB5034441" }
        if ($hotfix) {
            return @{ status = "patched"; details = "已安装补丁: $($hotfix.HotFixID)" }
        }
        
        # 检查版本是否受影响
        if ($buildNumber -lt 22631) {
            return @{ status = "vulnerable"; details = "构建号 $buildNumber 可能受影响" }
        }
        
        return @{ status = "unknown"; details = "无法确定漏洞状态" }
    }
    fix = {
        Write-Host "请安装Windows更新KB5034441或更新版本" -ForegroundColor Yellow
        return $false
    }
}

# CVE-2023-36746 - Windows权限提升
$cveResults += @{
    cve_id = "CVE-2023-36746"
    title = "Windows权限提升漏洞"
    cvss = 7.8
    risk_level = "High"
    affected_versions = @("Windows 10", "Windows 11")
    check = {
        # 检查注册表缓解措施
        $mitigation = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue
        if ($mitigation -and $mitigation.FeatureSettingsOverride -eq 3) {
            return @{ status = "mitigated"; details = "已启用缓解措施" }
        }
        
        $hotfix = Get-HotFix | Where-Object { $_.HotFixID -match "KB5034442" }
        if ($hotfix) {
            return @{ status = "patched"; details = "已安装补丁" }
        }
        
        return @{ status = "check_needed"; details = "建议安装最新补丁" }
    }
}

# CVE-2023-38148 - Windows HTTP协议栈远程代码执行
$cveResults += @{
    cve_id = "CVE-2023-38148"
    title = "Windows HTTP协议栈远程代码执行"
    cvss = 9.8
    risk_level = "Critical"
    affected_versions = @("Windows Server 2019", "Windows Server 2022")
    check = {
        # 检查HTTP服务
        $httpService = Get-Service -Name HTTP -ErrorAction SilentlyContinue
        if (-not $httpService) {
            return @{ status = "not_applicable"; details = "HTTP服务未运行" }
        }
        
        $hotfix = Get-HotFix | Where-Object { $_.HotFixID -match "KB5034443" }
        if ($hotfix) {
            return @{ status = "patched"; details = "已安装补丁" }
        }
        
        return @{ status = "vulnerable"; details = "HTTP服务运行中但缺少补丁" }
    }
}

# PowerShell日志记录检查 (安全措施)
$cveResults += @{
    cve_id = "CONFIG-001"
    title = "PowerShell日志记录"
    cvss = 0
    risk_level = "Info"
    check = {
        $transcription = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -ErrorAction SilentlyContinue
        $moduleLogging = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -ErrorAction SilentlyContinue
        $scriptBlockLogging = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -ErrorAction SilentlyContinue
        
        $enabled = @()
        if ($transcription.EnableTranscripting -eq 1) { $enabled += "转录" }
        if ($moduleLogging.EnableModuleLogging -eq 1) { $enabled += "模块日志" }
        if ($scriptBlockLogging.EnableScriptBlockLogging -eq 1) { $enabled += "脚本块日志" }
        
        if ($enabled.Count -gt 0) {
            return @{ status = "enabled"; details = "已启用: $($enabled -join ', ')" }
        } else {
            return @{ status = "disabled"; details = "未启用PowerShell日志记录" }
        }
    }
    fix = {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 1
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "OutputDirectory" -Value "C:\Windows\System32\PowerShellLogs"
        
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1
        
        return $true
    }
}

# 执行检查
Write-Host "【执行CVE漏洞检查...】" -ForegroundColor Yellow
Write-Host ""

$results = @()
$vulnerableCount = 0
$patchedCount = 0
$infoCount = 0

foreach ($cve in $cveResults) {
    Write-Host "检查 $($cve.cve_id): $($cve.title)" -NoNewline
    
    try {
        $checkResult = & $cve.check
        
        $result = @{
            cve_id = $cve.cve_id
            title = $cve.title
            cvss = $cve.cvss
            risk_level = $cve.risk_level
            status = $checkResult.status
            details = $checkResult.details
        }
        $results += $result
        
        switch ($checkResult.status) {
            "vulnerable" {
                Write-Host " ❌ 存在漏洞" -ForegroundColor Red
                $vulnerableCount++
                
                if ($AutoFix -and $cve.fix) {
                    Write-Host "    🔧 尝试修复..." -NoNewline -ForegroundColor Yellow
                    try {
                        $fixResult = & $cve.fix
                        if ($fixResult) {
                            Write-Host " 成功" -ForegroundColor Green
                        } else {
                            Write-Host " 需要手动处理" -ForegroundColor Yellow
                        }
                    } catch {
                        Write-Host " 失败: $_" -ForegroundColor Red
                    }
                }
            }
            "patched" {
                Write-Host " ✅ 已修复" -ForegroundColor Green
                $patchedCount++
            }
            "mitigated" {
                Write-Host " ✅ 已缓解" -ForegroundColor Green
                $patchedCount++
            }
            "not_applicable" {
                Write-Host " ➖ 不适用" -ForegroundColor Gray
            }
            default {
                Write-Host " ⚠️  $($checkResult.status)" -ForegroundColor Yellow
                $infoCount++
            }
        }
    } catch {
        Write-Host " ❓ 检查失败: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 CVE检查报告" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "已检查: $($results.Count) 项"
Write-Host "❌ 存在漏洞: $vulnerableCount" -ForegroundColor Red
Write-Host "✅ 已修复/缓解: $patchedCount" -ForegroundColor Green
Write-Host "⚠️  需关注: $infoCount" -ForegroundColor Yellow

# 显示漏洞详情
if ($vulnerableCount -gt 0) {
    Write-Host ""
    Write-Host "【存在漏洞的CVE】" -ForegroundColor Red
    Write-Host ""
    
    $results | Where-Object { $_.status -eq "vulnerable" } | ForEach-Object {
        Write-Host "🔴 $($_.cve_id)" -ForegroundColor Red
        Write-Host "   标题: $($_.title)"
        Write-Host "   CVSS: $($_.cvss) ($($_.risk_level))"
        Write-Host "   详情: $($_.details)"
        Write-Host ""
    }
    
    Write-Host "建议操作:" -ForegroundColor Yellow
    Write-Host "1. 运行Windows Update安装最新补丁"
    Write-Host "2. 检查Microsoft安全公告获取详细信息"
    Write-Host "3. 考虑启用额外的安全缓解措施"
    Write-Host ""
}

# 导出JSON
if ($ExportJson) {
    $jsonOutput = @{
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        system = @{
            os = $osInfo.Caption
            version = $osInfo.Version
            build = $buildNumber
        }
        summary = @{
            total = $results.Count
            vulnerable = $vulnerableCount
            patched = $patchedCount
            info = $infoCount
        }
        results = $results
    }
    
    $jsonPath = "windows-cve-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $jsonOutput | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Host "✅ 报告已保存: $jsonPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "检查完成！" -ForegroundColor Green
