try {
    [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
} catch {}

[System.GC]::Collect()

if ($PSScriptRoot) { Set-Location -Path $PSScriptRoot }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8






function Get-SystemSummary {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    







    $sw.Restart()
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osVersionRaw = $osInfo.Version
    $buildNumber = $osInfo.BuildNumber
    $versionParts = $osVersionRaw.Split('.')
    $major = $versionParts[0]
    $minor = $versionParts[1]
    $osCaption = "NT $major.$minor Build $buildNumber"
    $osArch = $osInfo.OSArchitecture
    $tOS = $sw.ElapsedMilliseconds










    $sw.Restart()
    $hostname = $env:COMPUTERNAME
    $username = $env:USERNAME
    $sysObject = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $workgroup = if ($sysObject.PartOfDomain) { $sysObject.Domain } else {$sysObject.Workgroup }
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]$identity
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    $adminText = if ($isAdmin) { "ADMIN" } else { "USUARI" }
    $tUser = $sw.ElapsedMilliseconds










    $sw.Restart()
    $psVersionShort = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    $tPS = $sw.ElapsedMilliseconds











    $sw.Restart()
    $cpu = (Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name
    $tCPU = $sw.ElapsedMilliseconds










$sw.Restart()
    $ramModules = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $ramBytes = ($ramModules | Measure-Object -Property Capacity -Sum).Sum
    $ramGB = [math]::Round($ramBytes / 1GB, 1)

    # Определяем общий тип DDR по первой планке для заголовка
    $ddrTotalType = "RAM"
    $firstModule = $ramModules | Select-Object -First 1
    if ($firstModule) {
        $rawType = if ($firstModule.SMBIOSMemoryType) { $firstModule.SMBIOSMemoryType } else { $firstModule.MemoryType }
        switch ($rawType) {
            20 { $ddrTotalType = "DDR" }
            21 { $ddrTotalType = "DDR2" }
            22 { $ddrTotalType = "DDR2 FB-DIMM" }
            24 { $ddrTotalType = "DDR3" }
            26 { $ddrTotalType = "DDR4" }
            34 { $ddrTotalType = "DDR5" }
            default {
                if ($firstModule.Speed -gt 4800) { $ddrTotalType = "DDR5" }
                elseif ($firstModule.Speed -gt 2133) { $ddrTotalType = "DDR4" }
                elseif ($firstModule.Speed -gt 800) { $ddrTotalType = "DDR3" }
            }
        }
    }

    # Детализация по каждой планке
    $ramList = @()
    foreach ($mod in $ramModules) {
        $swMod = [System.Diagnostics.Stopwatch]::StartNew()

        $modGB = [math]::Round($mod.Capacity / 1GB)
        $speed = if ($mod.Speed) { "$($mod.Speed) MHz" } else { "N/D" }
        $mfg = if ($mod.Manufacturer -and $mod.Manufacturer -notmatch "Unknown|Array") { $mod.Manufacturer.Trim() } else { "Generic" }
        $slot = if ($mod.DeviceLocator) { $mod.DeviceLocator.Trim() } else { "Slot" }

        # Индивидуальный тип для плашки
        $modType = $ddrTotalType
        $mType = if ($mod.SMBIOSMemoryType) { $mod.SMBIOSMemoryType } else { $mod.MemoryType }
        switch ($mType) {
            20 { $modType = "DDR" }
            21 { $modType = "DDR2" }
            24 { $modType = "DDR3" }
            26 { $modType = "DDR4" }
            34 { $modType = "DDR5" }
        }
        $swMod.Stop()
        $ramList += @{
            Slot    = $slot
            Details = "$modType $modGB GB $speed $mfg"
            Time    = $swMod.ElapsedMilliseconds
        }
    }
    $tRAM = $sw.ElapsedMilliseconds










    $sw.Restart()
    $gpuControllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
    $gpuList = @()

    foreach ($gpu in $gpuControllers) {
        $swGpu = [System.Diagnostics.Stopwatch]::StartNew()

        # Точный расчет VRAM с обходом 32-битного overflow WMI через реестр
        $vramMB = 0
        if ($gpu.PNPDeviceID) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($gpu.PNPDeviceID)\Device Parameters"
            if (Test-Path $regPath) {
                $regVram = (Get-ItemProperty -Path $regPath -Name "HardwareInformation.MemorySize" -ErrorAction SilentlyContinue).'HardwareInformation.MemorySize'
                if ($regVram) { $vramMB = [math]::Round($regVram / 1MB) }
            }
        }
        
        # Резервный расчет через WMI, если в реестре пусто
        if ($vramMB -eq 0 -and $gpu.AdapterRAM) {
            $vramMB = [math]::Round([uint64]$gpu.AdapterRAM / 1MB)
        }

        # Форматирование VRAM (GB или MB)
        $vramText = if ($vramMB -ge 1024) {
            "$([math]::Round($vramMB / 1024, 1)) GB"
        } elseif ($vramMB -gt 0) {
            "$vramMB MB"
        } else {
            "VRAM N/D"
        }

        $swGpu.Stop()

        $gpuList += @{
            Name = $gpu.Name
            VRAM = $vramText
            Time = $swGpu.ElapsedMilliseconds
        }
    }

    if ($gpuList.Count -eq 0) {
        $gpuList += @{ Name = "No detectada"; VRAM = ""; Time = 0 }
    }
    $tGPU = $sw.ElapsedMilliseconds




    




    $sw.Restart()
    $diskDrives = @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue | Sort-Object Index)

    # Тип носителя из Storage-модуля (ключ = номер физического диска)
    $physMap = @{}
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object { $physMap[[string]$_.DeviceId] = $_ }
    }

    $disksList = @()
    foreach ($drive in $diskDrives) {
        $swDisk = [System.Diagnostics.Stopwatch]::StartNew()

        # SSD/HDD
        $mediaType = "HDD"
        $pd = $physMap[[string]$drive.Index]
        if ($pd -and $pd.MediaType -in @("SSD", "HDD")) {
            $mediaType = [string]$pd.MediaType
        } elseif ($pd -and $pd.BusType -eq "NVMe") {
            $mediaType = "SSD"
        } elseif ($drive.Model -match "SSD|NVMe|Flash|Solid") {
            $mediaType = "SSD"
        }

        # Разделы -> тома (буквы), стиль таблицы разделов GPT/MBR, признак системного диска
        $partitionStyle = "MBR"
        $isSystem = $false
        $freeBytes = 0
        $parts = Get-CimAssociatedInstance -InputObject $drive -Association Win32_DiskDriveToDiskPartition -ErrorAction SilentlyContinue
        foreach ($part in $parts) {
            if ($part.Type -match "GPT") { $partitionStyle = "GPT" }
            $lds = Get-CimAssociatedInstance -InputObject $part -Association Win32_LogicalDiskToPartition -ErrorAction SilentlyContinue
            foreach ($ld in $lds) {
                if ($ld.DeviceID -eq $env:SystemDrive) { $isSystem = $true }
                $freeBytes += [uint64]$ld.FreeSpace
            }
        }

        $sizeGB = [math]::Round($drive.Size / 1GB)
        $freeGB = [math]::Round($freeBytes / 1GB)
        $swDisk.Stop()

        $disksList += @{
            Index    = $drive.Index
            Model    = $drive.Model
            IsSystem = $isSystem
            Details  = "[$mediaType/$partitionStyle] $freeGB/$sizeGB GB lliures"
            Time     = $swDisk.ElapsedMilliseconds
        }
    }
    $tDisks = $sw.ElapsedMilliseconds











    $sw.Restart()
    $netAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "AdapterTypeID=0 or AdapterTypeID=9" -ErrorAction SilentlyContinue
    $netList = @()

    foreach ($adapter in $netAdapters) {
        $swNet = [System.Diagnostics.Stopwatch]::StartNew()
        if ($adapter.Name -match "Virtual|VPN|TAP|VMware|VirtualBox|Loopback|Miniport|Kernel|P2P") { continue }

        $type = if ($adapter.AdapterType -match "Wireless|802.11" -or $adapter.Name -match "Wi-Fi|Wireless|802.11") { "Wi-Fi" } else { "Ethernet" }
        $netName = if ($adapter.NetConnectionID) { $adapter.NetConnectionID } else {$adapter.Name }
        $isConnected = ($adapter.NetConnectionStatus -eq 2)

        $swNet.Stop()

        $netList += @{
            Type        = $type
            Name        = $netName
            IsConnected = $isConnected
            Time        = $swNet.ElapsedMilliseconds
        }
    }

    if ($netList.Count -eq 0) {$netList += @{ Type = "XARXA"; Name = "Cap adaptador trobat"; IsConnected = $false }
    }
    $tNet = $sw.ElapsedMilliseconds
    












    return @{
        User         = $username
        Hostname     = $hostname
        Workgroup    = $workgroup
        OSCaption    = $osCaption
        OSArch       = $osArch
        PSVersion    = $psVersionShort
        Winget       = $hasWinget
        AdminText    = $adminText
        CPU          = $cpu
        RAMGB        = $ramGB
        RAMTotalType = $ddrTotalType
        RAMList      = $ramList
        GPUList      = $gpuList
        DisksList    = $disksList
        NetworkList  = $netList
        Timing       = @{
            OS    = $tOS
            PS    = $tPS
            User  = $tUser
            CPU   = $tCPU
            RAM   = $tRAM
            GPU   = $tGPU
            Disks = $tDisks
            Net   = $tNet
        }
    }
}










