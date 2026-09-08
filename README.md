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

<img width="1891" height="714" alt="firefox_6oVg1TRUxn" src="https://github.com/user-attachments/assets/81aac580-9e98-4001-9290-42a626014446" />


- Name the budget `IT-Automation-MVP` with an amount of $100 (or whatever works for you).
- Set alert thresholds at **25%**, **50%**, **75%**, and **90%** to monitor spending

<img width="1632" height="836" alt="firefox_Q4aCDKEBMA" src="https://github.com/user-attachments/assets/1a2eb4a4-d7b0-4b81-a638-31d46cce7266" />

<img width="1655" height="830" alt="firefox_Q64ms9GESg" src="https://github.com/user-attachments/assets/d66498ab-c4a6-416b-9845-98f7ad041a2a" />


Azure budgets just act as alerts, so they do not automatically prevent resource spending. The biggest spending concern will be the VM we provision.

# 2. Create a Resource Group

Go to:

```
Resource Groups
-> Create
```

<img width="1889" height="898" alt="firefox_fY7gFqDLnR" src="https://github.com/user-attachments/assets/f4f3f136-2dc7-4dc5-b624-3a5916a6aadf" />

<img width="1890" height="786" alt="firefox_RikilE2LFu" src="https://github.com/user-attachments/assets/90d74eb3-da52-4cb1-80fb-ccb2f5089f70" />

Use:

```
Resource group:
rg-itops-mvp
```

<img width="759" height="394" alt="firefox_6FpKPo2yTo" src="https://github.com/user-attachments/assets/718ffb0d-57d0-4fde-81b3-f9f8804c713d" />


Add tags if wanted:

```
Project = ITOperationsAutomation 
Environment = Lab
```
<img width="891" height="508" alt="firefox_f3YSZ6Q8u1" src="https://github.com/user-attachments/assets/93a7ad3d-f5f7-4942-b5f2-77a33d1a3bef" />

<img width="540" height="869" alt="firefox_ySVyzVy38U" src="https://github.com/user-attachments/assets/9cdd99c1-662d-472a-8510-1aa228798271" />


# 3. Create the Windows Server VM

We need to create a small Windows Server VM, we will use a Windows Server 2022 version.

Go to:

```
Virtual Machines
-> Create
-> Azure Virtual Machine
```

<img width="569" height="801" alt="firefox_U6Jascf9OB" src="https://github.com/user-attachments/assets/bddd57be-796c-4804-a60e-f398d80b45a8" />


**Name:**
Name it `vm-itops-01`

<img width="970" height="862" alt="firefox_PZ7vJzoKJz" src="https://github.com/user-attachments/assets/bfff34f9-c244-4b6f-bd58-21e05cd6c3fe" />



**Image:**
For the image I chose `[smalldisk] Windows Server 2022 Datacenter: Azure Edition Core -x64 Gen 2`
This ensures smaller resource pull and Core allows us only a cli.

<img width="1454" height="831" alt="firefox_LwxzPjKlR7" src="https://github.com/user-attachments/assets/d6ed069a-eb58-472f-a554-090be83a1e35" />


**Size:**
Small B-series like Standard_B1s is ideal,  ended up using a D-series since I chose US East 2 as my region.

No GUI is needed for this VM since we will only be using it to run PowerShell and monitor CPU usage.

<img width="806" height="341" alt="firefox_F3sOT1XLIg" src="https://github.com/user-attachments/assets/c0ba84bd-7f87-436b-bd82-e5e927932008" />

<img width="1515" height="786" alt="firefox_5fnG9VpAc5" src="https://github.com/user-attachments/assets/ffe2bad8-5c27-492f-9655-2cacaef8d5b7" />


# 4. Secure RDP

- Navigate to the VM's Network Security Group
- Edit inbound security rules to restrict TCP port 3389 from `Any / Internet` and ensure it allows only to `My IP Address`

