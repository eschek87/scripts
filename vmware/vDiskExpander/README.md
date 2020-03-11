# vDiskExpander.ps1

No more updates, it is now integrated to "vBuild" - check: https://github.com/eschek87/scripts/tree/master/vmware/vBuild

### General
Creates a powershell gui with wpf and let's you expand windows virtual machines disk in vmware and then automatically expands the disk in the operating system.<br>
Tested with: PowerShell 5.0, PowerCLI 10.1, vSphere 6.5

### Features
- 

### Requirements  
- Module slr.psm1 from my github site https://github.com/eschek87/scripts/blob/master/slr.psm1 (contains some used functions)
- Module PoshWPF from https://www.powershellgallery.com/packages/PoshWPF/
- Active Directory user account with privilege to increase virtual disks
- Active Directory user account with privilege to expand disk in windows operation system
- VMs needs advanced parameter disk.enableUUID=true

### Configure
1. The whole configuration is done in vDiskExpander_config.json and needs to be customized for your needs. There are some examples pre-filled. But the most important are:
- Line 3: Your vCenter(s)  


Steps to expand a disk:
- Right click on the vDiskExpander.ps1 and select "Run with powershell"
- Select your vCenter (is loaded from vDiskExpander_config.json)
- Hit "Ok" to start the collection and wait until it is finished 
- Type in the vm name or dns hostname and hit "Get Disks" and wait until it is finished 
- Select your drive letter
- Enter new disk size in the last textbox and hit "Resize Disk" and wait until it is finished 

<img src="https://github.com/eschek87/scripts/blob/master/vmware/vDiskExpander/screenshots/vDiskExpander.jpg" height="50%" width="50%"/>