#requires -version 5
#requires -modules slr
<#
.SYNOPSIS
  Generates a csv with vDS and vmkernel networking data from all esxi host that are in a cluster.
.DESCRIPTION
  The following data is collected:
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
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  look at section [Define variables]
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         Stephan Liebner
  Creation Date:  11.03.2019
  Purpose/Change: Initial script development
  Version:        1.1
  Author:         Stephan Liebner
  Creation Date:  10.01.2020
  Purpose/Change: Collect cdp information
  
.EXAMPLE
  vESXiNetwork.ps1
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
$ScriptVersion = "1.1"

#Define log file
$LogPath = $ScriptDir
$LogName = "$ScriptName.log"
$LogFile = Join-Path -Path $LogPath -ChildPath $LogName

#Define output file
$OutputPath=$ScriptDir
$OutputName = "$Today"+"_"+"$ScriptName.csv"
$OutputFile = Join-Path -Path $OutputPath -ChildPath $OutputName
#---------------------------------------------------------[Define variables]--------------------------------------------------------
#Define your variables here if possible

#vCenter server
$VCS = ""

#Hostname where script runs
$ScriptHostname= $env:computername
#-----------------------------------------------------------[Start Logging]------------------------------------------------------------
Log-Start -LogPath $LogPath -LogName $LogName -ScriptVersion $ScriptVersion
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Connect-VIServer -Server $VCS

Log-Write -LogPath $LogFile -LineValue "Gathering VMHost objects"
$vmhosts = Get-VMHost | Sort Name | Where-Object {$_.ConnectionState -eq "Connected" -and $_.ParentId -like "Cluster*"}

Log-Write -LogPath $LogFile -LineValue "Loop through each esx host and get vmk ip settings"
$Network = @()
foreach ($vmhost in $vmhosts)
{
    Log-Write -LogPath $LogFile -LineValue "Collect network from $($vmhost.name)"
    $Vds = Get-VDSwitch -Name (Get-VDSwitch -VMHost $vmhost.Name) -VMHost $vmhost
    $Uplinks = Get-VDPort -VDSwitch $vds -Uplink | where {$_.ProxyHost -like $vmhost.name} 
    $vmhostview = $vmhost | Get-View
    $networkSystem = Get-view $vmhostview.ConfigManager.NetworkSystem  
    
    foreach ($Uplink in $Uplinks)
    {       
        $HostNetworks = Get-VMHostNetworkAdapter -VMHost $vmhost | Where-Object {$_.DeviceName -match "vmk"}

        foreach ($HostNetwork in $HostNetworks)
        {
            $PortGroupUplink = (Get-VDUplinkTeamingPolicy -VDPortgroup $HostNetwork.PortGroupName)
            if ($PortGroupUplink.ActiveUplinkPort -match $Uplink.Name)
            {
                $Object = "" | select Host,Nic,Portgroup,VMKernelInterface,VMKernelIP,MTU,Mac,ActiveUplink,StandbyUplink,Switch,SwitchPort
                $Object.Host = $Uplink.ProxyHost
                $Object.Nic = $Uplink.ConnectedEntity.Name
                $Object.Portgroup = (Get-VDUplinkTeamingPolicy -VDPortgroup $HostNetwork.PortGroupName).VdPortgroup.Name
                $Object.VMKernelInterface = $HostNetwork.Name
                $Object.VMKernelIP = $HostNetwork.IP
                $Object.Mtu = $HostNetwork.Mtu
                $Object.Mac = $HostNetwork.Mac
                $Object.ActiveUplink = $PortGroupUplink.ActiveUplinkPort -join ','             
                $Object.StandbyUplink = $PortGroupUplink.StandbyUplinkPort -join ','

                #CDP Info
                $CdpInfo = $networkSystem.QueryNetworkHint("$($Object.Nic)")
                $Object.Switch = $CdpInfo.ConnectedSwitchPort.SystemName
                $Object.SwitchPort = $CdpInfo.ConnectedSwitchPort.PortId

                $Network += $Object
            }
        }       
    }
}
$Network | Export-Csv $OutputFile -NoTypeInformation
#-----------------------------------------------------------[Stop logging, disconnect from all vcenters and remove variables]------------------------------------------------------------
Log-Finish -LogPath $LogFile
Disconnect-VIServer * -Confirm:$false
