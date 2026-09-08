Disable-AzContextAutosave -Scope Process

$Context = (Connect-AzAccount -Identity).Context

$Context = Set-AzContext `
    -SubscriptionName $Context.Subscription `
    -DefaultProfile $Context

Write-Output "Authenticated successfully."

Get-AzResourceGroup `
    -Name "rg-itops-mvp" `
    -DefaultProfile $Context
