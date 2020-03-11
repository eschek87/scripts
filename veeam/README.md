# pre_script.ps1
## General
Get all vms with a vmware backup tag, the vmware backup tag is the same as the veeam job name and the veeam jobs are configured to use these vmware tag.<br>
Script runs before the veeam job starts. Script is defined in veeam job setting to be executed before backup.<br>
It checks if the vms in this backup job have a vmware pernixdata fvp tag with write back policy, if it found vms it sets the policy to write through in fvp before the backup starts to have a successful/conistent backup.

## Requirements
slr.psm1<br>
prnxcli<br>
powercli

## Configure
- Line 34: Your vCenter `$VCS = "1.1.1.1"`
	  
- Line 38&39: Credentials `Get-Credential | Export-Clixml -Path C:\scripts\${env:USERNAME}_cred.xml` <br>
You need to run this cmdlet first with a user that has admin rights to pernixdata management server. The script saves these credentials and use them for the connect-prnxserver
	  
- Line 45: Your Pernxidata Management Server `$prnxMgmt = "1.1.1.1"`

- Line 48: Your Pernxidata VMware Tag for Write Back `$prnxMgmt = "1.1.1.1"`

- Line 51&52: The name of your vmware backup and pernixdata tag category `$vmBkpCtgyName="Backup"` and `$vmPrnxCtgyName="Pernixdata"`
	  
## Example
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe C:\scripts\pre_script.ps1 W2012
![alt text](https://github.com/eschek87/powercli/blob/master/veeam/veeam_job_settings.jpg)
	  
# post_script.ps1
## General
Get all vms with a vmware backup tag, the vmware backup tag is the same as the veeam job name and the veeam jobs are configured to use these vmware tag.<br>
Script runs before the veeam job starts. Script is defined in veeam job setting to be executed before backup.<br>
It checks if the vms in this backup job have a vmware pernixdata fvp tag with write back policy, if it found vms it sets the policy to write back after the backup is finished.

## Requirements
slr.psm1<br>
prnxcli<br>
powercli

## Configure
- Line 34: Your vCenter `$VCS = "1.1.1.1"`
	  
- Line 38&39: Credentials `Get-Credential | Export-Clixml -Path C:\scripts\${env:USERNAME}_cred.xml` <br>
You need to run this cmdlet first with a user that has admin rights to pernixdata management server. The script saves these credentials and use them for the connect-prnxserver
	  
- Line 45: Your Pernxidata Management Server `$prnxMgmt = "1.1.1.1"`

- Line 48: Your Pernxidata VMware Tag for Write Back `$prnxMgmt = "1.1.1.1"`

- Line 51&52: The name of your vmware backup and pernixdata tag category `$vmBkpCtgyName="Backup"` and `$vmPrnxCtgyName="Pernixdata"`
	  
## Example
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe C:\scripts\pre_script.ps1 W2012
![alt text](https://github.com/eschek87/powercli/blob/master/veeam/veeam_job_settings.jpg)