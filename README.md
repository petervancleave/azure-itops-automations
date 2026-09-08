# Azure IT Operations Automation Platform

---


This is a guide and walkthrough of how to build an Azure-based IT operations lab with infrastructure monitoring, PowerShell automation, incident management, and workflow automation.

This guide details the end to end deployment of a working and demonstrable Azure IT operations automation MVP. Included is all configuration steps, script definitions, and troubleshooting corrections encountered during the lab build.

*As of now, this repository hosts an MVP version of the project showing the entire workflow that can be expanded upon further. Further expansion is still a work in progress.*

# 0. Introduction and Project Overview

## Problem

IT administrators regularly respond to repetitive infrastructure issues such as service failures, resource utilization alerts, and system health problems. This project demonstrates how Azure monitoring and automation can reduce manual intervention for known, low-risk incidents.

## Architecture

<img width="1168" height="784" alt="n0xFB" src="https://github.com/user-attachments/assets/3154cf10-312b-445c-8651-d58b02e3f17f" />


---
In words: 

Azure detects an IT problem → Power Automate creates and manages the incident → PowerShell investigates/remediates it → Azure Monitor/Log Analytics provides evidence → Power Automate notifies the administrator and records the result.

## Technologies

- Microsoft Azure
- Azure Virtual Machines
- Azure Monitor
- Log Analytics
- Azure Automation
- PowerShell
- Power Automate
- Microsoft Lists
- Sharepoint
- Outlook
- Azure RBAC
- Managed Identity
- KQL

## Incident Demonstration

A Windows service failure is intentionally simulated.

The system does the following:

1. Detect the issue
2. Investigate the service
3. Execute PowerShell remediation script
4. Verifies the service state
5. Records the incident
6. Notifies the admin

## Security

The Automation Account uses Managed Identity rather than stored Azure credentials.

RBAC is used to restrict automation permissions.

## Cost Control

(Use some of these techniques to keep costs low when experimenting)

- Small VM Size
- Automatic shutdown
- Manual deallocation when not in use
- Azure budget alerts
- Limited monitoring data collection

# 1. Set your Azure Budget 

In the Azure Portal, navigate to:

```
Cost Management
-> Budgets
-> Add
```

- Name the budget `IT-Automation-MVP` with an amount of $100 (or whatever works for you).
- Set alert thresholds at **25%**, **50%**, **75%**, and **90%** to monitor spending

Azure budgets just act as alerts, so they do not automatically prevent resource spending. The biggest spending concern will be the VM we provision.

# 2. Create a Resource Group

Go to:

```
Resource Groups
-> Create
```

Use:

```
Resource group:
rg-itops-mvp
```

Add tags if wanted:

```
Project = ITOperationsAutomation 
Environment = Lab
```

# 3. Create the Windows Server VM

We need to create a small Windows Server VM, we will use a Windows Server 2022 version.

Go to:

```
Virtual Machines
-> Create
-> Azure Virtual Machine
```

**Name:**
Name it `vm-itops-01`

**Image:**
For the image I chose `[smalldisk] Windows Server 2022 Datacenter: Azure Edition Core -x64 Gen 2`
This ensures smaller resource pull and Core allows us only a cli.

**Size:**
Small B-series like Standard_B1s is ideal,  ended up using a D-series since I chose US East 2 as my region.

No GUI is needed for this VM since we will only be using it to run PowerShell and monitor CPU usage.

# 4. Secure RDP

- Navigate to the VM's Network Security Group
- Edit inbound security rules to restrict TCP port 3389 from `Any / Internet` and ensure it allows only to `My IP Address`

# 5. Configure Auto Shutdown

On `vm-itops-01` navigate to:

```
Operations
-> Auto-shutdown
```

Set the time to when you want it to auto shutdown in your local timezone. 

*Auto shutdown is useful, but always be sure to manually click STOP (Deallocate) on the VM when done working to save money.*

# 6. Connect via RDP and Establish Baseline

- RDP into `vm-itops-01`
- Open Powershell and verify baseline commands:

```
hostname
```

then:

```
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion
```

then:

```
Get-Volume
```

then:

```
Get-Service | Select-Object -First 20
```

# 7. Create the first Powershell Script

Inside the console, create the first script. 

Currently, you should see this in the console:

```ps1
PS C:\Users\Administrator>
```

We need to first create the folders for the project:

