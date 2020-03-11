# vDiskMapping.ps1

### General
Collects information for virtual machine(s) hard disk(s), and for windows vm's map hard disk to windows disk volume name.<br>
Tested with: PowerShell 5.0, PowerCLI 11, vSphere 6.5

### Features
- VM Name
- Controller
- Disk Name
- Storage Format
- Size
- Datastore Path
- UUID

### Requirements  
- Module slr.psm1 from my github site https://github.com/eschek87/scripts/blob/master/slr.psm1 (contains some used functions)


### Configure
- Line 54: Enter your vCenter fqdn

<img src="https://github.com/eschek87/scripts/blob/master/vmware/vDiskMapping/screenshots/vDiskMapping.jpg" height="80%" width="80%"/>