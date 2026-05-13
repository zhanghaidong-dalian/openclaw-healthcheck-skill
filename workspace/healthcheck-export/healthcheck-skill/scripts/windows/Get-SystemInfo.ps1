#Requires -Version 5.1
<#
.SYNOPSIS
    OpenClaw Windows系统信息收集脚本
.DESCRIPTION
    收集Windows系统的基本信息，用于安全基线检查
.VERSION
    3.0.0
#>

[CmdletBinding()]
param(
    [switch]$ExportJson,
    [string]$OutputPath = "."
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"

Write-Host "🔍 OpenClaw Windows系统信息收集" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "收集时间: $(Get-Date)"
Write-Host ""

# 初始化结果对象
$systemInfo = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    hostname = $env:COMPUTERNAME
    domain = $env:USERDOMAIN
    username = $env:USERNAME
    os_info = @{}
    hardware = @{}
    network = @{}
    security = @{}
    services = @{}
    features = @{}
}

# 1. 操作系统信息
Write-Host "【收集操作系统信息...】" -ForegroundColor Yellow
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $systemInfo.os_info = @{
        caption = $os.Caption
        version = $os.Version
        build_number = $os.BuildNumber
        architecture = $os.OSArchitecture
        install_date = $os.InstallDate
        last_boot = $os.LastBootUpTime
        locale = (Get-WinSystemLocale).Name
    }
    Write-Host "  ✅ OS: $($os.Caption) $($os.Version)" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  无法获取OS信息: $_" -ForegroundColor Yellow
}

# 2. 硬件信息
Write-Host "【收集硬件信息...】" -ForegroundColor Yellow
try {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $memory = Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    
    $systemInfo.hardware = @{
        cpu = @{
            name = $cpu.Name
            cores = $cpu.NumberOfCores
            logical_processors = $cpu.NumberOfLogicalProcessors
        }
        memory = @{
            total_gb = [math]::Round($memory.Sum / 1GB, 2)
            slots = (Get-CimInstance Win32_PhysicalMemory).Count
        }
        disks = @($disks | ForEach-Object {
            @{
                drive = $_.DeviceID
                size_gb = [math]::Round($_.Size / 1GB, 2)
                free_gb = [math]::Round($_.FreeSpace / 1GB, 2)
                filesystem = $_.FileSystem
            }
        })
    }
    Write-Host "  ✅ CPU: $($cpu.Name)" -ForegroundColor Green
    Write-Host "  ✅ Memory: $([math]::Round($memory.Sum / 1GB, 2)) GB" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  无法获取硬件信息: $_" -ForegroundColor Yellow
}

# 3. 网络配置
Write-Host "【收集网络配置...】" -ForegroundColor Yellow
try {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    $ipConfig = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" }
    $firewallProfiles = Get-NetFirewallProfile
    
    $systemInfo.network = @{
        adapters = @($adapters | ForEach-Object {
            @{
                name = $_.Name
                interface_description = $_.InterfaceDescription
                mac_address = $_.MacAddress
                link_speed = $_.LinkSpeed
            }
        })
        ip_addresses = @($ipConfig | ForEach-Object {
            @{
                interface = $_.InterfaceAlias
                ipv4 = @($_.IPv4Address | ForEach-Object { $_.IPAddress })
                ipv6 = @($_.IPv6Address | ForEach-Object { $_.IPAddress })
                gateway = $_.IPv4DefaultGateway.NextHop
            }
        })
        firewall_profiles = @{
            domain = $firewallProfiles | Where-Object { $_.Name -eq "Domain" } | Select-Object -ExpandProperty Enabled
            private = $firewallProfiles | Where-Object { $_.Name -eq "Private" } | Select-Object -ExpandProperty Enabled
            public = $firewallProfiles | Where-Object { $_.Name -eq "Public" } | Select-Object -ExpandProperty Enabled
        }
    }
    Write-Host "  ✅ 发现 $($adapters.Count) 个活动网络适配器" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  无法获取网络信息: $_" -ForegroundColor Yellow
}

