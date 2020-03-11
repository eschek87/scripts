#requires -version 5
#requires -modules VMware.VimAutomation.Core 
#requires -modules slr
<#
.SYNOPSIS
  changes active path to datastore in vmware metro cluster with emc vplex with two san fabrics.
.DESCRIPTION
    Reason for this script:
    We have some vmware metro cluster connected to emc vplex. We use pernixdata fvp to accelerate vm's with caching devices in our esxi hosts. So we cannot use emc powerpath as path selection policy and 
    need to fallback to NMP or in our case to PRNX_PSP_FIXED. Best practices is to use only local vplex paths for I/O to reduce load on ISLs, to use the vplex cache optimal and to avoid higher latencies from the remote vplex.
    Every time a host reboots it automatically chooses a path from all available paths. Therefore I developed this script to check and set the paths on a schedule
    
    
    The script loops through a definied list of esxi hosts from a cluster and changes the active path from distributed datastore in vmware metro cluster with emc vplex with two san fabrics. 
    It uses the path selection policy PRNX_PSP_FIXED.
    
    
    Our vmware metro cluster design:
    - All esx hosts have 4 paths to distributed datastores (2 to our DC A VPLEX and 2 to our DC B VPLEX)
    - All esx hosts have 2 paths to non-distributed datastores at DC A (DC A esx hosts local to DC A VPLEX and DC B esx hosts via cross connect to DC A VPLEX)
    - All esx hosts have 2 paths to non-distributed datastores at DC B(DC B esx hosts local to DC B VPLEX and DC A esx hosts via cross connect to DC B VPLEX)
    - The script changes the paths for the distributed datastores:
    
        - It ensures that the active paths (I/O) for DC A esx hosts point at DC A VPLEX.
        - It ensures that the active paths (I/O) for DC B esx Hosts point at DC B VPLEX.
.PARAMETER <Parameter_Name>
  none  
.INPUTS
  look at section [Define variables]
.OUTPUTS
  send mail and log file are stored at script directory
.NOTES
  Version:        1.0
  Author:         Stephan Liebner
  Creation Date:  01.12.2015
  Purpose/Change: Initial script development
  
.EXAMPLE
  .\set_active_path_vplex_cross_connect.ps1
#>
#---------------------------------------------------------[Define variables]--------------------------------------------------------
#Define your variables here if possible

#vCenter server
$VCS = "<your vcenter>"

#Hostname where script runs
$ScriptHostname= $env:computername

#Generate credentials for login cmdlets
#you need to run the following onetime before
#Get-Credential | Export-Clixml -Path C:\scripts\${env:USERNAME}_cred.xml
#$Credentials = Import-Clixml -Path C:\scripts\${env:USERNAME}_cred.xml

#define filter for datacenter hosts
$DcAhosts="<hosts site a>"
$DcBhosts="<hosts site b>"

#define clusters
$Clusters="<clustername>"

#Filter for storage/disk typ
$vendor = "EMC"

#filter for local vplex pathes
#wwn DC A Vplex
$DcAvplexfab01_a00 = "wwn"
$DcAvplexfab01_a02 = "wwn"
$DcAvplexfab01_b00 = "wwn"
$DcAvplexfab01_b02 = "wwn"
                        
$DcAvplexfab02_a01 = "wwn"
$DcAvplexfab02_a03 = "wwn"
$DcAvplexfab02_b01 = "wwn"
$DcAvplexfab02_b03 = "wwn"

#wwn DC B Vplex                       
$DcBvplexfab01_a00 = "wwn"
$DcBvplexfab01_a02 = "wwn"
$DcBvplexfab01_b00 = "wwn"
$DcBvplexfab01_b02 = "wwn"
                        
$DcBvplexfab02_a01 = "wwn"
$DcBvplexfab02_a03 = "wwn"
$DcBvplexfab02_b01 = "wwn"
$DcBvplexfab02_b03 = "wwn"

#prnx path selection policy
$psp="PRNX_PSP_FIXED"

#variables for send-mailmessage for send as anonymous
$anonUsername = "anonymous"
$anonPassword = ConvertTo-SecureString -String "anonymous" -AsPlainText -Force
$anonCredentials = New-Object System.Management.Automation.PSCredential($anonUsername,$anonPassword)
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

#Dot source required function libraries
#.$ScriptDir\function.ps1

#Get date today for logfile in format day-month-year_hours-minutes, e.g. 24-11-2015_19-30
$Today = get-date -format d-M-yyyy_HH-mm

