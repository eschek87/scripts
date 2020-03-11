#requires -version 5
#requires -modules VMware.VimAutomation.Core 
#requires -modules slr
<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  First run must be with full access rights to create roles and permissions on target vcenter. Reads inventory from source vcenter and creates them on destination vcenter if they not exist
  - Folders (datacenter level)
  - Roles & Permissions (datacenter level)
  - Tag Categories & Tags
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  look at section [Define variables]
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         Stephan Liebner
  Creation Date:  06.03.2019
  Purpose/Change: Initial script development
.EXAMPLE
  vInventorySync.ps1
#>
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
#Set error action to silently continue
#$ErrorActionPreference = "SilentlyContinue"

#Set debug action to continue if you want debug messages at console
$DebugPreference="SilentlyContinue"

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

#Define output file
$OutputPath=$ScriptDir
$OutputName = "$Today"+"_"+"$ScriptName.csv"
$OutputFile = Join-Path -Path $OutputPath -ChildPath $OutputName
#---------------------------------------------------------[Define variables]--------------------------------------------------------
#Define your variables here if possible
$SourceViServer = ""
$DestinationViServer = ""

$SourceDatacenter = ""
$DestinationDatacenter = ""

# Get only roles that starts with this prefix
$RoleIncludeFilter = ""

# Exclude permissions that starts with this prefix
$PermissionsExcludeFilter = "VSPHERE.LOCAL"

# Exclude storage policies that are created by
$StoragePolicyExcludeFilter = "VMware Inc"

#Hostname where script runs
$ScriptHostname= $env:computername
#-----------------------------------------------------------[Start Logging]------------------------------------------------------------
Log-Start -LogPath $LogPath -LogName $LogName -ScriptVersion $ScriptVersion
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Write -LogPath $LogFile -LineValue "Execution starts"
####################EXPORT##################################################
Connect-VIServer -server $SourceViServer
$SourceDatacenter = Get-Datacenter $SourceDatacenter

###################
# FOLDERS - EXPORT
###################
Log-Write -LogPath $LogFile -LineValue "Collect - Folders" 
$SourceFolders = @()
foreach ( $SourceFolder in ($SourceDatacenter | Get-Folder) )
{
    $Object = "" | select Name, Type, Parent, Path
    $Object.Name = "$($SourceFolder.Name)"
    $Object.Type = "$($SourceFolder.Type)"
    $Object.Parent = "$($SourceFolder.Parent.Name)"
    $Object.Path = (Get-FolderPath -Folder $SourceFolder).Path -replace "Datencenter\\",""
    $SourceFolders += $Object
}

##################
# ROLES - EXPORT
##################
Log-Write -LogPath $LogFile -LineValue "Collect - Roles" 
$SourceRoles = @()
foreach ( $SourceRole in (Get-VIRole | Where-Object {$_.Name -like "$RoleIncludeFilter*"}) )
{
    $Object = "" | select Name, PrivilegeList
    $Object.Name = "$($SourceRole.Name)"
    $Object.PrivilegeList = $SourceRole.PrivilegeList
    $SourceRoles += $Object
}

###################### 
# PERMISSIONS - EXPORT
######################
Log-Write -LogPath $LogFile -LineValue "Collect - Permissions" 
$SourcePermissions = @()
foreach ( $SourcePermission in (Get-VIpermission | Where-Object {$_.Principal -notlike "$PermissionsExcludeFilter*"}) )
{
    $Object = "" | select EntityId, Entity, Principal, Role, Propagate
    $Object.EntityId = "$($SourcePermission.EntityId)"
    $Object.Entity = "$($SourcePermission.Entity.Name)"
    $Object.Principal = "$($SourcePermission.Principal)"
    $Object.Role = "$($SourcePermission.Role)"
    $Object.Propagate = "$($SourcePermission.Propagate)"
    $SourcePermissions += $Object
}

##########################
# Tags & Category - EXPORT
##########################
Log-Write -LogPath $LogFile -LineValue "Collect - Tags & Categories" 
$SourceTagCategories = @()
foreach ( $TagCategory in (Get-TagCategory) )
{
    $Object = "" | select Name, Cardinality, Description, EntityType
    $Object.Name = "$($TagCategory.Name)"
    $Object.Cardinality = "$($TagCategory.Cardinality)"
    $Object.Description = "$($TagCategory.Description)"
    $Object.EntityType = "$($TagCategory.EntityType)"
    
    # Find empty property
    $EmptyProperty = $Object.PSObject.Properties | Where-Object {$_.Value -eq ""}
    if ($EmptyProperty -ne $null)
    {Add-Member -InputObject $Object -NotePropertyName $EmptyProperty.Name -NotePropertyValue " " -force}

    $SourceTagCategories += $Object
}
$SourceTags = @()
foreach ( $Tags in (Get-Tag) )
{
    $Object = "" | select Name, Category, Description
    $Object.Name = "$($Tags.Name)"
    $Object.Category = "$($Tags.Category)"
    $Object.Description = "$($Tags.Description)"

    # Find empty property
    $EmptyProperty = $Object.PSObject.Properties | Where-Object {$_.Value -eq ""}
    if ($EmptyProperty -ne $null)
    {Add-Member -InputObject $Object -NotePropertyName $EmptyProperty.Name -NotePropertyValue " " -force}

    $SourceTags += $Object
}