```ps1
New-Item -ItemType Directory -Path C:\ITOps -Force
New-Item -ItemType Directory -Path C:\ITOps\powershell -Force
```

Verify:

```ps1
Get-ChildItem C:\ITOps
```

You should see:

```
powershell
```

Because we are using the Core version of the VM, we don't have a graphical way available to create the file. This means we must create the file directly from PowerShell. Run:

```ps1
New-Item -ItemType File -Path C:\ITOps\powershell\Get-ServerHealth.ps1 -Force
```

Check it exists:

```ps1
Get-ChildItem C:\ITOps\powershell
```

The returns should read:

```ps1
Get-ServerHealth.ps1
```

Then write the script to the file. Copy and paste the following script directly into the console:

```ps1
@'
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
'@ | Set-Content C:\ITOps\powershell\Get-ServerHealth.ps1
```

Check it exists:

```ps1
Get-Content C:\ITOps\powershell\Get-ServerHealth.ps1
```

The script should print directly back.

Before the script can be run, we must check the execution policy on it. 

Run:

```ps1
Get-ExecutionPolicy -List
```

Microsoft documents `Get-ExecutionPolicy -List` as the way to see all policies affecting the current PowerShell session.

On Windows Server, `RemoteSigned` is normally the appropriate policy for locally created scripts.

For our lab, check the result first. If the effective policy is `Restricted`, the run:

