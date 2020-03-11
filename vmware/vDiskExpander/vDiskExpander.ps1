#requires -version 4
#requires -modules SLR,PoshWPF,VMware.VimAutomation.Core
<#
.SYNOPSIS
  Maps virtual machine hard disk to windows drive letter and let's you expand the virtual machine hard disk and volume in windows
  VMs needs disk.enableUUID=true
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
  Creation Date:  11.06.2018
  Purpose/Change: Initial script development

  ToDo:
  After expand show new sizes
  Search with ad computer account

.EXAMPLE
  .\vDiskExpander.ps1
#> 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Set error action
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
# Name of xaml gui file
$GuiFile = $ScriptName+"_gui.xml"

# Name of config file
$ConfigFile = $ScriptName+"_config.xml"

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
#================================================================================================
# Import config and xaml file, needs to be global to be accessible in script blocks and functions
#================================================================================================
[xml]$Global:Config = Get-Content "$($ScriptDir)\$($ConfigFile)"
[xml]$Global:xaml = Get-Content "$($ScriptDir)\$($GuiFile)"

#region Functions
#####################################
# Connect to vCenter
#####################################
function Connect-vCenter
{
    #Build menu
    Write-Host "" 
    Write-Host "= Select a vCenter ="
    $vcs = $Config.Settings.VMware.VCenters.VCenter
    $menu = @{}
    for ($i=1;$i -le $vcs.count; $i++) 
    {
        Write-Host "$i. $($vcs[$i-1])"
        $menu.Add($i,($vcs[$i-1]))
    }
    
    [int]$answer = Read-Host 'Enter selection'
    $vcs = $menu.Item($answer)
    
    Write-Host ""
    Write-Host "= Connect to vCenter ="
    Connect-VIServer $vcs | Out-Null
}
#####################################
# Getting disks
#####################################
function Get-VMDisk {
    function Write-WpfError
    {
        param([string]$Text)
        Set-WPFControl -ControlName "getdisk" -PropertyName "Background" -Value "Red"
        Set-WPFControl -ControlName "getdisk" -PropertyName "ToolTip" -Value $Text
        Set-WPFControl -ControlName "getdisk" -Property "IsEnabled" -Value $true
        Set-WPFControl -ControlName "progressbar" -Property "IsIndeterminate" -Value $False
        #$wshell = New-Object -ComObject Wscript.Shell
        #$wshell.Popup("Useraccount $($TBUASAM.Text): failed to unlock!",0,"Error!",0x0) | Out-Null
    }
    ############################################
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "getdisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
    Set-WPFControl -ControlName "getdisk" -PropertyName "ToolTip" -Value "Get windows disk data"
    Set-WPFControl -ControlName "getdisk" -PropertyName "Background" -Value "#FFDDDDDD"
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Get disk data"

    # Create error variable for non terminating errors
    [array]$err = $null

    ####################################
    # Save Wpf Control value in variable
    ####################################
    $vmname = Get-WPFControl -ControlName "vmname" -PropertyName "Text"
    $hostname = Get-WPFControl -ControlName "hostname" -PropertyName "Text"

    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Get: Check inputs"
    #############################
    # Check if inputs are missing
    #############################
    if ([string]::IsNullOrEmpty($vmname) -and [string]::IsNullOrEmpty($hostname))
    {Write-WpfError -Text "VM or host name is missing";Return}
    elseif ([string]::IsNullOrEmpty($hostname))
    {
        try{$Global:Vm = Get-VM $vmname}
        catch
        {Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber) `n";Return}
    }
    elseif ([string]::IsNullOrEmpty($vmname))
    {
        try
        {
        $Global:Vm = Get-View -ViewType VirtualMachine -Property Name,Guest.HostName -Filter @{"Guest.HostName" = ".*$($hostname).*"} | Select @{N='VMName';E={$_.Name}}, @{N='GuestHostName';E={$_.Guest.HostName}}
        $Global:Vm = Get-VM $Vm.VMName
        }
        catch
        {Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber) `n";Return} 
    }
    else{}
    
    if(([string]::IsNullOrEmpty($Global:Vm)))
    {Write-WpfError -Text "No vm found";Return}         
    
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Get: Get vmware disk data"   
    $vmDatacenterView = $Vm | Get-Datacenter | Get-View  
    $Vdm = get-view -id (get-view serviceinstance).content.virtualdiskmanager
    $Vmdisks=$Vm | Get-HardDisk
    [array]$DiskData = New-Object System.Collections.ArrayList

    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Get: Get windows disk data and map to vmware disk data"
    foreach ($Vmdisk in $Vmdisks)
    {
        try{$Disks = Invoke-Command -ComputerName $Vm.Guest.HostName -ScriptBlock { Get-WmiObject Win32_DiskDrive | select * }}
        catch
        {Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber) `n";Return}

        foreach($Disk in $Disks)
        {
            $Vmdiskuuid=$Vdm.queryvirtualdiskuuid($Vmdisk.Filename,$vmDatacenterView.MoRef).Replace(" ","").Replace("-","")
            if ($Vmdiskuuid -eq $Disk.SerialNumber)
            {
                $DiskDriveToDiskPartition = Invoke-Command -ComputerName $vm.Guest.HostName -ScriptBlock { Get-WmiObject -query "Associators of {Win32_DiskDrive.DeviceID='$($using:Disk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" | Where-Object {$_.BootPartition -ne "True"} }                
                $LogicalDiskToPartition = Invoke-Command -ComputerName $vm.Guest.HostName -ScriptBlock { Get-WmiObject -query "Associators of {Win32_DiskPartition.DeviceID='$($using:DiskDriveToDiskPartition.DeviceId)'} WHERE AssocClass = Win32_LogicalDiskToPartition" }   
                $props=@{   
                DriveLetter=$LogicalDiskToPartition.DeviceID
                DiskName=$Vmdisk.Name
                StorageFormat=$Vmdisk.StorageFormat
                Size=$Vmdisk.CapacityGB
                WinSize=[math]::round(($LogicalDiskToPartition.Size / 1GB),0)
                WinFree=[math]::round(($LogicalDiskToPartition.FreeSpace / 1GB),0)
                WinVolumeName = $LogicalDiskToPartition.VolumeName
                }
                $DiskData += New-Object PsObject -Property $props
            }
        }
        $DiskData = $DiskData | Sort-Object { $_.DriveLetter }
    }
    Set-WpfControl -ControlName "vmname" -PropertyName "Text" -Value $Vm.Name
    Set-WPFControl -ControlName "hostname" -PropertyName "Text" -Value $Vm.Guest.HostName
    Set-WPFControl -ControlName "os" -PropertyName "Text" -Value $Vm.Guest.OSFullName
    Set-WPFControl -ControlName "driveletter" -PropertyName "ItemsSource" -Value $DiskData
    Set-WPFControl -ControlName "driveletter" -PropertyName "DisplayMemberPath" -Value "DriveLetter"  
    
    ##########################################         
    # Enable clicked button & stop progressbar
    ########################################## 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Get disk data" 
    Set-WPFControl -ControlName "getdisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"    
}

#####################################
# Resize disk
#####################################
function Set-VMDisk {
    function Write-WpfError
    {
        param([string]$Text)
        Set-WPFControl -ControlName "resizedisk" -PropertyName "Background" -Value "Red"
        Set-WPFControl -ControlName "resizedisk" -PropertyName "ToolTip" -Value $Text
        Set-WPFControl -ControlName "resizedisk" -Property "IsEnabled" -Value $true
        Set-WPFControl -ControlName "progressbar" -Property "IsIndeterminate" -Value $False
        #$wshell = New-Object -ComObject Wscript.Shell
        #$wshell.Popup("Useraccount $($TBUASAM.Text): failed to unlock!",0,"Error!",0x0) | Out-Null
    }
    ############################################
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "resizedisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
    Set-WPFControl -ControlName "resizedisk" -PropertyName "ToolTip" -Value "Set new disk size and expand"
    Set-WPFControl -ControlName "resizedisk" -PropertyName "Background" -Value "#FFDDDDDD"
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Set new disk size and expand"

    # Create error variable for non terminating errors
    [array]$err = $null

    ####################################
    # Save Wpf Control value in variable
    ####################################
    $Diskname = Get-WPFControl -ControlName "diskname" -PropertyName "Text"
    [int]$VmDiskSize = Get-WPFControl -ControlName "vmdisksize" -PropertyName "Text"
    [int]$NewDiskSize = Get-WPFControl -ControlName "newdisksize" -PropertyName "Text"
    $DriveLetter = (Get-WPFControl -ControlName "driveletter" -PropertyName "SelectedItem").DriveLetter

    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Resize: Check new disk size"
    if ($NewDiskSize -notmatch "^\d+$" -or $NewDiskSize -le $VmDiskSize)
    {Write-WpfError -Text "New disk size is not a number or less/equal current disk size";Return}
    
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Resize: Set new vm disk size"            
    try{$Vm | Get-HardDisk | Where-Object {$_.Name -eq $Diskname} | Set-HardDisk -CapacityGB $NewDiskSize -Confirm:$false}
    catch
    {Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber) `n";Return}

    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Resize: Expand disk in windows"
    Invoke-Command -ComputerName $Vm.Guest.HostName -ScriptBlock {"rescan" | diskpart
            #for W2k12R2 and higher
            #$Size = Get-PartitionSupportedSize -DriveLetter ($using:DriveLetter).replace(":","")
            #Resize-Partition -DriveLetter ($using:DriveLetter).replace(":","") -Size $Size.SizeMax

            'list disk' | diskpart | Where-Object {$_ -match 'disk (\d+)\s+online\s+\d+ .?b\s+\d+ [gm]b'} | ForEach-Object {$disk = $matches[1] 
            "select disk $disk", "list partition" | diskpart | Where-Object {$_ -match 'partition (\d+)'} | ForEach-Object { $matches[1] } | 
            ForEach-Object {"select disk $disk", "select partition $_", "extend" | diskpart | Out-Null}}
            }

    ##########################################         
    # Enable clicked button & stop progressbar
    ########################################## 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Set new disk size and expand" 
    Set-WPFControl -ControlName "resizedisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"
}

#####################################
# Stop script and gui
#####################################
function Stop-Gui
{
    Stop-Process -Id (Get-WmiObject -Class win32_process -Filter "name='powershell.exe'" | where-object {$_.CommandLine -like "*$ScriptName*"}).ProcessId
}

#####################################
# Add button actions/events
#####################################
function Add-WpfEvents
{
    #================================================
    # Actions & Events for buttons, textbox, checkbox
    #================================================
    # Button,select & close actions
    New-WPFEvent -ControlName "getdisk" -EventName "Click" -Action ${function:Get-VMDisk}
    New-WPFEvent -ControlName "resizedisk" -EventName "Click" -Action ${function:Set-VMDisk}
    New-WPFEvent -ControlName 'Window' -EventName 'Closing' -Action ${function:Stop-Gui}
}

#####################################
# Set Wpf Controls Content
#####################################
function Set-WpfControls
{
    #=====================
    # Tooltips for buttons
    #=====================
    Set-WPFControl -ControlName "getdisk" -PropertyName "ToolTip" -Value "Get windows disk data"
    Set-WPFControl -ControlName "resizedisk" -PropertyName "ToolTip" -Value "Set new disk size and expand"
}
#endregion Functions

#===================================================
# Connect to vCenter
#===================================================
# Calculate runtime
$StartDate = Get-Date
Clear-Host
Write-Host "########################################################################"
Write-Host "################                                        ################"
Write-Host "################              vDiskExpander             ################"
Write-Host "################                                        ################"
Write-Host "########################################################################"
Write-Host ""
Write-Host "=== Connect to vCenter"
Connect-vCenter
Hide-Console

#===================================================
# Create and open window/gui, set events and content
#===================================================
# Show gui
New-WPFWindow -xaml $xaml
# Start progressbar for setting button actions/events and wpf controls
Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "0"
Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Add events and content" 
# Add Events
Add-WpfEvents
# Set Content
Set-WpfControls
# Stop progressbar after setting events and wpf controls
Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"
# Calculate runtime
$EndDate = Get-Date
$Duration = New-TimeSpan –Start $StartDate –End $EndDate
$Text = "{0:mm} minutes and {0:ss} seconds" -f $Duration
Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Add events and content, Duration: $Text"  
# Leave the window/gui open
Start-WPFSleep