# close_file_handle.ps1

## General
Establish a ssh session to an isilon cluster and searches for open file handles that are definied in the search textbox. After selecting the line with the file it is possible to close this file handle.<br>
Beginning in OneFS 8.0.0, the 'isi smb sessions' and 'isi smb openfiles' commands were changed to use PAPI (Platform Application Programming Interface) and are restricted to the System zone, as they lack the '--zone' option like many other commands that are "zone aware".<br><br>
See emc kb 000497099<br>
The script will check the onefs version and if it is affected it will use another command and queries the zone id for open file handles: `isi_run -z 2 isi_classic smb file list`<br>
So you need to define your zone id.<br><br>
I will switch to use the PAPI with powershell invoke-restmethod once our onefs clusters are on 8.0.0.5 or later.

## Requirements  
Posh-SSH: https://www.powershellgallery.com/packages/Posh-SSH/1.7.7 <br>
slr.psm1

## Configure
- Line 32: Isilon Clusters (IP or Smart Connect Name) `$Clusters = "1.1.1.1","2.2.2.2"`
	  
- Line 41: Zone ID of your access zone that you want to query if your OneFS Version is between 8.0.0.0 - 8.0.0.4 `$ZoneId = "2"` <br>
![alt text](https://github.com/eschek87/powercli/blob/master/emc/close_file_handle.jpg)

## Example
.\close_file_handle.ps1

# modify_quota.ps1

## General
Query onefs isilon for existing quotas with the name from the search textbox and let you modify the quota after selecting the correct line. It uses the onefs papi with powershell invoke-restmethod.

## Requirements  
slr.psm1

## Configure
- Line 26: Isilon Clusters (IP or Smart Connect Name) `$Clusters = "1.1.1.1","2.2.2.2"`	  
![alt text](https://github.com/eschek87/powercli/blob/master/emc/modify_quota.jpg)

## Example
.\modify_quota.ps1