<img width="1016" height="692" alt="firefox_H7nkknMNhg" src="https://github.com/user-attachments/assets/d02429c7-fcbe-4152-9099-5c144ea18c6a" />


# 5. Configure Auto Shutdown

On `vm-itops-01` navigate to:

```
Operations
-> Auto-shutdown
```

Set the time to when you want it to auto shutdown in your local timezone. 

<img width="826" height="244" alt="firefox_UFXJZwO2ed" src="https://github.com/user-attachments/assets/d9edbee6-d0ac-4b0f-bd51-62021b2b019c" />


*Auto shutdown is useful, but always be sure to manually click STOP (Deallocate) on the VM when done working to save money.*

# 6. Connect via RDP and Establish Baseline

- RDP into `vm-itops-01`
- Open Powershell and verify baseline commands:

<img width="1920" height="1080" alt="mstsc_irKFASFxa8" src="https://github.com/user-attachments/assets/78d81016-e779-426f-8707-627221d67454" />

<img width="1920" height="1080" alt="mstsc_HidueOkqNA" src="https://github.com/user-attachments/assets/a9b54498-31a8-42d4-9442-472b180a42ba" />


```
hostname
```

<img width="1920" height="1080" alt="mstsc_Jld6guOU44" src="https://github.com/user-attachments/assets/458f8542-f57f-477a-8749-1cb1226a34a5" />


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

<img width="1295" height="656" alt="mstsc_rMlIDTWpe4" src="https://github.com/user-attachments/assets/e0cc7391-f585-4646-bb4f-66104382168c" />


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

<img width="1295" height="656" alt="mstsc_qT1c5HATQV" src="https://github.com/user-attachments/assets/176c4f22-cd78-4d96-8c8a-65ee55992b34" />


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

<img width="1295" height="656" alt="mstsc_A4ltA1ZuHD" src="https://github.com/user-attachments/assets/c05e8096-38a7-46a0-9d9a-b4b214b9be56" />


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

<img width="1295" height="656" alt="mstsc_kKVzNqfAru" src="https://github.com/user-attachments/assets/e168bada-2917-4537-9093-d15853fb2d3b" />


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

<img width="1301" height="714" alt="mstsc_D7cCu5xu5v" src="https://github.com/user-attachments/assets/cc3a292f-c616-4966-8156-bfb362871960" />


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

<img width="720" height="299" alt="mstsc_jod4LBThUw" src="https://github.com/user-attachments/assets/66fee157-d77b-45ed-b058-7738bc9fc2d5" />


# 10. Create Log Analytics Workspace

- Navigate to Log Analytics in the Azure Portal

In the top search bar of the Azure Portal, type **Log Analytics workspaces** and select it from the list.

<img width="1694" height="889" alt="firefox_hb9LGWno1N" src="https://github.com/user-attachments/assets/a00f2fae-ba86-4954-9ca2-4313910996b4" />


- Configure basic settings

Click **+ Create** (or **+ New**). Select **rg-itops-mvp** as the Resource Group. Enter **`law-itops-mvp`** in the **Name** field, and pick your local region (e.g., _East US_ or _West US_).

<img width="849" height="876" alt="ceZWc13S4J" src="https://github.com/user-attachments/assets/bce0f92c-8efd-4320-91ba-922ac6884d7b" />

- Review and create

Click **Review + Create**, wait for validation to pass, then click **Create**.

Once it is deployed, click **Go to resource** and confirm the top summary bar displays as operational.

# 11. Enable VM Monitoring

- Go to your Virtual Machine (**vm-itops-01**). Under the left-hand menu, scroll to the **Monitoring** section and select **Insights**.
- Click the **Enable** button. Ensure the configuration installs the **Azure Monitor Agent (AMA)** and sets the destination workspace to **`law-itops-mvp`**.
- Accept the default Data Collection Rule (DCR) prompt created by the wizard and click **Configure**

<img width="1429" height="866" alt="firefox_rZ1ln103Rp" src="https://github.com/user-attachments/assets/08af98c8-5a18-427f-80d8-6dfc0e43e372" />


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

