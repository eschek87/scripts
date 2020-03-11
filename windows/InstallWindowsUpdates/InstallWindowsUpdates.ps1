#requires -version 5
#requires -modules slr
<#
.SYNOPSIS
  Triggers sccm client to install available windows updates
.DESCRIPTION
  Define a list of servers with dns name in section "define variables"
  each server will be checked via remote wmi if updates available and triggers installation
  monitor installation progress for each server
  reboots server if necessary
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  look at section [Define variables]
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         Stephan Liebner
  Creation Date:  27.09.2018
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
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
#----------------------------------------------------------[Declarations]----------------------------------------------------------
#Script version
$ScriptVersion = "1.0"

#Define log file
$LogPath = $ScriptDir
$LogName = "$ScriptName.log"
$LogFile = Join-Path -Path $LogPath -ChildPath $LogName
#---------------------------------------------------------[Define variables]--------------------------------------------------------
#Define your variables here if possible

#Hostname where script runs
$ScriptHostname= $env:computername

$Servers +=
$Servers +=

$JobStatus = @{
    "0" = 'None'
    "1" = 'Available'
    "2" = 'Submitted'
    "3" = 'Detecting'
    "4" = 'PreDownload'
    "5" = 'Downloading'
    "6" = 'WaitInstall'
    "7" = 'Installing'
    "8" = 'PendingSoftReboot'
    "9" = 'PendingHardReboot'
    "10" = 'WaitReboot'
    "11" = 'Verifying'
    "12" = 'InstallComplete'
    "13" = 'Error'
    "14" = 'WaitServiceWindow'
    "15" = 'WaitUserLogon'
    "16" = 'WaitUserLogoff'
    "17" = 'WaitJobUserLogon'
    "18" = 'WaitUserReconnect'
    "19" = 'PendingUserLogoff'
    "20" = 'PendingUpdate'
    "21" = 'WaitingRetry'
    "22" = 'WaitPresModeOff'
    "23" = 'WaitForOrchestration'
    }
