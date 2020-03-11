# vSphereVersions.ps1

### General
Gather product versions from several software products. I use this to check the results on the vmware interoperatility matrix at https://www.vmware.com/resources/compatibility/sim/interop_matrix.php<br>
Tested with: PowerShell 5.0, PowerCLI 11, vSphere 6.5

### Features / Products
- vCenter
- vCenter Plugins (without internal VMware Plugins)
- vSAN
- ESXi
- NSX-V
- vRealize Operations Manager-
- vRealize LogInsight
- vRealize Orchestrator
- VEEAM
- Citrix XenDesktop

### Requirements  
- Module slr.psm1 from my github site https://github.com/eschek87/scripts/blob/master/slr.psm1 (contains some used functions)
- Citrix Snapin


### Configure
- Fill out the variables in line 51 until 59  