<img width="1893" height="841" alt="firefox_7qHWETCWEp" src="https://github.com/user-attachments/assets/4f3f29aa-f4b3-4030-9e1f-606660065aff" />


- Click the blue **RUN** button

You should see the VM. The Heartbeat table should receive a record roughly every minute when the agent is communicating correctly.

<img width="1561" height="811" alt="firefox_W5NacudvsS" src="https://github.com/user-attachments/assets/9b78566c-324d-415d-b0bd-809c573e47cf" />


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

<img width="1896" height="864" alt="firefox_jr6GNGctug" src="https://github.com/user-attachments/assets/53b3ba30-d956-47d1-9f96-32fe48f4b4bb" />


- Set Resource Group to **`rg-itops-mvp`**, set Name to **`aa-itops-mvp`**, and choose your matching Azure Region.

<img width="1890" height="817" alt="firefox_pHK6cM4RK6" src="https://github.com/user-attachments/assets/02ab4d49-d91e-48f3-8d8c-fc1b7a17053a" />


- On the **Advanced** tab, ensure **System-assigned identity** is checked (**On**). Click **Review + Create**, then **Create**.

<img width="1821" height="295" alt="firefox_jBWreREVr6" src="https://github.com/user-attachments/assets/93708d6d-2144-4a42-ad4b-f36a484dbf60" />


You can verify by navigating to `aa-itops-mvp` -> **Identity** (under Account Settings) and verify that the **Status** tab under _System assigned_ displays **On** with an assigned Object ID.

Azure Automation supports managed identities for runbooks so the runbook can authenticate to Azure resources without storing credentials.

# 15. Assign the Automation Account a role

For the MVP, give the Automation Account's managed identity a narrowly scoped role on your resource group rather than making it subscription Owner.

For example, if the runbook needs to interact with your VM's Azure resources, assign only an appropriate role required for that operation.

- Go to your Resource Group **`rg-itops-mvp`**.
- Click **Access control (IAM)** in the left menu.
- Click **+ Add** -> **Add role assignment**.
- Select the **Contributor** role (or _Virtual Machine Contributor_) and click **Next**.

<img width="1843" height="560" alt="firefox_IVrkp8f7zh" src="https://github.com/user-attachments/assets/c73b3dcc-5fa0-4e14-bbe4-7aa4484bc4ab" />


- Select **Managed identity** under _Assign access to_.
- Click **+ Select members**, set _Managed identity_ to **Automation Account**, pick **`aa-itops-mvp`**, and click **Select**.
- Click **Review + assign**.

<img width="1903" height="865" alt="firefox_9BwtucEQjL" src="https://github.com/user-attachments/assets/6afeddf6-99d3-440a-95d1-e8329cd3566d" />


Click **Role assignments** inside IAM, search for `aa-itops-mvp`, and verify it appears with the assigned role scoped to `rg-itops-mvp`.

# 16. Create a runbook

- Inside **aa-itops-mvp**, select **Runbooks** under _Process Automation_, then click **+ Create a runbook**

<img width="1562" height="823" alt="firefox_bW2C0AyJIS" src="https://github.com/user-attachments/assets/ba219ee9-bc81-4dff-ad61-e0d4d7f06cae" />


- Set Name to **`ServiceRecovery`**, Runbook type to **PowerShell**, and Runtime version to **7.2** (or 5.1). Click **Create**.

<img width="920" height="606" alt="firefox_ub7cPBihFZ" src="https://github.com/user-attachments/assets/ee1b0425-3fc8-49bb-beed-c5736ad4b0a5" />

  
- In the editor screen, put the following:

```ps1
Disable-AzContextAutosave -Scope Process
$Context = (Connect-AzAccount -Identity).Context
$Context = Set-AzContext -SubscriptionName $Context.Subscription -DefaultProfile $Context

Write-Output "Authenticated successfully via Managed Identity."
Get-AzResourceGroup -Name "rg-itops-mvp" -DefaultProfile $Context
```