# 4. 安全设置
Write-Host "【收集安全设置...】" -ForegroundColor Yellow
try {
    # UAC设置
    $uacReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
    $uacConsent = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
    
    # 密码策略
    $passwordPolicy = Get-LocalUser | Select-Object -First 1 | Get-LocalUserPasswordPolicy -ErrorAction SilentlyContinue
    
    # Windows Defender
    $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
    
    # 自动更新
    $updateSettings = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue
    
    $systemInfo.security = @{
        uac = @{
            enabled = if ($uacReg.EnableLUA -eq 1) { $true } else { $false }
            admin_consent = $uacConsent.ConsentPromptBehaviorAdmin
        }
        windows_defender = @{
            enabled = $defender.AntivirusEnabled
            real_time_protection = $defender.RealTimeProtectionEnabled
            behavior_monitor = $defender.BehaviorMonitorEnabled
            signature_age_days = if ($defender.AntivirusSignatureLastUpdated) { 
                [math]::Round(((Get-Date) - $defender.AntivirusSignatureLastUpdated).TotalDays, 1) 
            } else { $null }
        }
        auto_update = @{
            enabled = if ($updateSettings.NoAutoUpdate -eq 1) { $false } else { $true }
            install_schedule = $updateSettings.ScheduledInstallDay
        }
    }
    Write-Host "  ✅ UAC: $(if ($systemInfo.security.uac.enabled) { '启用' } else { '禁用' })" -ForegroundColor Green
    Write-Host "  ✅ Defender: $(if ($systemInfo.security.windows_defender.enabled) { '启用' } else { '禁用' })" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  无法获取安全设置: $_" -ForegroundColor Yellow
}

# 5. 关键服务
Write-Host "【收集关键服务状态...】" -ForegroundColor Yellow
try {
    $criticalServices = @("WinDefend", "wuauserv", "MpsSvc", "TermService", "RemoteRegistry", "SSDPSRV", "upnphost")
    $serviceStatuses = @()
    
    foreach ($svcName in $criticalServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            $serviceStatuses += @{
                name = $svc.Name
                display_name = $svc.DisplayName
                status = $svc.Status.ToString()
                start_type = $svc.StartType.ToString()
            }
        }
    }
    
    $systemInfo.services = @{
        critical_services = $serviceStatuses
        total_running = (Get-Service | Where-Object { $_.Status -eq "Running" }).Count
        total_stopped = (Get-Service | Where-Object { $_.Status -eq "Stopped" }).Count
    }
    Write-Host "  ✅ 发现 $($serviceStatuses.Count) 个关键服务" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  无法获取服务信息: $_" -ForegroundColor Yellow
}

# 6. 已安装功能
Write-Host "【收集Windows功能...】" -ForegroundColor Yellow
try {
    $features = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Enabled" }
    $systemInfo.features = @{
        enabled_count = $features.Count
        smb_enabled = ($features | Where-Object { $_.FeatureName -like "*SMB*" }).Count -gt 0
        telnet_enabled = ($features | Where-Object { $_.FeatureName -like "*Telnet*" }).Count -gt 0
        iis_enabled = ($features | Where-Object { $_.FeatureName -like "*IIS*" }).Count -gt 0
        hyperv_enabled = ($features | Where-Object { $_.FeatureName -like "*Hyper*" }).Count -gt 0
    }
    Write-Host "  ✅ 启用功能数: $($features.Count)" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  无法获取功能信息: $_" -ForegroundColor Yellow
}

# 输出结果
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 系统信息收集完成" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($ExportJson) {
    $jsonPath = Join-Path $OutputPath "system-info-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $systemInfo | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Host "✅ JSON报告已保存: $jsonPath" -ForegroundColor Green
} else {
    Write-Host ""
    $systemInfo | ConvertTo-Json -Depth 10
}

Write-Host ""
Write-Host "收集完成！" -ForegroundColor Green