#-----------------------------------------------------------[Start Logging]------------------------------------------------------------
Log-Start -LogPath $LogPath -LogName $LogName -ScriptVersion $ScriptVersion
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Write -LogPath $LogFile -LineValue "Execution starts"
#Script execution goes here
#Try
#{
#}
#Catch
#{
#Log-Error -LogPath $LogFile -ErrorDesc $Error[0] -ExitGracefully $True
#Break
#}
Log-Write -LogPath $LogFile -LineValue "==================================="
Log-Write -LogPath $LogFile -LineValue "[START] Windows update installation"
Log-Write -LogPath $LogFile -LineValue "==================================="
Log-Write -LogPath $LogFile -LineValue " "
Log-Write -LogPath $LogFile -LineValue "-----------------------------------------------------------"
Log-Write -LogPath $LogFile -LineValue "[START] Check for windows updates & install"
foreach ($Server in $Servers)
{
    Log-Write -LogPath $LogFile -LineValue "[$Server] Check for windows updates & install "
    # Machine Policy Retrieval & Evaluation cycle
    #$SCCMClientUpdate = Invoke-WMIMethod -ComputerName $Server -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}"
    #$SCCMWinUpdate = Invoke-WMIMethod -ComputerName $Server -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000113}"

    # Get all updates
    [System.Management.ManagementObject[]]$SCCMMissingUpdates = Get-WmiObject -ComputerName $Server -query "SELECT * FROM CCM_SoftwareUpdate" -namespace "ROOT\ccm\ClientSDK"
    $Updates = $SCCMMissingUpdates.count
    If ($Updates) 
    {
        Log-Write -LogPath $LogFile -LineValue "[$Server] Found $Updates updates"
        #Install the missing updates
        Log-Write -LogPath $LogFile -LineValue "[$Server] Install missing updates"
        $SCCMInstall = (Get-WmiObject -ComputerName $Server -Namespace "root\ccm\clientsdk" -Class "CCM_SoftwareUpdatesManager" -List).InstallUpdates($SCCMMissingUpdates)
    }
}
Log-Write -LogPath $LogFile -LineValue "[FINISHED] Check for windows updates & install"
Log-Write -LogPath $LogFile -LineValue "-----------------------------------------------------------"
Log-Write -LogPath $LogFile -LineValue " "
Log-Write -LogPath $LogFile -LineValue "-----------------------------------------------------------"
Log-Write -LogPath $LogFile -LineValue "[START] Check windows update installation progress"
$c1=0
foreach ($Server in $Servers)
{
    # Get all updates
    [System.Management.ManagementObject[]]$SCCMMissingUpdates = Get-WmiObject -ComputerName $Server -query "SELECT * FROM CCM_SoftwareUpdate" -namespace "ROOT\ccm\ClientSDK"
    $Updates = $SCCMMissingUpdates.count

    # Check install status
    If ($Updates) 
    {
        Log-Write -LogPath $LogFile -LineValue "[$Server] Check windows update installation progress"
        $c1++
        Write-Progress -Id 0 -Activity "Installation progress" -Status "Processing server $Server" -PercentComplete (($c1/$Servers.Count) * 100)
        do
        {
            # Get all updates and select the first in the list and check the install status
            [System.Management.ManagementObject[]]$SCCMUpdateStatus = Get-WmiObject -ComputerName $Server -query "SELECT * FROM CCM_SoftwareUpdate" -namespace "ROOT\ccm\ClientSDK" | Sort-Object Name
            
            # Get update state
            $UpdateRunning = if(@($SCCMUpdateStatus | where { $_.EvaluationState -eq 0 -or $_.EvaluationState -eq 1 -or $_.EvaluationState -eq 2 -or $_.EvaluationState -eq 3 -or $_.EvaluationState -eq 4 -or $_.EvaluationState -eq 5 -or $_.EvaluationState -eq 6 -or $_.EvaluationState -eq 7 -or $_.EvaluationState -eq 11 }).length -ne 0) { $true } else { $false }  	        
            #Write-Progress -Activity "[$Server] Installation progress" -ParentId 1
            $y=1
            for ($i=0;$i -lt $SCCMUpdateStatus.Count;$i++)
            {
                Write-Progress -Activity "$($JobStatus["$($SCCMUpdateStatus[$i].EvaluationState)"])" -Status "KB $($SCCMUpdateStatus[$i].ArticleID)" -Id $y -ParentId 0
                $y++
            }
        }
        while ($UpdateRunning -eq $True)
    }
    Log-Write -LogPath $LogFile -LineValue "[$Server] Windows update installation finished"
}
Log-Write -LogPath $LogFile -LineValue "Sleep 30 seconds"
Start-Sleep -Seconds 30
Log-Write -LogPath $LogFile -LineValue "[FINISHED] Check windows update installation progress"
Log-Write -LogPath $LogFile -LineValue "-----------------------------------------------------------"
Log-Write -LogPath $LogFile -LineValue " "
Log-Write -LogPath $LogFile -LineValue "-----------------------------------------------------------"
Log-Write -LogPath $LogFile -LineValue "[START] Check if reboot required"
foreach ($Server in $Servers)
{    
    $Reboot = $false
    $Reboot = $Reboot -or ((Invoke-WmiMethod -ComputerName $Server -Namespace root\ccm\clientsdk -Class CCM_ClientUtilities -Name DetermineIfRebootPending).RebootPending)
    $Reboot = $Reboot -or ((Invoke-WmiMethod -ComputerName $Server -Namespace root\ccm\clientsdk -Class CCM_ClientUtilities -Name DetermineIfRebootPending).IsHardRebootPending)
    $Reboot = $Reboot -or {if(Invoke-Command -ComputerName $Server -ScriptBlock {@(((Get-ItemProperty("HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager")).$("PendingFileRenameOperations")) | where { $_ }).length -ne 0}) { $true } else { $false }}
    $Reboot = $Reboot -or {if(@($SCCMUpdateStatus | where { $_.EvaluationState -eq 8 -or $_.EvaluationState -eq 9 -or $_.EvaluationState -eq 10  }).length -ne 0) { $true } else { $false }}

    if ($Reboot -eq $True)
    {
        
        Log-Write -LogPath $LogFile -LineValue "[$Server] Reboot"
        #Invoke-Command -ComputerName $Server -ScriptBlock {shutdown /r}
    }
    else {}
}
Log-Write -LogPath $LogFile -LineValue "[FINISHED] Check if reboot required"
Log-Write -LogPath $LogFile -LineValue "-----------------------------------------------------------"
Log-Write -LogPath $LogFile -LineValue " "
Log-Write -LogPath $LogFile -LineValue "======================================"
Log-Write -LogPath $LogFile -LineValue "[FINISHED] Windows update installation"
Log-Write -LogPath $LogFile -LineValue "======================================"
#-----------------------------------------------------------[Stop logging, disconnect from all vcenters and remove variables]------------------------------------------------------------
Log-Finish -LogPath $LogFile