#Add snap-ins or modules
#Import-Module
#Add-PSSnapin
#----------------------------------------------------------[Declarations]----------------------------------------------------------
#Script version
$ScriptVersion = "1.0"

#Define log file
$LogPath = $ScriptDir
$LogName = "$ScriptName.log"
$LogFile = Join-Path -Path $LogPath -ChildPath $LogName

#Define output file
$OutputPath=$ScriptDir
$OutputName = "$Today"+"_"+"$ScriptName.csv"
$OutputFile = Join-Path -Path $OutputPath -ChildPath $OutputName
#-----------------------------------------------------------[Start Logging]------------------------------------------------------------
Log-Start -LogPath $LogPath -LogName $LogName -ScriptVersion $ScriptVersion
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Write -LogPath $LogFile -LineValue "Execution starts"
Log-Write -LogPath $LogFile -LineValue "Connecting to vCenter..."
Connect-VIServer -Server $VCS

foreach ($Cluster in $Clusters)
{
	Log-Write -LogPath $LogFile -LineValue "Getting all esx hosts and add all esx hosts from one datacenter to a variable"
    $esxhosts = Get-Cluster $Cluster|  Get-VMHost
	$DcAesxhosts = $esxhosts | Where-Object {$_.Name -like $DcAhosts}
	$DcBesxhosts = $esxhosts | Where-Object {$_.Name -like $DcBhosts}
	###################################DC A ESX Hosts#####################################################################
	Log-Write -LogPath $LogFile -LineValue "Loop through all esx hosts from datacenter $DcAhosts for local vplex paths"
	foreach ($DcAesxhost in $DcAesxhosts)
	{
	Log-Write -LogPath $LogFile -LineValue "Loading esxcli for host $DcAesxhost"
	$esxcli = Get-EsxCli -VMHost $DcAesxhost
	
	Log-Write -LogPath $LogFile -LineValue "Getting all datastores for host $DcAesxhost"
	$vplexdevices=($esxcli.storage.nmp.device.list() | Where-Object {$_.DeviceDisplayName -match "$vendor"}).device
	
		Log-Write -LogPath $LogFile -LineValue "Loop through all datastores for host $DcAesxhost"
		$i=0
		foreach ($vplexdevice in $vplexdevices)
		{
		Log-Write -LogPath $LogFile -LineValue "Setting path selection policy to $psp for vplex device $vplexdevice"
		$esxcli.storage.nmp.device.set(0, "$vplexdevice", "$psp")
		Log-Write -LogPath $LogFile -LineValue "Getting datastore name for vplex device $vplexdevice"
		$datastore = ($esxcli.storage.vmfs.extent.list() | Where-Object {$_.DeviceName -eq "$vplexdevice"}).VolumeName
		Log-Write -LogPath $LogFile -LineValue "Getting all paths for vplex device $datastore"
		$vplexpaths=($esxcli.storage.nmp.path.list() | Where-Object {$_.Device -eq $vplexdevice})
		#empty array with runtime names for next run
		$runtimename=$null
			Log-Write -LogPath $LogFile -LineValue "Loop through each path for $datastore and checks which paths matches to local vplex"
			foreach ($vplexpath in $vplexpaths) 
			{ 
				if (
				$vplexpath.Path -match $DcAvplexfab01_a00 -or 
				$vplexpath.Path -match $DcAvplexfab01_a02 -or 
				$vplexpath.Path -match $DcAvplexfab01_b00 -or 
				$vplexpath.Path -match $DcAvplexfab01_b02 -or 
				$vplexpath.Path -match $DcAvplexfab02_a01 -or 
				$vplexpath.Path -match $DcAvplexfab02_a03 -or 
				$vplexpath.Path -match $DcAvplexfab02_b01 -or 
				$vplexpath.Path -match $DcAvplexfab02_b03) 
				{
				[array]$runtimename+=$vplexpath.RuntimeName
				}        
				else 
				{
				}
			}
		if (!$runtimename)
		{
		Log-Write -LogPath $LogFile -LineValue "The vplex device $datastore is a device from the other datacenter and not distributed, change nothing"
		}
		else
		{ 
		Log-Write -LogPath $LogFile -LineValue "The vplex device $datastore is a distributed or a local device, will change path alternating to a local vplex path"
			try
			{
				if ($i%2 -eq 1)
				{
				$runtimename=$runtimename[0]
				$setpref = $esxcli.storage.nmp.psp.generic.pathconfig.set(0, "preferred", "$runtimename")
				}
				else
				{
				$runtimename=$runtimename[1]
				$setpref = $esxcli.storage.nmp.psp.generic.pathconfig.set(0, "preferred", "$runtimename")
				}
				$i++
			}
			catch
			{
			Log-Error -LogPath $LogFile -ErrorDesc $Error[0] -ExitGracefully $False
			
			}
			Log-Write -LogPath $LogFile -LineValue $DcAesxhost";"$runtimename";"$datastore";"$setpref #| Out-File -FilePath $OutputFile -Append
			}
		}
	}
	###################################DC B ESX Hosts#####################################################################
	Log-Write -LogPath $LogFile -LineValue "Loop through esx hosts from datacenter $DcBhosts for local vplex paths"
	foreach ($DcBesxhost in $DcBesxhosts)
	{
	Log-Write -LogPath $LogFile -LineValue "Loading esxcli for host $DcBesxhost"
	$esxcli = Get-EsxCli -VMHost $DcBesxhost
	
	Log-Write -LogPath $LogFile -LineValue "Getting all datastores for host $DcBesxhost"
	$vplexdevices=($esxcli.storage.nmp.device.list() | Where-Object {$_.DeviceDisplayName -match "$vendor"}).device
	
		Log-Write -LogPath $LogFile -LineValue "Loop through all datastores for host $DcBesxhost"
		$i=0
		foreach ($vplexdevice in $vplexdevices)
		{
		Log-Write -LogPath $LogFile -LineValue "Setting path selection policy to $psp for vplex device $vplexdevice"
		$esxcli.storage.nmp.device.set(0, "$vplexdevice", "$psp")
		Log-Write -LogPath $LogFile -LineValue "Getting datastore name for vplex device $vplexdevice"
		$datastore = ($esxcli.storage.vmfs.extent.list() | Where-Object {$_.DeviceName -eq "$vplexdevice"}).VolumeName
		Log-Write -LogPath $LogFile -LineValue "Getting all paths for vplex device $datastore"
		$vplexpaths=($esxcli.storage.nmp.path.list() | Where-Object {$_.Device -eq $vplexdevice})
		#empty array with runtime names for next run
		$runtimename=$null
			Log-Write -LogPath $LogFile -LineValue "Loop through each path for $datastore and checks which paths matches to local vplex"
			foreach ($vplexpath in $vplexpaths) 
			{ 
				if (
				$vplexpath.Path -match $DcBvplexfab01_a00 -or 
				$vplexpath.Path -match $DcBvplexfab01_a02 -or 
				$vplexpath.Path -match $DcBvplexfab01_b00 -or 
				$vplexpath.Path -match $DcBvplexfab01_b02 -or 
				$vplexpath.Path -match $DcBvplexfab02_a01 -or 
				$vplexpath.Path -match $DcBvplexfab02_a03 -or 
				$vplexpath.Path -match $DcBvplexfab02_b01 -or 
				$vplexpath.Path -match $DcBvplexfab02_b03) 
				{
				[array]$runtimename+=$vplexpath.RuntimeName
				}        
				else 
				{
				}
			}   
		if (!$runtimename)
		{
		Log-Write -LogPath $LogFile -LineValue "The vplex device $datastore is a device from the other datacenter and not distributed, change nothing"
		}
		else
		{ 
		Log-Write -LogPath $LogFile -LineValue "The vplex device $datastore is a distributed or local device, will change path alternating to a local vplex path"
			try
			{
				if ($i%2 -eq 1)
				{
				$runtimename=$runtimename[0]
				$setpref = $esxcli.storage.nmp.psp.generic.pathconfig.set(0, "preferred", "$runtimename")
				}
				else
				{
				$runtimename=$runtimename[1]
				$setpref = $esxcli.storage.nmp.psp.generic.pathconfig.set(0, "preferred", "$runtimename")
				}
				$i++
			}
			catch
			{
			Log-Error -LogPath $LogFile -ErrorDesc $Error[0] -ExitGracefully $False
			
			}
			Log-Write -LogPath $LogFile -LineValue $DcBesxhost";"$runtimename";"$datastore";"$setpref
			}
		}
	}
}
#-----------------------------------------------------------[Stop logging, disconnect from all vcenters and remove variables]------------------------------------------------------------
Log-Finish -LogPath $LogFile -NoExit $True
Disconnect-VIServer * -Confirm:$false