$sysInfo = Get-SystemSummary
$t = $sysInfo.Timing

$windowWidth = $Host.UI.RawUI.WindowSize.Width
if ($windowWidth -lt 40) {$windowWidth = 80 }
$separator = "=" * ($windowWidth - 1)

Write-Host ""
Write-Host $separator -ForegroundColor DarkCyan
Write-Host "    DIAGNÒSTIC DEL SISTEMA (DEBUG MODE)" -ForegroundColor DarkCyan
Write-Host $separator -ForegroundColor DarkCyan

Write-Host "`n    USUARI: " -NoNewline -ForegroundColor Gray
Write-Host "$($sysInfo.User) " -NoNewline -ForegroundColor White
Write-Host "[$($sysInfo.AdminText)] " -NoNewline -ForegroundColor Green
Write-Host "[$($t.User) ms]" -ForegroundColor DarkGray

Write-Host "     EQUIP: " -NoNewline -ForegroundColor Gray
Write-Host "$($sysInfo.Hostname) " -NoNewline -ForegroundColor White
Write-Host "($($sysInfo.Workgroup)) " -NoNewline -ForegroundColor DarkGray
Write-Host "[$($t.User) ms]" -ForegroundColor DarkGray

Write-Host "`n     NUCLI: " -NoNewline -ForegroundColor Gray
Write-Host "$($sysInfo.OSCaption) " -NoNewline -ForegroundColor White
Write-Host "($($sysInfo.OSArch)) " -NoNewline -ForegroundColor DarkGray
Write-Host "[$($t.OS) ms]" -ForegroundColor DarkGray