###########################
# Storage Policies - EXPORT
###########################
Log-Write -LogPath $LogFile -LineValue "Collect - Storage Policies" 
$SourceStoragePolicies = @()
foreach ( $StoragePolicy in (Get-SpbmStoragePolicy | Where-Object {$_.CreatedBy -ne $StoragePolicyExcludeFilter}) )
{
    $Object = "" | select Name, Description, AnyOfRuleSets
    $Object.Name = "$($StoragePolicy.Name)"
    $Object.Description = "$($StoragePolicy.Description)"
    $Object.AnyOfRuleSets = "$($StoragePolicy.AnyOfRuleSets)"
    
    # Find empty property
    $EmptyProperty = $Object.PSObject.Properties | Where-Object {$_.Value -eq ""}
    if ($EmptyProperty -ne $null)
    {Add-Member -InputObject $Object -NotePropertyName $EmptyProperty.Name -NotePropertyValue " " -force}
    
    $SourceStoragePolicies += $Object
}
        
# Disconnect from Source vCenter 
Disconnect-VIServer $SourceViServer -Confirm:$false

####################IMPORT##################################################
Connect-VIServer -server $DestinationViServer
$DestinationDatacenter = Get-Datacenter $DestinationDatacenter

##################
# FOLDERS - IMPORT
##################
Foreach ($Folder in $SourceFolders)
{
    # Workaround: remove invisible folder path name
    $FolderPath = $Folder.Path -replace "Datencenter\\",""
    $ParentFolder = $Folder.Parent
    
    # Split fullpath into individual folder names   
    $Directorylist = $FolderPath.split('\')
    
    # Skip datacenter folder name 
    $Directorylist = $Directorylist | Where {$_ -ne $DestinationDatacenter}
    
    # Loop throught the list of directories and create them if not found.
    # Folder are created row by row, from left to right
    # Datacenter Root \ Subfolder1 \ Subfolder2 \ Subfolder3 
    # Once the folder is created it becomes the parent for subfolder.
    Foreach ($Directory in $Directorylist)
    {
        $Current = Get-Folder -name $Directory -ErrorAction SilentlyContinue
        if ($Current -eq $null)
        {
            Log-Write -LogPath $LogFile -LineValue "Creating new folder $Directory" 
            New-Folder -Name $Directory -Location $ParentFolder | Out-Null
        }else
        {Log-Write -LogPath $LogFile -LineValue "Skip - Found folder $Directory"}
    }
}

################
# ROLES - IMPORT
################
foreach ($Role in $SourceRoles) 
{
    # Check if role exist and check if privileges are the same
    $RoleExist = Get-VIRole -Name $Role.Name -ErrorAction SilentlyContinue
    $PrivilegeList = (Get-VIRole -Name $Role.Name -ErrorAction SilentlyContinue).PrivilegeList

    if ($RoleExist -eq $null)
    {
        Log-Write -LogPath $LogFile -LineValue "Creating new role $($Role.Name)"  
        New-VIRole -Name $Role.Name | Out-Null
        
        Log-Write -LogPath $LogFile -LineValue "Add Privileges to new role $($Role.Name)" 
        Set-VIRole -Role (Get-VIRole -Name $Role.Name) -AddPrivilege (Get-VIPrivilege -Id $Role.PrivilegeList) #-ErrorAction SilentlyContinue | Out-Null
    }
    elseif ( $RoleExist -ne $null -and (Compare-Object -ReferenceObject $Role.PrivilegeList -DifferenceObject $PrivilegeList) -ne $null )
    {

        $PrivilegeList = (Compare-Object -ReferenceObject $Role.PrivilegeList -DifferenceObject $PrivilegeList)
        foreach ($Privilege in $PrivilegeList)
        {
            if ($Privilege.SideIndicator -eq "<=")
            {
                Log-Write -LogPath $LogFile -LineValue "Modify - Found role $($Role.Name), but privilege $($Privilege.InputObject) are not on destination. Adding privilege"
                Set-VIRole -Role (Get-VIRole -Name $Role.Name) -AddPrivilege (Get-VIPrivilege -id $Privilege.InputObject) #-ErrorAction SilentlyContinue | Out-Null
            }
            elseif ($Privilege.SideIndicator -eq "=>")
            {
                Log-Write -LogPath $LogFile -LineValue "Modify - Found role $($Role.Name), but privilege $($Privilege.InputObject) are not on source. Removing privilege"
                Set-VIRole -Role (Get-VIRole -Name $Role.Name) -RemovePrivilege (Get-VIPrivilege -id $Privilege.InputObject) #| Out-Null
            }
        }
    }
    else {Log-Write -LogPath $LogFile -LineValue "Skip - Found role $($Role.Name) and privileges are the same."}
}


Start-Sleep -Seconds 10

###################### 
# PERMISSIONS - IMPORT
######################
# Create Permissions on cluster, datacenter root, virtual machines and folders
# Only if the objects exist
foreach ($Permission in $SourcePermissions) 
{
    if ($Permission.Propagate -eq "True")
    {$Permission.Propagate = $True}
    else {$Permission.Propagate = $False}

    $PermissionExist = $null
    $ClusterExist = $null
    $FolderExist = $null
    $VmExist = $null
    switch -Wildcard ($Permission.EntityId)
    {
        ClusterComputeResource-domain*
        {
            $ClusterExist = (Get-Cluster -Name $Permission.Entity -ErrorAction SilentlyContinue).Name
            if ($ClusterExist -ne $null)
            {$PermissionExist = (Get-VIPermission -Entity $ClusterExist -Principal $Permission.Principal -ErrorAction SilentlyContinue)}
            
            if ( $ClusterExist -ne $null -and $PermissionExist -eq $null )
            {
                Log-Write -LogPath $LogFile -LineValue "Creating new permissions for $($Permission.Entity): $($Permission.Principal) with $($Permission.Role) & Propagate is $($Permission.Propagate)"
                New-VIPermission -Entity (Get-Cluster -Name $Permission.Entity) -Principal $Permission.Principal -Role (Get-VIRole $Permission.Role) -Propagate $Permission.Propagate | Out-Null
            }
            else {Log-Write -LogPath $LogFile -LineValue "Skip - Found permission or object not present $($Permission.Entity)"}
        }
        Folder-group-d1
        {
            $FolderExist = (Get-Folder -Name $Permission.Entity -ErrorAction SilentlyContinue).Name
            if ($FolderExist -ne $null)
            {$PermissionExist = (Get-VIPermission -Entity $FolderExist -Principal $Permission.Principal -ErrorAction SilentlyContinue)}
            # Workaround
            $Permission.Entity =$Permission.Entity -replace "Datencenter","Datacenters"
            
            if ( $FolderExist -ne $null -and $PermissionExist -eq $null )
            {
                Log-Write -LogPath $LogFile -LineValue "Creating new permissions for $($Permission.Entity): $($Permission.Principal) with $($Permission.Role) & Propagate is $($Permission.Propagate)"
                New-VIPermission -Entity (Get-Folder -Name $Permission.Entity) -Principal $Permission.Principal -Role (Get-VIRole $Permission.Role) -Propagate $Permission.Propagate | Out-Null
            }
            else {Log-Write -LogPath $LogFile -LineValue "Skip - Found permission or object not present $($Permission.Entity)"}
        }
        VirtualMachine-vm*
        {
            $VmExist = (Get-VM -Name $Permission.Entity -ErrorAction SilentlyContinue).Name
            if ($VmExist -ne $null)
            {$PermissionExist = (Get-VIPermission -Entity $VmExist -Principal $Permission.Principal -ErrorAction SilentlyContinue)}
                       
            if ( $VmExist -ne $null -and $PermissionExist -eq $null)
            {
                Log-Write -LogPath $LogFile -LineValue "Creating new permissions for $($Permission.Entity): $($Permission.Principal) with $($Permission.Role) & Propagate is $($Permission.Propagate)"
                New-VIPermission -Entity (Get-VM -Name $Permission.Entity) -Principal $Permission.Principal -Role (Get-VIRole $Permission.Role) -Propagate $Permission.Propagate | Out-Null
            }
            else {Log-Write -LogPath $LogFile -LineValue "Skip - Found permission or object not present $($Permission.Entity)"}
        }
        Folder-group-v*
        {
            $FolderExist = (Get-Folder -Name $Permission.Entity -ErrorAction SilentlyContinue).Name
            if ($FolderExist -ne $null)
            {$PermissionExist = (Get-VIPermission -Entity $FolderExist -Principal $Permission.Principal -ErrorAction SilentlyContinue)}
                        
            if ( $FolderExist -ne $null -and $PermissionExist -eq $null )
            {
                Log-Write -LogPath $LogFile -LineValue "Creating new permissions for $($Permission.Entity): $($Permission.Principal) with $($Permission.Role) & Propagate is $($Permission.Propagate)"
                New-VIPermission -Entity (Get-Folder -Name $Permission.Entity) -Principal $Permission.Principal -Role (Get-VIRole $Permission.Role) -Propagate $Permission.Propagate | Out-Null
            }
            else {Log-Write -LogPath $LogFile -LineValue "Skip - Found permission or object not present $($Permission.Entity)"}
        }
    }
}

##########################
# Tags & Category - IMPORT
##########################
foreach ($Category in $SourceTagCategories) 
{
if ( (Get-TagCategory -Name $Category.Name -ErrorAction SilentlyContinue) -eq $null )
    {
        Log-Write -LogPath $LogFile -LineValue "Creating new tag category $($Category.Name)"  
        New-TagCategory -Name $Category.Name -Description $Category.Description -Cardinality $Category.Cardinality -EntityType $Cardinality.EntityType | Out-Null
    }
    else {Log-Write -LogPath $LogFile -LineValue "Skip - Found tag category $($Category.Name)"}
}
foreach ($Tag in $SourceTags) 
{
if ( (Get-Tag -Name $Tag.Name -ErrorAction SilentlyContinue) -eq $null )
    {
        Log-Write -LogPath $LogFile -LineValue "Creating new tag $($Tag.Name)"
        # Needs to be with ""  
        New-Tag -Name "$($Tag.Name)" -Category $Tag.Category -Description "$($Tag.Description)" | Out-Null
    }
    else {Log-Write -LogPath $LogFile -LineValue "Skip - Found tag $($Tag.Name)"}
}

###########################
# Storage Policies - IMPORT
###########################
<#
foreach ($StoragePolicy in $SourceStoragePolicies) 
{
if ( (Get-SpbmStoragePolicy -Name $StoragePolicy.Name -ErrorAction SilentlyContinue) -eq $null )
    {
        Log-Write -LogPath $LogFile -LineValue "Creating new storage policy $($StoragePolicy.Name)"  
        New-SpbmStoragePolicy -Name $StoragePolicy.Name -Description $StoragePolicy.Description -AnyOfRuleSets (New-SpbmRule $StoragePolicy.AnyOfRuleSets) | Out-Null
    }
    else {Log-Write -LogPath $LogFile -LineValue "Skip - Found storage policy $($StoragePolicy.Name)"}
}
#>

# Disconnect from Destination vCenter 
Disconnect-VIServer -Server $DestinationViServer -Force -confirm:$false
#-----------------------------------------------------------[Stop logging, disconnect from all vcenters and remove variables]------------------------------------------------------------
Log-Finish -LogPath $LogFile

<#
##Export all VM locations
$report = @()
$report = get-datacenter $datacenter -Server $sourceVI| get-vm | Get-Folderpath
 
$report | Export-Csv "c:\vms-with-FolderPath-$($datacenter).csv" -NoTypeInformation

# Virtual machine permissions
foreach($perm in $vmperms){
    $row = "" | select EntityId, FolderName, Role, Principal, IsGroup, Propagate
    $row.EntityId = $perm.EntityId
    $Foldername = (Get-View -id $perm.EntityId).Name
    $row.FolderName = $foldername
    $row.Principal = $perm.Principal
    $row.Role = $perm.Role
    $row.IsGroup = $perm.IsGroup
    $row.Propagate = $perm.Propagate
    $report += $row
}

##Export VM Custom Attributes and notes
$vmlist = get-datacenter $datacenter -Server $sourceVI| get-vm 
$Report =@()
foreach ($vm in $vmlist) {
    $row = "" | Select Name, Notes, Key, Value, Key1, Value1
    $row.name = $vm.Name
    $row.Notes = $vm | select -ExpandProperty Notes
    $customattribs = $vm | select -ExpandProperty CustomFields
    $row.Key = $customattribs[0].Key
    $row.Value = $customattribs[0].value
    $row.Key1 = $customattribs[1].Key
    $row.Value1 = $customattribs[1].value    
    $Report += $row
}
 
$report | Export-Csv "c:\vms-with-notes-and-attributes-$($datacenter).csv" -NoTypeInformation

# ESX host migration
 
#Switch off HA
Get-Cluster $datacenter -Server $sourceVI  | Set-Cluster -HAEnabled:$false -DrsEnabled:$false -Confirm:$false
 
#Remove ESX hosts from old vcenter
$Myvmhosts = get-datacenter $datacenter -Server $sourceVI | Get-VMHost 
foreach ($line in $Myvmhosts) {
Get-vmhost -Server $sourceVI -Name $line.Name | Set-VMHost -State "Disconnected" -Confirm:$false
Get-VMHost -server $sourceVI -Name $line.Name | Remove-VMHost -Confirm:$false
}
#add ESX hosts into new vcenter
foreach ($line in $Myvmhosts) {
    Add-VMHost -Name $line.name  -Location (Get-Datacenter $datacenter -server $destVI) -user root -Password trunk@1 -Force
}
 
#Turn on HA and DRS on 
Set-Cluster -Server $destVI Cluster1 -DrsEnabled:$true -HAEnabled:$true -Confirm:$false

##move the vm's to correct location
$VMfolder = @()
$VMfolder = import-csv "c:\VMs-with-FolderPath-$($datacenter).csv" | Sort-Object -Property Path
foreach($guest in $VMfolder){
    $key = @()
    $key =  Split-Path $guest.Path | split-path -leaf
    Move-VM (get-datacenter $datacenter -Server $destVI  | Get-VM $guest.Name) -Destination (get-datacenter $datacenter -Server $destVI | Get-folder $key) 
}
  
##Import VM Custom Attributes and Notes
$NewAttribs = Import-Csv "C:\vms-with-notes-and-attributes-$($datacenter).csv"
foreach ($line in $NewAttribs) {
    set-vm -vm $line.Name -Description $line.Notes -Confirm:$false
    Set-CustomField -Entity (get-vm $line.Name) -Name $line.Key -Value $line.Value -confirm:$false
    Set-CustomField -Entity (get-vm $line.Name) -Name $line.Key1 -Value $line.Value1 -confirm:$false

}

################    
# Error Checking
################
 
##Gather all info for New Vcenter        
##Export all folders
$report = @()
$report = Get-folder vm -server $destVI | get-folder | Get-Folderpath
        ##Replace the top level with vm
        foreach ($line in $report) {
        $line.Path = ($line.Path).Replace("DC1\","vm\")
        }
$report | Export-Csv "v:\Folders-with-FolderPath_dest.csv" -NoTypeInformation

<# 
##Export all VM locations
$report = @()
$report = get-vm -server $destVI | Get-Folderpath
 
$report | Export-Csv "c:\vms-with-FolderPath_dest.csv" -NoTypeInformation

 
#Get the Permissions    
$permissions = Get-VIpermission -Server $destVI
        
$report = @()
foreach($perm in $permissions){
        $row = "" | select EntityId, FolderName, Role, Principal, IsGroup, Propopgate
        $row.EntityId = $perm.EntityId
        $Foldername = (Get-View -id $perm.EntityId).Name
        $row.FolderName = $foldername
        $row.Principal = $perm.Principal
        $row.Role = $perm.Role
        $report += $row
}
$report | export-csv "v:\perms_dest.csv" -NoTypeInformation


##Export VM Custom Attributes and notes
 
$vmlist = get-vm -Server $destVI
$Report =@()
foreach ($vm in $vmlist) {
    $row = "" | Select Name, Notes, Key, Value, Key1, Value1
    $row.name = $vm.Name
    $row.Notes = $vm | select -ExpandProperty Notes
    $customattribs = $vm | select -ExpandProperty CustomFields
    $row.Key = $customattribs[0].Key
    $row.Value = $customattribs[0].value
    $row.Key1 = $customattribs[1].Key
    $row.Value1 = $customattribs[1].value    
    $Report += $row
}
$report | Export-Csv "c:\vms-with-notes-and attributes_dest.csv" -NoTypeInformation

 
##compare the source and destination - this part is not yet finished

write-output "Folder-paths"
Compare-Object -ReferenceObject (import-csv C:\vms-with-FolderPath.csv) (import-csv C:\vms-with-FolderPath_dest.csv) -IncludeEqual

write-output "Notes & Attributes"
Compare-Object -ReferenceObject (import-csv "C:\vms-with-notes-and attributes.csv") (import-csv "C:\vms-with-notes-and attributes_dest.csv") -IncludeEqual
 
write-output "Permissions"
Compare-Object -ReferenceObject (import-csv v:\perms.csv | select * -ExcludeProperty EntityId) (import-csv v:\perms_dest.csv | select * -ExcludeProperty EntityId) -IncludeEqual
#>    