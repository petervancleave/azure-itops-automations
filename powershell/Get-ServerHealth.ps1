$ComputerName = $env:COMPUTERNAME

$OS = Get-CimInstance Win32_OperatingSystem

$Uptime = (Get-Date) - $OS.LastBootUpTime

$MemoryGB = [math]::Round(
    $OS.TotalVisibleMemorySize / 1MB,
    2
)

$FreeMemoryGB = [math]::Round(
    $OS.FreePhysicalMemory / 1MB,
    2
)

$Disks = Get-CimInstance Win32_LogicalDisk `
    -Filter "DriveType=3"

$DiskResults = foreach ($Disk in $Disks) {

    $Used = $Disk.Size - $Disk.FreeSpace

    [PSCustomObject]@{
        Drive = $Disk.DeviceID
        SizeGB = [math]::Round($Disk.Size / 1GB, 2)
        FreeGB = [math]::Round($Disk.FreeSpace / 1GB, 2)
        UsedPercent = [math]::Round(
            ($Used / $Disk.Size) * 100,
            2
        )
    }
}

[PSCustomObject]@{
    ComputerName = $ComputerName
    UptimeDays = [math]::Round($Uptime.TotalDays, 2)
    MemoryGB = $MemoryGB
    FreeMemoryGB = $FreeMemoryGB
    Disks = $DiskResults
}
