#requires -version 4
#requires -modules SLR,VMware.VimAutomation.Core
<#
.SYNOPSIS
  Collects information for virtual machine(s) hard disk(s), and for windows vm's map hard disk to windows disk volume name
  - VM Name, Controller, Disk Name, Storage Format, Size, Datastore Path, UUID
.DESCRIPTION
  all scripts need to be saved in the following form for the logging function to work correct script_name.ps1 and not script-name.ps1
.PARAMETER <Parameter_Name>
  <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  look at section [Define variables]
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         Stephan Liebner
  Creation Date:  18.02.2020
  Purpose/Change: Initial script development                                                                                                                                                                                                    
                                                                                                                                                                  
.EXAMPLE                                                                                                                                                     
  .\vDiskMapping.ps1
#>  
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Set error action to silently continue
#$ErrorActionPreference = "Stop"

# Set debug action to continue if you want debug messages at console
$DebugPreference = "SilentlyContinue"

# Determine path of script
$ScriptDir = $(Split-Path $MyInvocation.MyCommand.Definition)

# Get filename of script and use the same name for the logfile without file extension
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptName = $ScriptName.Replace(".ps1","")
$ScriptFullPath = Join-Path -Path $ScriptDir -ChildPath $ScriptName

#Get date today for logfile in format day-month-year_hours-minutes, e.g. 24-11-2015_19-30
$Today = get-date -format d-M-yyyy_HH-mm
#----------------------------------------------------------[Declarations]----------------------------------------------------------
# Script version
$ScriptVersion = "1.0"

# Define log file
$LogPath = $ScriptDir
$LogName = "$($ScriptName)_$($env:UserName).log"
$LogFile = Join-Path -Path $LogPath -ChildPath $LogName
#---------------------------------------------------------[Define variables]--------------------------------------------------------
$VCServer= ""
$VMDiskData = @()
$DiskData = $null

# Hostname where script runs
$ScriptHostname= $env:computername

# Variables for send-mailmessage for send as anonymous
$anonUsername = "anonymous"
$anonPassword = ConvertTo-SecureString -String "anonymous" -AsPlainText -Force
# Needs to be global to be accessible in script blocks
$Global:anonCredentials = New-Object System.Management.Automation.PSCredential($anonUsername,$anonPassword) 
#-----------------------------------------------------------[Start Logging]------------------------------------------------------------
#Log-Start -LogPath $LogPath -LogName $LogName -ScriptVersion $ScriptVersion
#-----------------------------------------------------------[Execution]------------------------------------------------------------
# Connect to vCenter Server(s)
Connect-VIServer -Server $VCServer

$Vms = Read-Host "Enter VMName to create disk mapping for (Comma separated)"
$Vms=$Vms.Split(',')

$Vdm = get-view -id (get-view serviceinstance).content.virtualdiskmanager

foreach ($Vm in $Vms)
{
    $Vm = Get-VM $Vm
    $Vmdisks = $Vm | Get-HardDisk
    $vmDatacenterView = $Vm | Get-Datacenter | Get-View 
    $VmView = Get-View -ViewType VirtualMachine -Filter @{"Name" = $Vm.Name}

    foreach ($Vmdisk in $Vmdisks)
    {
        if ($Vm.Guest.GuestFamily -like "*Windows*")
        {
            try{$Disks = Invoke-Command -ComputerName $Vm.Guest.HostName -ScriptBlock { Get-WmiObject Win32_DiskDrive | select * }}
            catch
            {}

            foreach($Disk in $Disks)
            {
                $Vmdiskuuid=$Vdm.queryvirtualdiskuuid($Vmdisk.Filename,$vmDatacenterView.MoRef).Replace(" ","").Replace("-","")
                if ($Vmdiskuuid -eq $Disk.SerialNumber)
                {
                    $DiskDriveToDiskPartition = Invoke-Command -ComputerName $vm.Guest.HostName -ScriptBlock { Get-WmiObject -query "Associators of {Win32_DiskDrive.DeviceID='$($using:Disk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" | Where-Object {$_.BootPartition -ne "True"} }                
                    $LogicalDiskToPartition = Invoke-Command -ComputerName $vm.Guest.HostName -ScriptBlock { Get-WmiObject -query "Associators of {Win32_DiskPartition.DeviceID='$($using:DiskDriveToDiskPartition.DeviceId)'} WHERE AssocClass = Win32_LogicalDiskToPartition" }   
                    $SCSIController = ($VmView.Config.Hardware.Device | where-object {$_.DeviceInfo.Label -match "SCSI Controller"}) | Where-Object {$_.Device -like $VmDisk.ExtensionData.Key}
                    
                    $DiskData = "" | Select VMName, Controller, DiskName, Index, DriveLetter, StorageFormat, Size,  WinSize, WinFree, WinVolumeName, Filename, UUID
                    $DiskData.VMName = $Vm.Name
                    $DiskData.Controller = "$($SCSIController.BusNumber) : $($Vmdisk.ExtensionData.UnitNumber)"  
                    $DiskData.DiskName = "$($Vmdisk.Name)"
                    $DiskData.Index = $Disk.Index
                    $DiskData.DriveLetter = $LogicalDiskToPartition.DeviceID               
                    $DiskData.StorageFormat = $Vmdisk.StorageFormat
                    $DiskData.Size = $Vmdisk.CapacityGB
                    $DiskData.WinSize = [math]::round(($LogicalDiskToPartition.Size / 1GB),0)
                    $DiskData.WinFree = [math]::round(($LogicalDiskToPartition.FreeSpace / 1GB),0)
                    $DiskData.WinVolumeName = $LogicalDiskToPartition.VolumeName
                    $DiskData.Filename = $Vmdisk.Filename
                    $DiskData.UUID = $Vmdiskuuid
                   
                    $VMDiskData += $DiskData 
                }
            }
        }
        else
        {
            $Vmdiskuuid=$Vdm.queryvirtualdiskuuid($Vmdisk.Filename,$vmDatacenterView.MoRef).Replace(" ","").Replace("-","")   
            $SCSIController = ($VmView.Config.Hardware.Device | where-object {$_.DeviceInfo.Label -match "SCSI Controller"}) | Where-Object {$_.Device -like $VmDisk.ExtensionData.Key}
            
            $DiskData = "" | Select VMName, Controller, DiskName, StorageFormat, Size, Filename, UUID
            $DiskData.VMName = $Vm.Name
            $DiskData.Controller = "$($SCSIController.BusNumber) : $($Vmdisk.ExtensionData.UnitNumber)"  
            $DiskData.DiskName = "$($Vmdisk.Name)"              
            $DiskData.StorageFormat = $Vmdisk.StorageFormat
            $DiskData.Size = $Vmdisk.CapacityGB
            $DiskData.Filename = $Vmdisk.Filename
            $DiskData.UUID = $Vmdiskuuid
            
            $VMDiskData += $DiskData 
        }
    }
}
$VMDiskData | Sort-Object { $_.VMName, $_.DriveLetter } | Out-GridView

#-----------------------------------------------------------[Stop logging, disconnect from all vcenters and remove variables]------------------------------------------------------------
Disconnect-VIServer * -Confirm:$false