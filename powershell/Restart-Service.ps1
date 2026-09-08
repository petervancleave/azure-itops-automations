param(
    [Parameter(Mandatory)]
    [string]$ServiceName
)

try {

    $Service = Get-Service `
        -Name $ServiceName `
        -ErrorAction Stop

    $Before = $Service.Status

    if ($Before -ne "Running") {

        Start-Service `
            -Name $ServiceName `
            -ErrorAction Stop

        Start-Sleep -Seconds 3

        $Service.Refresh()
    }

    $After = $Service.Status

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Service      = $ServiceName
        Before       = $Before
        After        = $After
        Result       = if ($After -eq "Running") {
            "SUCCESS"
        }
        else {
            "FAILED"
        }
        Timestamp = Get-Date
    }
}
catch {

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Service      = $ServiceName
        Result       = "ERROR"
        Error        = $_.Exception.Message
        Timestamp    = Get-Date
    }
}