Write-Host "      PWSH: " -NoNewline -ForegroundColor Gray
Write-Host "v$($sysInfo.PSVersion) " -NoNewline -ForegroundColor White
$wingetColor = if ($sysInfo.Winget) { "Green" } else { "DarkGray" }
Write-Host "[WINGET] " -NoNewline -ForegroundColor $wingetColor
Write-Host "[$($t.PS) ms]" -ForegroundColor DarkGray

Write-Host "`n       CPU: " -NoNewline -ForegroundColor Gray
Write-Host "$($sysInfo.CPU) " -NoNewline -ForegroundColor White
Write-Host "[$($t.CPU) ms]" -ForegroundColor DarkGray







Write-Host "`n       RAM: " -NoNewline -ForegroundColor Gray
$ramColor = if ($sysInfo.RAMGB -ge 8) { "Green" } else { "White" }

Write-Host "$($sysInfo.RAMTotalType) " -NoNewline -ForegroundColor White
Write-Host "$($sysInfo.RAMGB) GB" -NoNewline -ForegroundColor $ramColor
Write-Host " TOTAL " -NoNewline -ForegroundColor White
Write-Host "[$($t.RAM) ms]" -ForegroundColor DarkGray

for ($i = 0; $i -lt $sysInfo.RAMList.Count; $i++) {
    $m = $sysInfo.RAMList[$i]
    Write-Host (" " * 12) -NoNewline
    Write-Host "[$($m.Slot)] " -NoNewline -ForegroundColor White
    Write-Host "$($m.Details) " -NoNewline -ForegroundColor DarkGray
    Write-Host "[$($m.Time) ms]" -ForegroundColor DarkGray
}








Write-Host "`n       GPU: " -NoNewline -ForegroundColor Gray
for ($i = 0; $i -lt $sysInfo.GPUList.Count; $i++) {
    $gpu = $sysInfo.GPUList[$i]
    Write-Host (" " * 12 * [int]($i -gt 0)) -NoNewline
    Write-Host "$($gpu.Name) " -NoNewline -ForegroundColor White
    if ($gpu.VRAM) {
        Write-Host "[$($gpu.VRAM)] " -NoNewline -ForegroundColor DarkGray
    }
    Write-Host "[$($gpu.Time) ms]" -ForegroundColor DarkGray
}

Write-Host "`n    DISCOS: " -NoNewline -ForegroundColor Gray
for ($i = 0; $i -lt $sysInfo.DisksList.Count; $i++) {
    $d = $sysInfo.DisksList[$i]
    Write-Host (" " * 12 * [int]($i -gt 0)) -NoNewline
    Write-Host "[$($d.Index)] $($d.Model) " -NoNewline -ForegroundColor White
    Write-Host "$($d.Details) " -NoNewline -ForegroundColor DarkGray
    if ($d.IsSystem) {
        Write-Host "[SISTEMA] " -NoNewline -ForegroundColor Green
    }
    Write-Host "[$($d.Time) ms]" -ForegroundColor DarkGray
}



Write-Host "`n     XARXA: " -NoNewline -ForegroundColor Gray
for ($i = 0; $i -lt $sysInfo.NetworkList.Count; $i++) {
    $net = $sysInfo.NetworkList[$i]
    Write-Host (" " * 12 * [int]($i -gt 0)) -NoNewline
    if ($net.IsConnected) {
        Write-Host "$($net.Name) " -NoNewline -ForegroundColor White
        Write-Host "[CONNECTAT]" -NoNewline -ForegroundColor Green
    } else {
        Write-Host "$($net.Name) " -NoNewline -ForegroundColor White
        Write-Host "[DESCONNECTAT]" -NoNewline -ForegroundColor DarkGray
    }
    Write-Host " [$($net.Time) ms]" -ForegroundColor DarkGray
}




Write-Host "`n$separator" -ForegroundColor DarkCyan
Write-Host ""