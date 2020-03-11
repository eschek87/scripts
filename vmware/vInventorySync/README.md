# vInventorySync.ps1

### General
Gathers several inventory objects from source vcenter and creates them on destination vcenter if they not exist. I use it to have my test vcenter in sync with production.<br>
First run must be with full access rights to create roles and permissions on target vcenter. Reads inventory from source vcenter and creates them on destination vcenter if they not exist.<br>>
Tested with: PowerShell 5.0, PowerCLI 11, vSphere 6.5

### Features
The following objects are synced
- Storage policy
- Folders (datacenter level)
- Roles & Permissions (datacenter level)
- Tag Categories & Tags

### Requirements  
- Module slr.psm1 from my github site https://github.com/eschek87/scripts/blob/master/slr.psm1 (contains some used functions)

### Configure
- Fill out the variables in line 57 until 64  