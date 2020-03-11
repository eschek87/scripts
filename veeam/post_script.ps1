#requires -version 5
#requires -modules VMware.VimAutomation.Core
#requires -modules PrnxCli
#requires -modules slr
Param (
#veeam backup job name
[Parameter(Mandatory=$true)][string]$vbrJob
) 
<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  all scripts need to be saved in the following form for the logging function to work correct script_name.ps1 and not script-name.ps1
  Get all vms with a vmware backup tag, the vmware backup tag is the same as the veeam job name and the veeam jobs are configured to use these vmware tag
  Script runs before the veeam job starts. Script is defined in veeam job setting to be executed before backup.
  It checks if the vms in this backup job have a vmware pernixdata fvp tag with write back policy, if it found vms it sets the policy to write back after the backup is finished.
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  look at section [Define variables]
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         Stephan Liebner
  Creation Date:  07.06.2016
  Purpose/Change: Initial script development
  
.EXAMPLE
  C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe C:\scripts\post_script.ps1 W2012
#>
#---------------------------------------------------------[Define variables]--------------------------------------------------------
#Define your variables here if possible

#vCenter server
$VCS = "<your vcenter>"

#generate credentials
#you need to run the following before
#Get-Credential | Export-Clixml -Path C:\scripts\${env:USERNAME}_cred.xml
$credentials = Import-Clixml -Path C:\scripts\${env:USERNAME}_cred.xml

#Hostname where script runs
$Hostname= $env:computername

#ip pernixdata mgmt server
$prnxMgmt="<your pernixdata management server>"

#vmware tag for pernixdata writeback
$vmPrnxTag="<vmware write back tag>"

#Backup and Pernixdata vCenter Tag Category Name
$vmBkpCtgyName="<vmware backup tag category>"
$vmPrnxCtgyName="<vmware perxixdata tag category>"
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
#Set error action to silently continue
#$ErrorActionPreference = "SilentlyContinue"

#Set debug action to continue if you want debug messages at console
$DebugPreference="Continue"

#Determine path of script
$ScriptDir = $(Split-Path $MyInvocation.MyCommand.Definition)
#Get filename of script and use the same name for the logfile without file extension
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptName = $ScriptName.Replace(".ps1","")
$ScriptFullPath = Join-Path -Path $ScriptDir -ChildPath $ScriptName

#Get date today for logfile in format day-month-year_hours-minutes, e.g. 24-11-2015_19-30
$Today = get-date -format d-M-yyyy_HH-mm

#Add snap-ins or modules
#Import-Module
#Add-PSSnapin
Import-Module prnxcli
#----------------------------------------------------------[Declarations]----------------------------------------------------------
#Script version
$ScriptVersion = "1.0"

#Define log file
$LogPath = $ScriptDir
$LogName = $ScriptName+"_"+$vbrJob+".log"
$LogFile = Join-Path -Path $LogPath -ChildPath $LogName

#Define output file
$OutputPath=$ScriptDir
$OutputName = "$Today"+"_"+"$ScriptName.csv"
$OutputFile = Join-Path -Path $OutputPath -ChildPath $OutputName
#-----------------------------------------------------------[Start Logging]------------------------------------------------------------
Log-Start -LogPath $LogPath -LogName $LogName -ScriptVersion $ScriptVersion
#-----------------------------------------------------------[Functions]------------------------------------------------------------

#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Write -LogPath $LogFile -LineValue "Execution starts"
Log-Write -LogPath $LogFile -LineValue "Connecting to vCenter..."
Connect-VIServer -Server $VCS
#need to wait some time, before the next connect cmdlet is issued, without wait the script does not work
Start-Sleep 60

Try
{
Connect-PrnxServer $prnxMgmt -Credentials $credentials
}
Catch
{
Log-Error -LogPath $LogFile -ErrorDesc $Error[0] -ExitGracefully $False
}

Log-Write -LogPath $LogFile -LineValue "get all vms"
$vms=Get-VM -Tag $vbrjob
Log-Write -LogPath $LogFile -LineValue "loop through all vms and get-tagassignment category backup and pernixdata"
foreach ($vm in $vms)
{
$vmName=$vm.name
$backupTag=(Get-TagAssignment -Entity $vm -Category Backup).Tag.Name
$prnxTag=(Get-TagAssignment -Entity $vm -Category Pernixdata).Tag.Name

    Log-Write -LogPath $LogFile -LineValue "check if backup tag from vm $vmName is equal $vbrjob"
    if ($backupTag -eq $vbrJob)
    {
    Log-Write -LogPath $LogFile -LineValue "check if pernixdata tag from vm $vmName is WB"
    
        if ($prnxTag -eq "$vmPrnxTag")
        {
            Log-Write -LogPath $LogFile -LineValue "$vmName has vmware tag $vmPrnxTag, execute Set-PrnxAccelerationPolicy -WriteBack -NumWBPeers 1 -NumWBExternalPeers 1 -WaitTimeSeconds 60 -Name $vmName"
            Try
            {
            Set-PrnxAccelerationPolicy -WriteBack -NumWBPeers 0 -NumWBExternalPeers 1 -WaitTimeSeconds 60 -Name $myvmname
            }
            Catch
            {
            Log-Error -LogPath $sLogFile -ErrorDesc $Error[0] -ExitGracefully $False
            
            }
        }
        else
        {Log-Write -LogPath $LogFile -LineValue "$vmName has vmware tag WT or no, nothing to do"}
    }
    else
    {Log-Write -LogPath $LogFile -LineValue "$vmName has (no) backup tag $backupTag and is not in veeam backup job $vbrJob, nothing to do"}
}
#-----------------------------------------------------------[Stop logging, disconnect from all vcenters and remove variables]------------------------------------------------------------
Log-Finish -LogPath $LogFile
Disconnect-PrnxServer
Disconnect-VIServer * -Confirm:$false