<img width="1911" height="718" alt="firefox_u79AArZeHZ" src="https://github.com/user-attachments/assets/33213cff-eab8-4d9c-8b22-37bd8d3d8a59" />


Click **Test pane**, then click **Start**. Wait for the output pane to show `Authenticated successfully...`. Click **X** to close the test pane, then click **Publish** -> **Yes**.

<img width="1717" height="757" alt="firefox_R61VR9xLt6" src="https://github.com/user-attachments/assets/a8cfe9fc-d5a6-44a4-aa46-1a92742ea7b5" />


Select the published runbook, click **Start**, navigate to **Jobs**, and confirm the status transitions to **Completed**.

<img width="1424" height="455" alt="firefox_pKRaVuV4j9" src="https://github.com/user-attachments/assets/e99cc6db-8106-47b9-9e7b-1846856300b3" />


# 17. Create an Azure Monitor Alert and Action Group

Start Alert Rule Creation: vm-itops-01.
1. In the Azure Portal, navigate to **Virtual machines** $\rightarrow$ **`vm-itops-01`**.
2. Under **Monitoring** on the left menu, select **Alerts**.
3. Click **+ Create** at the top and select **Alert rule**.

<img width="1265" height="687" alt="firefox_EABirQJ0Bl" src="https://github.com/user-attachments/assets/26947d67-4d16-4653-96e7-86907b542600" />


Set Low Threshold Condition:Condition Tab.

1. On the **Condition** tab, click **Select a signal** (or click the existing signal if pre-populated).
2. Search for and select **Percentage CPU**.
3. Configure the signal logic:
    - **Threshold:** `Static`
    - **Operator:** `Greater than`
    - **Aggregation type:** `Average`
    - **Threshold value:** `5` _(Set to 5% so normal activity triggers it easily during testing)_
    - **Unit:** `Percent`

<img width="1650" height="786" alt="firefox_4L9Rvv2yzZ" src="https://github.com/user-attachments/assets/6ed8f634-3126-433d-974b-1b76ded1da1a" />

      
4. Scroll down to **Evaluation granularity**:
    
    - **Aggregation granularity (Period):** `1 minute`
    - **Frequency of evaluation:** `1 minute`
5. Click **Next: Actions**.

Create the Action Group (ag-itops-mvp): Actions Tab.

1. On the **Actions** tab, click **+ Create action group**.

<img width="1748" height="655" alt="firefox_TeyqZKGP8l" src="https://github.com/user-attachments/assets/5d79c97f-9cd5-4a9d-8fe0-d254f2cb09c7" />


3. In the **Basics** tab of the wizard:
    - **Resource group:** `rg-itops-mvp`
    - **Action group name:** `ag-itops-mvp`
    - **Display name:** `AgItOps`
4. Click **Next: Notifications**.
5. Configure the notification details:
    - **Notification type:** Select **Email/SMS message/Push/Voice**.
    - **Name:** `AdminEmail`
    - Check the **Email** box, enter your personal email address, and click **OK**.
6. Click **Review + create**, then click **Create**.

Finalize and Save the Alert Rule: Details Tab.

1. Back in the Alert Rule creation flow, confirm **`ag-itops-mvp`** is now selected under _Actions_.
2. Click **Next: Details**.
3. Configure rule details:
    - **Severity:** `2 - Warning` (or `3 - Informational`)
    - **Alert rule name:** `Alert-HighCPU-MVP`
    - **Advanced options:** Leave _Automatically resolve alerts_ checked.
4. Click **Review + create**, then click **Create**.

<img width="1217" height="570" alt="firefox_gTTQE9l8US" src="https://github.com/user-attachments/assets/56250d8e-029c-474f-a281-117bdca25dd8" />


Now in the VM console run this command which loops to generate a mild CPU spike and trip the threshold:

```ps1
while ($true) { $i++ }
```

<img width="1301" height="714" alt="mstsc_Rkpl7dZZPp" src="https://github.com/user-attachments/assets/d7dd7cf9-b9ac-4b55-80db-bf8a5731e425" />