```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

You might have to follow up by hitting `Y` to accept. I did not get prompted.

Verify:

```ps1
Get-ExecutionPolicy
```

You should see `RemoteSigned`

Now we need to execute the script. 

Run:

```ps1
C:\ITOps\powershell\Get-ServerHealth.ps1
```

Or, you can use this command directly since we are in a different directory:

```ps1
& C:\ITOps\powershell\Get-ServerHealth.ps1
```

The output should look something like this:
```ps1
ComputerName   : VM-ITOPS-01
UptimeDays     : 0.42
MemoryGB       : 7.91
FreeMemoryGB   : 5.23
Disks          : {@{Drive=C:; SizeGB=127.99; FreeGB=98.42; UsedPercent=23.1}}
```

The numbers will be different.

You can format PowerShell output into an easier to read table if you wish with the following:

```ps1
$result | Format-List
$result.Disks | Format-Table
```

# 9. Create the remediation script

Now we will repeat the steps above but this time with the remediation script:

```
param(
    [Parameter(Mandatory)]
    [string]$ServiceName
)
try {
    $Service = Get-Service -Name $ServiceName -ErrorAction Stop
    $Before = $Service.Status

    if ($Before -ne "Running") {
        Start-Service -Name $ServiceName -ErrorAction Stop
        Start-Sleep -Seconds 3
        $Service.Refresh()
    }

    $After = $Service.Status

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Service      = $ServiceName
        Before       = $Before
        After        = $After
        Result       = if ($After -eq "Running") { "SUCCESS" } else { "FAILED" }
        Timestamp    = Get-Date
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
```

Pick a standard service. You can see some available with the following command:

```ps1
Get-Service | Where-Object { $_.Status -eq "Running" } | Select-Object -First 10 Name, DisplayName
```

Choose a service from the list and verify it is running:

```ps1
Get-Service -Name <ServiceName>
```

Make sure you are able to stop the service, then stop the service:

```ps1
Stop-Service -Name <ServiceName> -Force
Get-Service -Name <ServiceName>
```

The `Status` column should show as `Stopped`

I chose to use the DeviceInstall service.

Next, run the remediation script:

```ps1
.\Restart-Service.ps1 -ServiceName <ServiceName>
```

You should see an output like:

```
ComputerName : vm-itops-01
Service      : <ServiceName>
Before       : Stopped
After        : Running
Result       : SUCCESS
Timestamp    : 5/5/2025 8:40:00 AM
```

# 10. Create Log Analytics Workspace

- Navigate to Log Analytics in the Azure Portal

In the top search bar of the Azure Portal, type **Log Analytics workspaces** and select it from the list.

- Configure basic settings

Click **+ Create** (or **+ New**). Select **rg-itops-mvp** as the Resource Group. Enter **`law-itops-mvp`** in the **Name** field, and pick your local region (e.g., _East US_ or _West US_).

- Review and create

Click **Review + Create**, wait for validation to pass, then click **Create**.

Once it is deployed, click **Go to resource** and confirm the top summary bar displays as operational.

# 11. Enable VM Monitoring

- Go to your Virtual Machine (**vm-itops-01**). Under the left-hand menu, scroll to the **Monitoring** section and select **Insights**.
- Click the **Enable** button. Ensure the configuration installs the **Azure Monitor Agent (AMA)** and sets the destination workspace to **`law-itops-mvp`**.
- Accept the default Data Collection Rule (DCR) prompt created by the wizard and click **Configure**

*Wait 5-10 minutes for extension provisioning. Keep refreshing the page as needed until the insights performance charts begin populating.*

# 12. Verify Telemetry

- Open your **Log Analytics Workspace** (`law-itops-mvp`).
- On the left blade, click **Logs**. Close any welcome pop-up modals.
- Paste the following KQL snippet into the query editor window:

```kusto
Heartbeat
| order by TimeGenerated desc
| take 20
```

- Click the blue **RUN** button

You should see the VM. The Heartbeat table should receive a record roughly every minute when the agent is communicating correctly.

# 13. Save KQL Queries

Save the following health monitoring queries into the file:

```kusto
// Query 1: Verify Host Connectivity
Heartbeat
| summarize LastSeen = max(TimeGenerated) by Computer
| order by LastSeen desc

// Query 2: CPU Utilization Trend
Perf
| where CounterName == "% Processor Time"
| summarize AverageCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

Execute Query 2 in the Azure Log Analytics portal to ensure CPU metrics are recording properly.

# 14. Create Azure Automation

- In the portal search bar, search for **Automation Accounts** and click **+ Create**.
- Set Resource Group to **`rg-itops-mvp`**, set Name to **`aa-itops-mvp`**, and choose your matching Azure Region.
- On the **Advanced** tab, ensure **System-assigned identity** is checked (**On**). Click **Review + Create**, then **Create**.

You can verify by navigating to `aa-itops-mvp` -> **Identity** (under Account Settings) and verify that the **Status** tab under _System assigned_ displays **On** with an assigned Object ID.

Azure Automation supports managed identities for runbooks so the runbook can authenticate to Azure resources without storing credentials.

# 15. Assign the Automation Account a role

For the MVP, give the Automation Account's managed identity a narrowly scoped role on your resource group rather than making it subscription Owner.

For example, if the runbook needs to interact with your VM's Azure resources, assign only an appropriate role required for that operation.

- Go to your Resource Group **`rg-itops-mvp`**.
- Click **Access control (IAM)** in the left menu.
- Click **+ Add** -> **Add role assignment**.
- Select the **Contributor** role (or _Virtual Machine Contributor_) and click **Next**.
- Select **Managed identity** under _Assign access to_.
- Click **+ Select members**, set _Managed identity_ to **Automation Account**, pick **`aa-itops-mvp`**, and click **Select**.
- Click **Review + assign**.

Click **Role assignments** inside IAM, search for `aa-itops-mvp`, and verify it appears with the assigned role scoped to `rg-itops-mvp`.

# 16. Create a runbook

- Inside **aa-itops-mvp**, select **Runbooks** under _Process Automation_, then click **+ Create a runbook**
- Set Name to **`ServiceRecovery`**, Runbook type to **PowerShell**, and Runtime version to **7.2** (or 5.1). Click **Create**.
- In the editor screen, put the following:

```ps1
Disable-AzContextAutosave -Scope Process
$Context = (Connect-AzAccount -Identity).Context
$Context = Set-AzContext -SubscriptionName $Context.Subscription -DefaultProfile $Context

Write-Output "Authenticated successfully via Managed Identity."
Get-AzResourceGroup -Name "rg-itops-mvp" -DefaultProfile $Context
```

Click **Test pane**, then click **Start**. Wait for the output pane to show `Authenticated successfully...`. Click **X** to close the test pane, then click **Publish** -> **Yes**.

Select the published runbook, click **Start**, navigate to **Jobs**, and confirm the status transitions to **Completed**.

# 17. Create an Azure Monitor Alert and Action Group


Start Alert Rule Creation: vm-itops-01.
1. In the Azure Portal, navigate to **Virtual machines** $\rightarrow$ **`vm-itops-01`**.
2. Under **Monitoring** on the left menu, select **Alerts**.
3. Click **+ Create** at the top and select **Alert rule**.

Set Low Threshold Condition:Condition Tab.

1. On the **Condition** tab, click **Select a signal** (or click the existing signal if pre-populated).
2. Search for and select **Percentage CPU**.
3. Configure the signal logic:
    - **Threshold:** `Static`
    - **Operator:** `Greater than`
    - **Aggregation type:** `Average`
    - **Threshold value:** `5` _(Set to 5% so normal activity triggers it easily during testing)_
    - **Unit:** `Percent`
4. Scroll down to **Evaluation granularity**:
    
    - **Aggregation granularity (Period):** `1 minute`
    - **Frequency of evaluation:** `1 minute`
5. Click **Next: Actions**.

Create the Action Group (ag-itops-mvp): Actions Tab.

1. On the **Actions** tab, click **+ Create action group**.
2. In the **Basics** tab of the wizard:
    - **Resource group:** `rg-itops-mvp`
    - **Action group name:** `ag-itops-mvp`
    - **Display name:** `AgItOps`
3. Click **Next: Notifications**.
4. Configure the notification details:
    - **Notification type:** Select **Email/SMS message/Push/Voice**.
    - **Name:** `AdminEmail`
    - Check the **Email** box, enter your personal email address, and click **OK**.
5. Click **Review + create**, then click **Create**.

Finalize and Save the Alert Rule: Details Tab.

1. Back in the Alert Rule creation flow, confirm **`ag-itops-mvp`** is now selected under _Actions_.
2. Click **Next: Details**.
3. Configure rule details:
    - **Severity:** `2 - Warning` (or `3 - Informational`)
    - **Alert rule name:** `Alert-HighCPU-MVP`
    - **Advanced options:** Leave _Automatically resolve alerts_ checked.
4. Click **Review + create**, then click **Create**.

Now in the VM console run this command which loops to generate a mild CPU spike and trip the threshold:

```ps1
while ($true) { $i++ }
```

Let it run for a few minutes

Check your email inbox. You should receive an email from **Azure Monitor Alerts** subject line containing `Alert-HighCPU-MVP`
# 18. Set Up Microsoft List For Incidents

- Go to [make.powerautomate.com](https://make.powerautomate.com) or [portal.office.com](https://portal.office.com) and open **Lists** (or SharePoint).

Click **+ New list** $\rightarrow$ **Blank list**.
- **Name:** `IT Operations Incidents`
- Click **Create**.

- Add columns to match schema like so:

|Column Name|Type|Settings / Notes|
|---|---|---|
|**Title**|_(Default)_|Will store `INC-001`, `INC-002`, etc.|
|**Date**|**Date and time**|Include time: **Yes**|
|**Server**|**Single line of text**|Stores server hostname (e.g. `vm-itops-01`)|
|**Alert**|**Single line of text**|Alert subject or metric name|
|**Severity**|**Choice**|Choices: `High`, `Medium`, `Low`|
|**Description**|**Multiple lines of text**|Alert details / raw text|
|**Action**|**Single line of text**|Action taken (e.g. `Restart-Service.ps1`)|
|**Status**|**Choice**|Choices: `Open`, `In Progress`, `Resolved`|
|**Resolution**|**Multiple lines of text**|Resolution summary|

# 19. Build Power Automate Flow

- Navigate to [make.powerautomate.com](https://make.powerautomate.com).
- On the left menu, click **+ Create** $\rightarrow$ **Automated cloud flow**.
- **Flow name:** `IT Operations Incident Flow`
- **Trigger:** Search for `When a new email arrives (V3)` (Office 365 Outlook) and select it.
- Click **Create**.

Now we need an email trigger:

- Search for trigger **When a new email arrives (V3)**. Add a Subject Filter for **`Azure Monitor Alert`** to avoid triggering on unrelated emails.
- Add action **Create item (SharePoint / Microsoft Lists)**. Point to your site address and select list **`IT Operations Incidents`**.

Map the list fields as follows:

- **Incident ID:** `INC-001` (or dynamic string expression)
- **Date:** Expression `utcNow()`
- **Server:** `vm-itops-01`
- **Alert:** Email Subject line
- **Severity:** `High`
- **Status:** `Open`

Now a notification step:

Add a final action: **Send an email notification (V3)**. Set recipient to your email address with body text stating: _"Incident created in tracking list for review."_ Click **Save**.

To verify it is working, trigger an Azure Monitor alert, wait for the email, and verify that a new record automatically appears in your _IT Operations Incidents_ list.



