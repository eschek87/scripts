# vESXiNetwork.ps1

### General
Generates a csv with vDS and vmkernel networking data from all esxi host that are in a cluster.<br>
Tested with: PowerShell 5.0, PowerCLI 11, vSphere 6.5

### Features
- Hostname
- VMNic Name
- Portgroup Name
- VMKernelInterface Name
- VMKernelIP
- MTU
- Mac
- ActiveUplink
- StandbyUplink
- SwitchName
- SwitchPort
  
### Requirements  
- Module slr.psm1 from my github site https://github.com/eschek87/scripts/blob/master/slr.psm1 (contains some used functions)


### Configure
- Line 71: Enter your vCenter fqdn