Let it run for a few minutes

<img width="1883" height="542" alt="firefox_RSjUqZ7Hhr" src="https://github.com/user-attachments/assets/c0893491-c470-4ca3-b17a-f1db8ee55109" />


Check your email inbox. You should receive an email from **Azure Monitor Alerts** subject line containing `Alert-HighCPU-MVP`

<img width="1053" height="884" alt="olk_QeXMJ8ZjJa" src="https://github.com/user-attachments/assets/a6bab29e-da6d-481b-81d9-df73ec4ada6e" />


# 18. Set Up Microsoft List For Incidents

- Go to [make.powerautomate.com](https://make.powerautomate.com) or [portal.office.com](https://portal.office.com) and open **Lists** (or SharePoint).

<img width="1848" height="916" alt="l7q310zTlK" src="https://github.com/user-attachments/assets/daf1ff34-88d9-40b1-9d52-66324bcdfec9" />


Click **+ New list** $\rightarrow$ **Blank list**.
- **Name:** `IT Operations Incidents`
- Click **Create**.

<img width="1859" height="762" alt="firefox_baIvm7H9Ne" src="https://github.com/user-attachments/assets/61109512-1854-4ce2-b030-18d9b27683df" />

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

<img width="1487" height="684" alt="firefox_J9yMZM7Zch" src="https://github.com/user-attachments/assets/fe31ade5-3d06-4f5f-9e84-b7a3080632b2" />


- On the left menu, click **+ Create** $\rightarrow$ **Automated cloud flow**.
- **Flow name:** `IT Operations Incident Flow`
- **Trigger:** Search for `When a new email arrives (V3)` (Office 365 Outlook) and select it.
- Click **Create**.

<img width="897" height="574" alt="firefox_WizR7CeSUl" src="https://github.com/user-attachments/assets/448a8fc3-c444-434e-bd9c-b0a6d7e07d62" />


Now we need an email trigger:

- Search for trigger **When a new email arrives (V3)**. Add a Subject Filter for **`Azure Monitor Alert`** to avoid triggering on unrelated emails.

<img width="1906" height="848" alt="firefox_GwOUkoaraI" src="https://github.com/user-attachments/assets/296a5b73-64d0-4de9-b8ba-3286413ad0b9" />


- Add action **Create item (SharePoint / Microsoft Lists)**. Point to your site address and select list **`IT Operations Incidents`**.

Map the list fields as follows:

- **Incident ID:** `INC-001` (or dynamic string expression)
- **Date:** Expression `utcNow()`
- **Server:** `vm-itops-01`
- **Alert:** Email Subject line
- **Severity:** `High`
- **Status:** `Open`


<img width="674" height="674" alt="firefox_GNuzmZOL0t" src="https://github.com/user-attachments/assets/433978a3-86cb-48fb-b782-87263b1b70be" />



Now a notification step:

Add a final action: **Send an email notification (V2)**. Set recipient to your email address with body text stating: _"Incident created in tracking list for review."_ Click **Save**.


<img width="775" height="551" alt="firefox_vUAUDCkUW5" src="https://github.com/user-attachments/assets/8dd4de6d-1159-49d5-b9df-7023ec7f5a19" />

<img width="1486" height="647" alt="firefox_Tw7MdPeSpq" src="https://github.com/user-attachments/assets/3ac90247-d52f-423f-a58c-0eb242f7df4c" />


To verify it is working, trigger an Azure Monitor alert, wait for the email, and verify that a new record automatically appears in your _IT Operations Incidents_ list.

<img width="788" height="364" alt="olk_bzJiM7NMWx" src="https://github.com/user-attachments/assets/0df7e35a-4b67-494a-83be-49924be50e20" />

<img width="1849" height="738" alt="firefox_PllezW9oIo" src="https://github.com/user-attachments/assets/9b92a2da-9197-48fa-b4f4-47f414ba1056" />



