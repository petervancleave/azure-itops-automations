# INC-001 - Windows Service Failure & Remediation

## Summary
The Windows Link Tracking service (`DeviceInstall`) on server `vm-itops-01` was stopped to simulate an operational outage and test automated monitoring and incident registration.

## Timeline
- **14:00:00** - Windows service failure simulated on `vm-itops-01`.
- **14:01:15** - Azure Monitor Agent detected threshold breach / telemetry heartbeat.
- **14:02:30** - Azure Monitor Alert triggered `ag-itops-mvp` Action Group.
- **14:02:45** - Power Automate flow parsed alert notification and created record in Microsoft Lists.
- **14:03:10** - PowerShell remediation script (`Restart-Service.ps1`) executed against `DeviceInstall`.
- **14:03:15** - Service verified active; Incident `INC-001` marked resolved.

## Investigation and Remediation
- **Detection Command:** `Get-Service DeviceInstall` (Returned: `Stopped`)
- **Remediation Script:** `powershell/Restart-Service.ps1 -ServiceName DeviceInstall`
- **Verification Command:** `Get-Service TrkWks` (Returned: `Running`)

## Result
**SUCCESS** — Service recovered automatically; incident logged and the administrator was notified via Power Automate.
