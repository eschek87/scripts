#requires -version 4
#requires -modules SLR,PoshWPF,VMware.VimAutomation.Core
<#
.SYNOPSIS
  Creates a powershell gui with wpf and let's you clone windows virtual machines from windows templates with vCenter customization specs.
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
  Creation Date:  01.12.2015
  Purpose/Change: Initial script development
  Version:        2.0
  Author:         Stephan Liebner
  Creation Date:  04.10.2017
  Purpose/Change: Change from windows forms to wpf, optimize code, change from powershell jobs to runspace
  Version:        2.1
  Author:         Stephan Liebner
  Creation Date:  15.01.2018
  Purpose/Change: Added tabcontrol to script and moved some parts to these new tabcontrols
  Version:        2.2
  Author:         Stephan Liebner
  Creation Date:  23.02.2018
  Purpose/Change: Created some functions to reduce and optimze code, seperate json config file for post configuration and software installation, xml file for xaml code
  Version:        2.5
  Author:         Stephan Liebner
  Creation Date:  06.03.2018
  Purpose/Change: Code improvements, partial input validation, design enhancements
  Version:        2.7
  Author:         Stephan Liebner
  Creation Date:  12.04.2018
  Purpose/Change: It is now possible to move vm to a folder and clone vm from content library item ovf or template, reboot vm if vmtools are old, code improvements, design enhancements (tooltips for buttons)
  Version:        3.0
  Author:         Stephan Liebner
  Creation Date:  04.06.2018
  Purpose/Change: Using now module "PoshWPF" for creating the gui, collecting all vcenter data first and build then the gui, no more runspaces for scriptblocks needed, design and handling enhancements
  Version:        3.1
  Author:         Stephan Liebner
  Creation Date:  26.06.2018
  Purpose/Change: checkbox for overwrite hostname / computer account, better and more error handling
  Version:        3.2
  Author:         Stephan Liebner
  Creation Date:  17.07.2018
  Purpose/Change: switch config file from json to xml, all post config action can now have a default value for checked/unchecked in gui with xml attribute "IsChecked"
  Version:        3.3
  Author:         Stephan Liebner
  Creation Date:  04.06.2019
  Purpose/Change: Code improvements, performance optimization
  Version:        3.4
  Author:         Stephan Liebner
  Creation Date:  06.06.2019
  Purpose/Change: Export collected vCenter inventory to xml and import on start if files exist
  Version:        3.5
  Author:         Stephan Liebner
  Creation Date:  18.06.2019
  Purpose/Change: Validate postconfig and software installation
  Version:        3.6
  Author:         Stephan Liebner
  Creation Date:  08.01.2020
  Purpose/Change: Add possibility to create nsx security group and tags
  Version:        3.7
  Author:         Stephan Liebner
  Creation Date:  11.02.2020
  Purpose/Change: Small bug fixes
  Version:        3.8
  Author:         Stephan Liebner
  Creation Date:  13.02.2020
  Purpose/Change: Remove vm options like hotplug, tools etc from script and add them to config xml, make add-<>Elements more generic -> created a function
  Version:        4.0
  Author:         Stephan Liebner
  Creation Date:  13.02.2020
  Purpose/Change: vmtools status and guestoperation ready after customization 6 times ok, check if source, destination etc from config.xml is empty,sort postconfig, checked options first                                                                                                                                                                                                                                                                                                                                                                         
.EXAMPLE                                                                                                                                                     
  .\vBuild.ps1
#>  
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Set error action to silently continue
#$ErrorActionPreference = "Stop"

# Set debug action to continue if you want debug messages at console
$DebugPreference = "Continue"

# Determine path of script
$ScriptDir = $(Split-Path $MyInvocation.MyCommand.Definition)

# Get filename of script and use the same name for the logfile without file extension
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptName = $ScriptName.Replace(".ps1","")
$ScriptFullPath = Join-Path -Path $ScriptDir -ChildPath $ScriptName

#Get date today for logfile in format day-month-year_hours-minutes, e.g. 24-11-2015_19-30
$Today = get-date -format d-M-yyyy_HH-mm

Add-Type -AssemblyName System.Windows.Forms
#----------------------------------------------------------[Declarations]----------------------------------------------------------
# Script version
$ScriptVersion = "4.0"

# Define log file
$LogPath = $ScriptDir
$LogName = "$($ScriptName)_$($env:UserName).log"
$LogFile = Join-Path -Path $LogPath -ChildPath $LogName
#---------------------------------------------------------[Define variables]--------------------------------------------------------
# Name of xaml gui file
$GuiFile = $ScriptName+"_gui.xml"

# Name of config file
$ConfigFile = $ScriptName+"_config.xml"

# Name of inventory folder
$InventoryFolder = $ScriptName+"-Inventory"

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
# Connect to vCenter and collect data
#####################################
function Import-Inventory {
    #Build menu
    Write-Host "" 
    Write-Host "= Select a vCenter ="
    [array]$vcs = $Config.Settings.VMware.VCenters.VCenter
    $menu = @{}
    for ($i=1;$i -le $vcs.count; $i++) 
    {
        Write-Host "$i. $($vcs[$i-1])"
        $menu.Add($i,($vcs[$i-1]))
    }
    
    [int]$answer = Read-Host 'Enter selection'
    [string]$vcs = $menu.Item($answer)
    
    Write-Host ""
    Write-Host "= Connect to vCenter ="
    Connect-VIServer $vcs | Out-Null
    
    [string]$nsx = Read-Host 'Connect to nsx (y/n)?'
    if ($nsx -eq "y")
    {
        Write-Host "= Connect to NSX ="
        $Credentials = Get-Credential -Message "Provide credentials for nsx and vCenter login" -UserName (([String]::Concat($env:USERNAME,"@",$env:USERDNSDOMAIN)).tolower())
        Connect-NsxServer -vCenterServer $vcs -Credential $Credentials | Out-Null
    }

    #Global variables to be accessible outside function
    $Global:ClustersHosts = New-Object System.Collections.ArrayList
    $Global:Policies = New-Object System.Collections.ArrayList
    $Global:Templates = New-Object System.Collections.ArrayList
    $Global:Customizations = New-Object System.Collections.ArrayList
    $Global:Folders = New-Object System.Collections.ArrayList
    $Global:TagCategories = New-Object System.Collections.ArrayList
    
    #Create folder for inventory if not exist, to store vCenter inventory
    if ( !(Test-Path $ScriptDir\$InventoryFolder) )
    {New-Item -ItemType Directory -Path $ScriptDir\$InventoryFolder | out-null}

    #Check if inventory exist and import
    if ( (Test-Path $ScriptDir\$InventoryFolder\$($vcs)_ClustersHosts.xml) -and (Test-Path $ScriptDir\$InventoryFolder\$($vcs)_Policies.xml) -and (Test-Path $ScriptDir\$InventoryFolder\$($vcs)_Customizations.xml) -and (Test-Path $ScriptDir\$InventoryFolder\$($vcs)_TagCategories.xml) -and (Test-Path $ScriptDir\$InventoryFolder\$($vcs)_Folders.xml) -and (Test-Path $ScriptDir\$InventoryFolder\$($vcs)_Templates.xml) )
    {
        Write-Host "" 
        Write-Host "= Found existing inventory in '$ScriptDir\$InventoryFolder', import now ="
        Import-Clixml $ScriptDir\$InventoryFolder\$($vcs)_ClustersHosts.xml | Foreach {$ClustersHosts.Add($_)} | out-null
        Import-Clixml $ScriptDir\$InventoryFolder\$($vcs)_Policies.xml | ForEach {$Policies.Add($_)} | out-null
        Import-Clixml $ScriptDir\$InventoryFolder\$($vcs)_Templates.xml | ForEach {$Templates.Add($_)} | out-null
        Import-Clixml $ScriptDir\$InventoryFolder\$($vcs)_Customizations.xml | ForEach {$Customizations.Add($_)} | out-null
        Import-Clixml $ScriptDir\$InventoryFolder\$($vcs)_Folders.xml | ForEach {$Folders.Add($_)} | out-null
        Import-Clixml $ScriptDir\$InventoryFolder\$($vcs)_TagCategories.xml | ForEach {$TagCategories.Add($_)} | out-null
    }
    else
    {
        Write-Host "" 
        Write-Host "= Collect inventory ="
        Get-Cluster | Sort-Object | select Name, Id | ForEach {$ClustersHosts.Add($_)} | out-null
        Get-VMHost | Where-Object {$_.IsStandalone -eq 'True' -and $_.Manufacturer -notlike "*VMware*"} | Sort-Object | select Name, Id | ForEach {$ClustersHosts.Add($_)} | out-null
        (Get-SpbmStoragePolicy -Requirement | Sort-Object).Name | ForEach {$Policies.Add($_)} | out-null
        (Get-OSCustomizationSpec | Sort-Object).Name | ForEach {$Customizations.Add($_)} | out-null
        (Get-TagCategory | Where-Object {$_.EntityType -match "All|VirtualMachine"} | Sort-Object Name).Name | ForEach {$TagCategories.Add($_)} | out-null
        Get-Folder -Type VM | Get-FolderPath | Select Name, Path | Sort-Object Path | ForEach {$Folders.Add($_)} | out-null

        Get-Template | Select Name | ForEach {$Templates.Add($_)} | out-null
        $Templates | ForEach {Add-Member -InputObject $_ –MemberType NoteProperty –Name TemplateType –Value "$($_.Name) (Template)" -Force}  | out-null
        Get-ContentLibraryItem -ItemType ovf | Select Name, ItemType | ForEach {$Templates.Add($_)} | out-null
        $Templates | Where-Object {$_.ItemType -eq "ovf"} | ForEach {Add-Member -InputObject $_ –MemberType NoteProperty –Name TemplateType –Value "$($_.Name) (ovf)" -Force} | out-null
        
        Write-Host "= Export inventory to $ScriptDir\$InventoryFolder ="
        $ClustersHosts | Export-Clixml $ScriptDir\$InventoryFolder\$($vcs)_ClustersHosts.xml
        $Policies | Export-Clixml $ScriptDir\$InventoryFolder\$($vcs)_Policies.xml
        $Customizations | Export-Clixml $ScriptDir\$InventoryFolder\$($vcs)_Customizations.xml
        $TagCategories | Export-Clixml $ScriptDir\$InventoryFolder\$($vcs)_TagCategories.xml
        $Folders | Export-Clixml $ScriptDir\$InventoryFolder\$($vcs)_Folders.xml
        $Templates | Export-Clixml $ScriptDir\$InventoryFolder\$($vcs)_Templates.xml
    }      
}

###########################################################################################
# Create automatic wpf/xaml code for groupbox, listbox, checkbox, textblock from config.xml
###########################################################################################
function Add-WpfElements {
    param(
        [Parameter(Mandatory=$true)][xml]$xaml,
        [Parameter(Mandatory=$true)][string]$name
    )
    # Create one row definitions
    $GridRowDefinitions = $xaml.CreateElement('Grid.RowDefinitions',$xaml.Window.NamespaceURI)
    $null = ($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GridRowDefinitions)
    
    # Create one row for each xml childnode
    for ($i=0; $i -lt ($Config.Settings.$name.ChildNodes.Count); $i++) 
    { 
        $GridRowDefinition = $xaml.CreateElement('RowDefinition',$xaml.Window.NamespaceURI)
        $null = $GridRowDefinition.SetAttribute("Height","*")
        $null = (($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GridRowDefinitions)).AppendChild($GridRowDefinition)
    }
    
    # After all rows are created, create one groupbox for each category entry
    $y=0 # counter for wpf control name
    $x=0 # counter for groupbox grid.row
    foreach ($Node in $Config.Settings.$name.ChildNodes)
    {
        # Create groupbox
        $GroupBox = $xaml.CreateElement('GroupBox',$xaml.Window.NamespaceURI)
        $null = $GroupBox.SetAttribute("Grid.Row",$x)
        $null = $GroupBox.SetAttribute("Margin","3,3,3,3")
        $null = ($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)
        
        # Create groupbox header
        $GroupBoxHeader = $xaml.CreateElement('GroupBox.Header',$xaml.Window.NamespaceURI)
        $null = (($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)).AppendChild($GroupBoxHeader)
        
        # Create groupbox header label
        $Label = $xaml.CreateElement('Label',$xaml.Window.NamespaceURI)
        $null = $Label.SetAttribute("FontWeight","Bold")
        $null = $Label.SetAttribute("FontFamily","Calibri")
        $null = $Label.SetAttribute("FontSize",16)
        $null = $Label.SetAttribute("Content",$Node.Name)
        $null = ((($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)).AppendChild($GroupBoxHeader)).AppendChild($Label)
        
        # Create grid in groupbox
        $GroupBoxGrid = $xaml.CreateElement('Grid',$xaml.Window.NamespaceURI)
        $null = (($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)).AppendChild($GroupBoxGrid)
           
        # Create groupbox grid definitions
        $GroupBoxGridRowDefinitions = $xaml.CreateElement('Grid.RowDefinitions',$xaml.Window.NamespaceURI)
        $null = ((($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)).AppendChild($GroupBoxGrid)).AppendChild($GroupBoxGridRowDefinitions)
        
        # Create ListBox inside Groupbox
        $ListBox = $xaml.CreateElement('ListBox',$xaml.Window.NamespaceURI)  
        #$null = $ListBox.SetAttribute("Width","Auto")
        $null = $ListBox.SetAttribute("Height","310")
        $null = $ListBox.SetAttribute("BorderThickness","0")
        $null = ((($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)).AppendChild($GroupBoxGrid)).AppendChild($ListBox)
        
        # Sort objects, show 'IsChecked' at first in gui
        $Node.$name | Sort-Object IsChecked -Descending | % { [void]$Node.AppendChild($_) }

        # Create checkbox within groupbox foreach command
        for ($i=0; $i -lt ($Node.ChildNodes.Count); $i++) 
        {
            # Create ListBox Items foreach command
            $ListBoxItem = $xaml.CreateElement('ListBoxItem',$xaml.Window.NamespaceURI)
            $null = (((($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)).AppendChild($GroupBoxGrid)).AppendChild($ListBox)).AppendChild($ListBoxItem)
               
            # Create one checkbox for each category in this groupbox
            $CheckBox = $xaml.CreateElement('CheckBox',$xaml.Window.NamespaceURI)
            $null = $CheckBox.SetAttribute("Name",$($name+$y)) #it's important so set a name attribute, this is used/referenced in the command execution part of the script
            $null = $CheckBox.SetAttribute("Margin","3,3,3,3")
            

            if ($Node.ChildNodes.Count -gt "1")
            {
                if($Node.ChildNodes.IsChecked[$i] -match "true")
                {$null = $CheckBox.SetAttribute("IsChecked","True")}
                else{$null = $CheckBox.SetAttribute("IsChecked","False")}
            }
            else
            {
                if($Node.ChildNodes.IsChecked -match "true")
                {$null = $CheckBox.SetAttribute("IsChecked","True")}
                else{$null = $CheckBox.SetAttribute("IsChecked","False")}
            }
    
            $null = ((((($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)).AppendChild($GroupBoxGrid)).AppendChild($ListBox)).AppendChild($ListBoxItem)).AppendChild($CheckBox)
            
            #Create one textblock for each checkbox
            $TextBlock = $xaml.CreateElement('TextBlock',$xaml.Window.NamespaceURI)
            
            if ($Node.ChildNodes.Count -gt "1")
            {
                $null = $TextBlock.SetAttribute("Name","TB"+$($name+$y)) #Name for textblock
                $null = $TextBlock.SetAttribute("Text","$($Node.ChildNodes.name[$i])") #Name Attribute from xml
            }
            else
            {
                $null = $TextBlock.SetAttribute("Name","TB"+$($name+$y)) #Name for textblock
                $null = $TextBlock.SetAttribute("Text","$($Node.ChildNodes.name)") #Name Attribute from xml
            }

            $null = $TextBlock.SetAttribute("TextTrimming","CharacterEllipsis")
            $null = $TextBlock.SetAttribute("TextWrapping","Wrap")
            $null = $TextBlock.SetAttribute("Width","500")
            $null = (((((($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq $name}).AppendChild($GroupBox)).AppendChild($GroupBoxGrid)).AppendChild($ListBox)).AppendChild($ListBoxItem)).AppendChild($CheckBox)).AppendChild($TextBlock)
            
            # Increment counter to set a continuous "name" attribute
            $y++     
        }
        
        # Increment counter for the number of grid rows, one row for each category entry
        $x++
    }
}
  
#####################################
# Create gui elements for tagging
#####################################
function Add-TagElements {
    param(
        [Parameter(Mandatory=$true)][xml]$xaml
    )

    # Create one column definition and column
    $GridColumnDefinitions = $xaml.CreateElement('Grid.ColumnDefinitions',$xaml.Window.NamespaceURI)
    $GridColumnDefinition = $xaml.CreateElement('ColumnDefinition',$xaml.Window.NamespaceURI)
    $null = $GridColumnDefinition.SetAttribute("Width","*")
    $null = (($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq "Tagging"}).AppendChild($GridColumnDefinitions)).AppendChild($GridColumnDefinition)
    
    # Create one row definition
    $GridRowDefinitions = $xaml.CreateElement('Grid.RowDefinitions',$xaml.Window.NamespaceURI)
    $null = ($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq "Tagging"}).AppendChild($GridRowDefinitions)
    
    # At first create one row for each tag
    for ($i = 0; $i -lt ($TagCategories.count); $i++) 
    {        
        $GridRowDefinition = $xaml.CreateElement('RowDefinition',$xaml.Window.NamespaceURI)
        $null = $GridRowDefinition.SetAttribute("Height","*")
        $null = (($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq "Tagging"}).AppendChild($GridRowDefinitions)).AppendChild($GridRowDefinition)
    }
    
    # After all rows are created, create one combobox and textblock for each tag
    for ($i = 0; $i -lt ($TagCategories.count); $i++) 
    {           
        # Create one Combobox for each tag
        $ComboBox = $xaml.CreateElement('ComboBox',$xaml.Window.NamespaceURI)
        $null = $ComboBox.SetAttribute("Name",$("tag"+$i))
        $null = $ComboBox.SetAttribute("Grid.Row",$i)
        $null = $ComboBox.SetAttribute("Grid.Column","0")
        $null = $ComboBox.SetAttribute("Margin","3,3,3,3")
        $null = $ComboBox.SetAttribute("Height","25")
        $null = ($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq "Tagging"}).AppendChild($ComboBox)
        
        # Create one TextBlock for each tag
        $TextBlock = $xaml.CreateElement('TextBlock',$xaml.Window.NamespaceURI)
        $null = $TextBlock.SetAttribute("Name",$("tb"+$i))
        $null = $TextBlock.SetAttribute("Grid.Row",$i)
        $null = $TextBlock.SetAttribute("Grid.Column","0")
        $null = $TextBlock.SetAttribute("IsHitTestVisible","False")
        $null = $TextBlock.SetAttribute("Margin","7,7,7,7")
        $null = $TextBlock.SetAttribute("Foreground","Black")
        $null = $TextBlock.SetAttribute("Text","--- Select $($TagCategories[$i]) Tag ---")
        $null = $TextBlock.SetAttribute("Visibility","{Binding ElementName=$("tag"+$i), Path=Text.IsEmpty, Converter={StaticResource MyBoolToVisibilityConverter}}")
        $null = ($xaml.SelectNodes("//*[@Name]") | Where-Object {$_.Name -eq "Tagging"}).AppendChild($TextBlock) 
    }
}

#####################################
# Add button actions/events
#####################################
function Add-WpfEvents {
    #================================================
    # Actions & Events for buttons, textbox, checkbox
    #================================================
    # Button,select & close actions
    New-WPFEvent -ControlName "ImportVMConfig" -EventName "Click" -Action ${function:Import-VMConfig}
    New-WPFEvent -ControlName "AddNewVM" -EventName "Click" -Action ${function:Add-NewVM}
    New-WPFEvent -ControlName "SetTags" -EventName "Click" -Action ${function:Set-Tags} 
    New-WPFEvent -ControlName "InvokePostConfig" -EventName "Click" -Action  ${function:Invoke-PostConfig}
    New-WPFEvent -ControlName "InstallSoftware" -EventName "Click" -Action ${function:Install-Software}
    New-WPFEvent -ControlName "InvokeNSXConfig" -EventName "Click" -Action ${function:Invoke-NSXConfig}
    New-WPFEvent -ControlName "clusterorhost" -EventName "SelectionChanged" -Action ${function:Get-ClusterData}
    New-WPFEvent -ControlName 'Window' -EventName 'Closing' -Action ${function:Stop-Gui}

    New-WPFEvent -ControlName "GetVMDisk" -EventName "Click" -Action ${function:Get-VMDisk}
    New-WPFEvent -ControlName "SetVMDisk" -EventName "Click" -Action ${function:Set-VMDisk}

    # Textbox actions
    #Workaround for help text for passwordbox, cause they do not support databinding
    New-WPFEvent -ControlName "adminpassword" -EventName "GotFocus" -Action {Set-WPFControl -ControlName "tbpw" -PropertyName "Visibility" -Value "Hidden"}
    New-WPFEvent -ControlName "adminpassword" -EventName "LostFocus" -Action {
        if ([string]::IsNullOrWhiteSpace((Get-WPFControl -ControlName "adminpassword" -PropertyName "password")))
        {Set-WPFControl -ControlName "tbpw" -PropertyName "Visibility" -Value "Visible"}
        else{}
    }
    #Workaround for ip textbox databinding (checkbox checked)
    New-WPFEvent -ControlName "ip" -EventName "GotFocus" -Action {Set-WPFControl -ControlName "tbip" -PropertyName "Visibility" -Value "Hidden"}
    New-WPFEvent -ControlName "ip" -EventName "LostFocus" -Action {
        if ([string]::IsNullOrWhiteSpace((Get-WPFControl -ControlName "ip" -PropertyName "Text")))
        {Set-WPFControl -ControlName "tbip" -PropertyName "Visibility" -Value "Visible"}
        else{}
    }
    #Workaround for subnet textbox databinding (checkbox checked)
    New-WPFEvent -ControlName "subnet" -EventName "GotFocus" -Action {Set-WPFControl -ControlName "tbsub" -PropertyName "Visibility" -Value "Hidden"}
    New-WPFEvent -ControlName "subnet" -EventName "LostFocus" -Action {
        if ([string]::IsNullOrWhiteSpace((Get-WPFControl -ControlName "subnet" -PropertyName "Text")))
        {Set-WPFControl -ControlName "tbsub" -PropertyName "Visibility" -Value "Visible"}
        else{}
    }
    #Workaround for gateway textbox databinding (checkbox checked)
    New-WPFEvent -ControlName "gateway" -EventName "GotFocus" -Action {Set-WPFControl -ControlName "tbgw" -PropertyName "Visibility" -Value "Hidden"}
    New-WPFEvent -ControlName "gateway" -EventName "LostFocus" -Action {
        if ([string]::IsNullOrWhiteSpace((Get-WPFControl -ControlName "gateway" -PropertyName "Text")))
        {Set-WPFControl -ControlName "tbgw" -PropertyName "Visibility" -Value "Visible"}
        else{}
    }
    # Chechbox action
    #if checkbox static ip is checked then make relevant textboxes visible
    New-WPFEvent -ControlName "staticip" -EventName "Checked" -Action {
        Set-WPFControl -ControlName "ip" -PropertyName "Visibility" -Value "Visible"
        Set-WPFControl -ControlName "subnet" -PropertyName "Visibility" -Value "Visible"
        Set-WPFControl -ControlName "gateway" -PropertyName "Visibility" -Value "Visible"
        Set-WPFControl -ControlName "tbip" -PropertyName "Visibility" -Value "Visible"
        Set-WPFControl -ControlName "tbsub" -PropertyName "Visibility" -Value "Visible"
        Set-WPFControl -ControlName "tbgw" -PropertyName "Visibility" -Value "Visible"
    }
    #if checkbox static ip is unchecked then collaps relevant textboxes
    New-WPFEvent -ControlName "staticip" -EventName "UnChecked" -Action {
        Set-WPFControl -ControlName "ip" -PropertyName "Visibility" -Value "Collapsed"
        Set-WPFControl -ControlName "subnet" -PropertyName "Visibility" -Value "Collapsed"
        Set-WPFControl -ControlName "gateway" -PropertyName "Visibility" -Value "Collapsed"
        Set-WPFControl -ControlName "tbip" -PropertyName "Visibility" -Value "Collapsed"
        Set-WPFControl -ControlName "tbsub" -PropertyName "Visibility" -Value "Collapsed"
        Set-WPFControl -ControlName "tbgw" -PropertyName "Visibility" -Value "Collapsed"
    }
    
    <# HDD
    New-WPFEvent -ControlName "hdd" -EventName "Checked"{
        Set-WPFControl -ControlName "hddnumber_slider" -PropertyName "Visibility" -Value "Visible"
        Set-WPFControl -ControlName "hddnumber_textbox" -PropertyName "Visibility" -Value "Visible"
        Set-WPFControl -ControlName "hddnumber_label" -PropertyName "Visibility" -Value "Visible"
    })
    New-WPFEvent -ControlName "hdd" -EventName "UnChecked"{
        Set-WPFControl -ControlName "hddnumber_slider" -PropertyName "Visibility" -Value "Collapsed"
        Set-WPFControl -WindowName "vBuild" -ControlName "hddnumber_textbox" -PropertyName "Visibility" -Value "Collapsed"
        Set-WPFControl -ControlName "hddnumber_label" -PropertyName "Visibility" -Value "Collapsed"
    })
    #>
}

#####################################
# Set Wpf Controls Content
#####################################
function Set-WpfControls {       
    Set-WPFControl -ControlName "clusterorhost" -PropertyName "ItemsSource" -Value $ClustersHosts
    Set-WPFControl -ControlName "clusterorhost" -PropertyName "DisplayMemberPath" -Value "Name"
    Set-WPFControl -ControlName "policy" -PropertyName "ItemsSource" -Value $Policies
    Set-WPFControl -ControlName "template" -PropertyName "ItemsSource" -Value $Templates
    Set-WPFControl -ControlName "template" -PropertyName "DisplayMemberPath" -Value "TemplateType"
    Set-WPFControl -ControlName "customization" -PropertyName "ItemsSource" -Value $Customizations
    Set-WPFControl -ControlName "vmfolder" -PropertyName "ItemsSource" -Value $Folders
    Set-WPFControl -ControlName "vmfolder" -PropertyName "DisplayMemberPath" -Value "Path"   
    $i=0
    $TagCategories | foreach {
        $Tags = New-Object System.Collections.ArrayList 
        $Tags.Add(" ") | out-null
        (Get-Tag -Category $_| Sort-Object).Name | ForEach {$Tags.Add($_)} | out-null
        Set-WPFControl -ControlName $("tag"+$i) -PropertyName "ItemsSource" -Value $Tags
        $i++
        }
    
    $DiskType = New-Object System.Collections.ArrayList
    $DiskType = "Thin","Thick eager zeroed","Thick lazy zeroed"
    Set-WPFControl -ControlName "disktype" -PropertyName "ItemsSource" -Value $DiskType

    #===============================================================
    # Load/set default values from config file that we need to start
    #===============================================================
    Set-WPFControl -ControlName "mailto" -PropertyName "ItemsSource" -Value $Config.Settings.Mail.To
    Set-WPFControl -ControlName "staticip" -PropertyName "IsChecked" -Value $True
}

#####################################
# Collect cluster data
#####################################
function Get-ClusterData {
    # Calculate scribtblock runtime
    $StartDate = Get-Date
       
    # Start progressbar
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Collect cluster data"

    # Save Wpf Control value in variable
    $clusterorhost = Get-WPFControl -ControlName "clusterorhost" -PropertyName "SelectedItem"

    # Check if cluster was selected or single host
    if ($clusterorhost.id -like "Cluster*")
    {
        $EsxHosts = (Get-Cluster -Name $clusterorhost.name | Get-VMHost | Where-Object {$_.ConnectionState -ne "Maintenance"} | Sort-Object).Name     
        $ResourcePools = (Get-Cluster -Name $clusterorhost.name | Get-ResourcePool | Where-Object {$_.Name -notmatch "Resources|Virtual Lab 1"} | Sort-Object).Name              
        $PortGroups = (Get-VDSwitch -VMHost ($EsxHosts | select -First 1) | Get-VDPortgroup | Sort-Object).Name
        $Datastores = New-Object System.Collections.ArrayList
        Get-Cluster -Name $clusterorhost.name | Get-Datastore | Where-Object {($_.Name -notmatch "local") -and ($_.Name -notmatch "nfs") -and ($_.Name -notmatch "veeam")} | Select Name, FreeSpaceGB | Sort-Object | ForEach {$Datastores.Add($_)} | out-null
        $Datastores | ForEach {Add-Member -InputObject $_ –MemberType NoteProperty –Name FreeSpace –Value "$($_.Name) ($([math]::round($_.FreeSpaceGB,2)) GB free)"}        
    }
    else
    {
        [array]$EsxHosts = (Get-VMHost -Name $clusterorhost.name).Name
        $ResourcePools = (Get-VMHost -Name $clusterorhost.name | Get-ResourcePool | Where-Object {$_.Name -notmatch "Resources|Virtual Lab 1"} | Sort-Object).Name        
        $PortGroups = (Get-VirtualPortGroup -VMHost $clusterorhost.name -Standard | Sort-Object).Name
        $Datastores = New-Object System.Collections.ArrayList
        Get-VMHost -Name $clusterorhost.name | Get-Datastore | Where-Object {($_.Name -notmatch "local") -and ($_.Name -notmatch "nfs") -and ($_.Name -notmatch "veeam")} | Select Name, FreeSpaceGB | Sort-Object | ForEach {$Datastores.Add($_)} | out-null
        $Datastores | ForEach {Add-Member -InputObject $_ –MemberType NoteProperty –Name FreeSpace –Value "$($_.Name) ($([math]::round($_.FreeSpaceGB,2)) GB free)"}  
    }   
       
    # Update Wpf Controls
    Set-WPFControl -ControlName "esxhost" -PropertyName "ItemsSource" -Value $EsxHosts
    Set-WPFControl -ControlName "resourcepool" -PropertyName "ItemsSource" -Value $ResourcePools
    Set-WPFControl -ControlName "portgroup" -PropertyName "ItemsSource" -Value $PortGroups
    Set-WPFControl -ControlName "datastore" -PropertyName "ItemsSource" -Value $Datastores
    Set-WPFControl -ControlName "datastore" -PropertyName "DisplayMemberPath" -Value "FreeSpace"
 
    # Set Wpf Control Items that are needed for creating a vm
    #Set-WPFControl -ControlName "esxhost" -PropertyName "SelectedIndex" -Value "0"
    #Set-WPFControl -ControlName "datastore" -PropertyName "SelectedIndex" -Value "0"
    #Set-WPFControl -ControlName "portgroup" -PropertyName "SelectedIndex" -Value "0"

    # Calculate scribtblock runtime
    $EndDate = Get-Date
    $Duration = New-TimeSpan –Start $StartDate –End $EndDate
    $Text = "{0:mm} minutes and {0:ss} seconds" -f $Duration

    # Enable clicked button & stop progressbar 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Collect cluster data, Duration: $Text"
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"
}

#####################################
# Build and configure virtual machine
#####################################
function Add-NewVM {
    function Write-WpfError
    {
        param([string]$Text)
        Set-WPFControl -ControlName "AddNewVM" -Property "IsEnabled" -Value $true
        Set-WPFControl -ControlName "progressbar" -Property "IsIndeterminate" -Value $False
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("$($Text)",0,"Error!",64) | Out-Null
    }
    # Calculate scribtblock runtime
    $StartDate = Get-Date
    ############################################
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Build and configure virtual machine"   

    # Create output variable for popup
    [array]$output = $null

    ####################################
    # Save Wpf Control value in variable
    ####################################
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Collect inputs"
    $vmname = Get-WPFControl -ControlName "vmname" -PropertyName "Text"
    $hostname = Get-WPFControl -ControlName "hostname" -PropertyName "Text"
    $overwritehostname = Get-WPFControl -ControlName "overwritehostname" -PropertyName "IsChecked"
    $ip = Get-WPFControl -ControlName "ip" -PropertyName "Text"
    $gateway = Get-WPFControl -ControlName "gateway" -PropertyName "Text"
    $subnet = Get-WPFControl -ControlName "subnet" -PropertyName "Text"
    $staticip = Get-WPFControl -ControlName "staticip" -PropertyName "IsChecked"
    $customization = Get-WPFControl -ControlName "customization" -PropertyName "SelectedItem"
    $template = Get-WPFControl -ControlName "template" -PropertyName "SelectedItem"
    $clusterorhost = Get-WPFControl -ControlName "clusterorhost" -PropertyName "SelectedItem"
    $esxhost = Get-WPFControl -ControlName  "esxhost" -PropertyName "SelectedItem"
    $datastore = Get-WPFControl -ControlName "datastore" -PropertyName "SelectedItem"
    $policy = Get-WPFControl -ControlName "policy" -PropertyName "SelectedItem"
    $portgroup = Get-WPFControl -ControlName "portgroup" -PropertyName "SelectedItem"
    $resourcepool = Get-WPFControl -ControlName "resourcepool" -PropertyName "SelectedItem"
    $adminpassword = Get-WPFControl -ControlName "adminpassword" -PropertyName "Password"
    $ram = Get-WPFControl -ControlName "ram" -PropertyName "Text"
    $totalcores = Get-WPFControl -ControlName "totalcores" -PropertyName "Text"
    $corespersocket = Get-WPFControl -ControlName "corespersocket" -PropertyName "Text"
    $disktype = Get-WPFControl -ControlName "disktype" -PropertyName "SelectedItem"
    $vmfolder = Get-WPFControl -ControlName "vmfolder" -PropertyName "SelectedItem"
    $To = Get-WPFControl -ControlName "mailto" -PropertyName "SelectedItem"
    
    #############################################################
    # Check if inputs are missing that are needed to build the vm
    #############################################################
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Validate inputs"
    if ([string]::IsNullOrWhiteSpace($vmname))
    {Write-WpfError -Text "vmname missing or contains whitespace";Return}
    if ([string]::IsNullOrWhiteSpace($hostname))
    {Write-WpfError -Text "hostname missing";Return}
    if ([string]::IsNullOrWhiteSpace($customization))
    {Write-WpfError -Text "customization missing";Return}
    if ([string]::IsNullOrWhiteSpace($template))
    {Write-WpfError -Text "template missing";Return}
    if ([string]::IsNullOrWhiteSpace($clusterorhost))
    {Write-WpfError -Text "cluster or host missing";Return}
    if ([string]::IsNullOrWhiteSpace($esxhost))
    {Write-WpfError -Text "esxhost missing";Return}
    if ([string]::IsNullOrWhiteSpace($datastore))
    {Write-WpfError -Text "datastore missing";Return}
    if ([string]::IsNullOrWhiteSpace($portgroup))
    {Write-WpfError -Text "portgroup missing";Return}
    if ([string]::IsNullOrWhiteSpace($adminpassword))
    {Write-WpfError -Text "adminpassword missing";Return}
    if ([string]::IsNullOrWhiteSpace($ram))
    {Write-WpfError -Text "ram missing";Return}
    if ([string]::IsNullOrWhiteSpace($totalcores))
    {Write-WpfError -Text "cpu missing";Return}
    if ([string]::IsNullOrWhiteSpace($corespersocket))
    {Write-WpfError -Text "cores missing";Return}
    if ($totalcores -lt $corespersocket)
    {Write-WpfError -Text "Total cpu cores is less than cores per socket. Please change vm hardware.";Return}
    if ([string]::IsNullOrWhiteSpace($vmfolder))
    {Write-WpfError -Text "vm folder missing";Return}
    if ($overwritehostname -ne "True")
    {
        if ($(try {Get-ADComputer $hostname} catch {$null}) -ne $null) 
        {Write-WpfError -Text "Computer/hostname account exist";Return}
    }
    if ($(try {Get-VM $vmname} catch {$null}) -ne $null)
    {Write-WpfError -Text "VM name exist";Return}
    
    ###########################################
    # Check if ip config is static 
    # True: IP address validation and ping test 
    # False: nothing
    ##########################################
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Validate ip addresses"
    switch ($staticip)
    {
        True
        {
            try
            {
                [ipaddress]$ip
                [ipaddress]$gateway
                $pingip =Test-Connection -Quiet $ip
                $pinggw = Test-Connection -Quiet $gateway
                #if ip is reachable and gateway not then throw error
                if ($pingip -eq $True -or $pinggw -ne $True)
                {Write-WpfError -Text "IP reachable or Gateway not reachable";Return}                
            }
            catch
            {Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)";Return}
        }
        False
        {}
    }
    
    #########################
    # set customization spec 
    # True: static 
    # False: dhcp
    #########################
    $CusSpecName = "Temp"+(Get-Random)    
    switch($staticip)
    {
        True
        {            
            try
            {      
                Get-OSCustomizationSpec $customization | New-OSCustomizationSpec -Name $CusSpecName -Type Persistent
                Get-OSCustomizationSpec -Name $CusSpecName | Set-OSCustomizationSpec -AdminPassword $adminpassword -NamingScheme Fixed -NamingPrefix $hostname
                Get-OSCustomizationSpec -Name $CusSpecName | Get-OSCustomizationNicMapping | where { $_.Position -eq '1'} | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $ip -SubnetMask $subnet -DefaultGateway $gateway -Dns $Config.Settings.VMware.CustomizationSpec.PrimaryDNS,$Config.Settings.VMware.CustomizationSpec.SecondaryDNS
                $CustomizationSpec = Get-OSCustomizationSpec -Name $CusSpecName
            }
            catch
            {
                Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
                Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber) `n";Return
            }
        }
        False
        {
            try
            {                
                Get-OSCustomizationSpec $customization | New-OSCustomizationSpec -Name $CusSpecName -Type Persistent
                Get-OSCustomizationSpec -Name $CusSpecName | Set-OSCustomizationSpec -AdminPassword $adminpassword -NamingScheme Fixed -NamingPrefix $hostname
                Get-OSCustomizationSpec -Name $CusSpecName | Get-OSCustomizationNicMapping | where { $_.Position -eq '1'} | Set-OSCustomizationNicMapping -IpMode UseDhcp
                $CustomizationSpec = Get-OSCustomizationSpec -Name $CusSpecName
            }
            catch
            {
                Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
                Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)";Return
            }
        }
    }
    
    #####################################################
    # Create the vm from template or content library item
    # if: without storage policy (thin / thick)
    # else: with storage policy (thin / thick)
    #####################################################
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Build virtual machine"
    if ([string]::IsNullOrWhiteSpace($policy))
    {
        try
        {
            switch ($template.itemtype) 
            { 
                "ovf" 
                {
                    if ($disktype -eq "Thin")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore $datastore.name -ContentLibraryItem $template.name -DiskStorageFormat Thin -Confirm:$false}
                    elseif ($disktype -eq "Thick eager zeroed")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore $datastore.name -ContentLibraryItem $template.name -DiskStorageFormat EagerZeroedThick -Confirm:$false}
                    elseif ($disktype -eq "Thick lazy zeroed")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore $datastore.name -ContentLibraryItem $template.name -DiskStorageFormat Thick -Confirm:$false}
                    else 
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore $datastore.name -ContentLibraryItem $template.name -Confirm:$false}
                    break
                    
                } 
                default
                {
                    if ($disktype -eq "Thin")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore $datastore.name -Template $template.name -DiskStorageFormat Thin -Confirm:$false}
                    elseif ($disktype -eq "Thick eager zeroed")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore $datastore.name -Template $template.name -DiskStorageFormat EagerZeroedThick -Confirm:$false}
                    elseif ($disktype -eq "Thick lazy zeroed")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore $datastore.name -Template $template.name -DiskStorageFormat Thick -Confirm:$false}
                    else 
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore $datastore.name -Template $template.name -Confirm:$false}
                    break
                }
            }
        }
        catch
        {
            Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
            Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)";Return
        }
    }
    else
    {
        try
        {
            switch ($template.itemtype) 
            { 
                "ovf" 
                {
                    if ($disktype -eq "Thin")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore (Get-SpbmCompatibleStorage -StoragePolicy $policy -CandidateStorage $datastore.name) -ContentLibraryItem $template.name -DiskStorageFormat Thin -Confirm:$false}
                    elseif ($disktype -eq "Thick eager zeroed")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore (Get-SpbmCompatibleStorage -StoragePolicy $policy -CandidateStorage $datastore.name) -ContentLibraryItem $template.name -DiskStorageFormat EagerZeroedThick -Confirm:$false}
                    elseif ($disktype -eq "Thick lazy zeroed")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore (Get-SpbmCompatibleStorage -StoragePolicy $policy -CandidateStorage $datastore.name) -ContentLibraryItem $template.name -DiskStorageFormat Thick -Confirm:$false}
                    else 
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore (Get-SpbmCompatibleStorage -StoragePolicy $policy -CandidateStorage $datastore.name) -ContentLibraryItem $template.name -Confirm:$false}
                    break
                } 
                default
                {
                    if ($disktype -eq "Thin")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore (Get-SpbmCompatibleStorage -StoragePolicy $policy -CandidateStorage $datastore.name) -Template $template.name -DiskStorageFormat Thin -Confirm:$false}
                    elseif ($disktype -eq "Thick eager zeroed")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore (Get-SpbmCompatibleStorage -StoragePolicy $policy -CandidateStorage $datastore.name) -Template $template.name -DiskStorageFormat EagerZeroedThick -Confirm:$false}
                    elseif ($disktype -eq "Thick lazy zeroed")
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore (Get-SpbmCompatibleStorage -StoragePolicy $policy -CandidateStorage $datastore.name) -Template $template.name -DiskStorageFormat Thick -Confirm:$false}
                    else 
                    {New-VM -VMHost $esxhost -Name $vmname -Datastore (Get-SpbmCompatibleStorage -StoragePolicy $policy -CandidateStorage $datastore.name) -Template $template.name -Confirm:$false}
                    break
                }
            }
        }
        catch
        {
            Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
            Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)";Return
        }
    }        
    
    # Get vm object
    try
    {
        Start-Sleep -Seconds 5
        $Vm = Get-VM $vmname
    }
    catch
    {
         Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
         Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)";Return
    } 
    
    # Apply storage policy if selected   
    if ([string]::IsNullOrWhiteSpace($policy)){}
    else
    {
        try{Set-VM -VM $Vm -StoragePolicy (Get-SpbmStoragePolicy | where-object {$_.Name -eq $policy}) -Confirm:$false}
        catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
    }   
    
    #########################################
    # Customize vm hardware
    #########################################
    # Set cpu & cores per socket
    Set-VM -VM $Vm -NumCpu $totalcores -CoresPerSocket $corespersocket -Confirm:$false
    # Set RAM
    Set-VM -VM $Vm -MemoryGB $ram -Confirm:$false
    # Set Network
    $Vm | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $portgroup -Confirm:$false
    $Vm | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected:$true -Confirm:$false

    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Set vm options"
    #############################################################################
    # Loop through each command that are definied in config xml 
    # <vmoptions> and check for xml type "PowerCLI-Cmdlets" because these 
    # are cmdlets
    #############################################################################
    $i=0
    foreach ($VMOption in $Config.Settings.VMOptions.ChildNodes)
    {
        foreach ($VMOptionCmd in $VMOption.ChildNodes)
        {
            $Name = $VMOptionCmd.Name -replace "VMNAME",$vmname
            $Type = $VMOptionCmd.Type
            $VMOptionCommand = "$($VMOptionCmd.Command -replace "VMNAME",$vmname)"
            
            if ((Get-WPFControl -ControlName "VMOptions$i" -PropertyName "IsChecked") -eq "True" -and $Type -eq "PowerCLI")
            {                                  
                Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Config: Run $Name"          
                #$output += "Config: Run $($Name)" 
                
                try{ Invoke-Expression $VMOptionCommand -ErrorAction Stop} #.ScriptOutput.Trim() }
                catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
            }
            $i++
            #Sleep 2 seconds after running command
            Start-Sleep -Seconds 5
        }
    }
    
    #Validate
    $i=0
    foreach ($VMOption in $Config.Settings.VMOptions.ChildNodes)
    {
        foreach ($VMOptionCmd in $VMOption.ChildNodes)
        {
            $Name = $VMOptionCmd.Name -replace "VMNAME",$vmname
            $Type = $VMOptionCmd.Type
            $Validate = $VMOptionCmd.Validate
            $ValidateCommand = $VMOptionCmd.ValidateCommand -replace "VMNAME",$vmname
            
            if ((Get-WPFControl -ControlName "VMOptions$i" -PropertyName "IsChecked") -eq "True" -and $Type -eq "PowerCLI-Cmdlets")
            {
                if ($Validate -eq "True")
                {
                    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Validate: $Name"
                    $output += "Validate: $Name"

                    #Start validation       
                    try{ $output += "Status: "+(Invoke-Expression $ValidateCommand -ErrorAction Stop) }
                    catch{ $output += "$Name Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
                    $output += "---------------------------------------------------------" 
                }
            }
        $i++
        }
    } 

    #Apply os customization
    try {$Vm | Set-VM -OSCustomizationSpec $CustomizationSpec -Confirm:$false}
    catch
    {
        Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
        Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)";Return
    }
    # Start vm
    try {$Vm | Start-VM}
    catch
    {
        Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
        Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)";Return
    }   
    
    ###########################################################
    # Wait max 120 seconds till sysprep is started after poweron
    # stop after 120 seconds and break loop
    ###########################################################
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Customization"       
    $i = 0
    $max = 60
    $Started = "*Started Customization of VM $($Vm.Name)*"
    while ($ViEvent -notlike $Started -and $i -le $max )
    {
        If($i -gt $max) {break}
        Start-Sleep -Seconds 10
        $ViEvent = Get-VIEvent -Start (get-date).AddHours(-1) -Entity $Vm | where {$_.FullFormattedMessage -like "*Started Customization of VM $($Vm.Name)*"}
        $ViEvent = $ViEvent.FullFormattedMessage
        $i++    
    } 
    
    # if no "Started Customization" event then stop execution
    if ([string]::IsNullOrWhiteSpace($ViEvent))
    {
        Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
        Write-WpfError -Text "Customization did not start after 120 seconds";Return
    }
    else {}    
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Customization started"

    ###########################################
    # Wait till sysprep is finished
    # stop after 10 minutes and break loop
    ########################################### 
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Wait 10 minutes for Customization succeeded"
    $i = 0
    $max = 60
    $Succeeded = "*Customization of VM $($Vm.Name) succeeded*"
    while ($ViEvent -notlike $Succeeded -and $i -le $max)
    {
        If($i -gt $max) {break}
        Start-Sleep -Seconds 10
        $ViEvent = Get-VIEvent -Start (get-date).AddHours(-1) -Entity $Vm | where {$_.FullFormattedMessage -like "*Customization of VM $($Vm.Name) succeeded*"}
        $ViEvent = $ViEvent.FullFormattedMessage
        $i++
    }
    
    #if no "Customization succeeded" event then stop execution
    if ([string]::IsNullOrWhiteSpace($ViEvent))
    {
        Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false
        Write-WpfError -Text "Customization did not finish after 300 seconds";Return
    }
    else {}

    #############################################################
    # Wait until vm is ready for all type of opertions
    # GuestOperationsReady must be 6 times True
    ############################################################
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Wait until vmtools are running and OS is ready"
    $y=0
    do
    {
        $ToolsStatus = (Get-VM -Name $vmname).ExtensionData.Guest.ToolsRunningStatus
        $Ready = (Get-VM -Name $vmname).ExtensionData.guest.GuestOperationsReady
        Start-Sleep 30

        if ($Ready -eq $True)
        {$y++}
    }
    while ($ToolsStatus -ne "guestToolsRunning" -and $Ready -ne $True -and $y -ne "6")
    
         
    
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Move to resource pool and folder"  
    # Move to resource pool
    try
    {
        if ([string]::IsNullOrWhiteSpace($resourcepool)){}
        else{ Move-VM -VM $Vm -Destination (Get-ResourcePool -Location $clusterorhost.name -Name $resourcepool) -Confirm:$false -ErrorAction Stop }
    }
    catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" } 
    
    # Move to vm folder
    try
    {
        if ([string]::IsNullOrWhiteSpace($vmfolder.name)){}
        else{ Move-VM -VM $Vm -InventoryLocation $vmfolder.name -Confirm:$false -ErrorAction Stop ; Start-Sleep 30 }
    }
    catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
         
    # Reboot vm if vmtools are old
    $ToolsStatus = (Get-VM -Name $vmname).ExtensionData.Guest.ToolsVersionStatus
    if ($ToolsStatus -ne "guestToolsCurrent")
    {
        Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Build: Reboot vm to update vmtools"
        $Vm | Restart-VMGuest -Confirm:$false
        Start-Sleep 30
    }
    else{}
    
    # Wait until vm is up and ready
    # GuestOperationsReady must be 6 times True
    $y=0
    do
    {
        $ToolsStatus = (Get-VM -Name $vmname).ExtensionData.Guest.ToolsRunningStatus
        $Ready = (Get-VM -Name $vmname).ExtensionData.guest.guestOperationsReady
        Start-Sleep 30
        if ($Ready -eq $True)
        {$y++}
    }
    while ($ToolsStatus -ne "guestToolsRunning" -and $Ready -ne $True -and $y -ne "6")  

    ##############################
    # Send mail with vm parameters
    ##############################
    $Subject = $Config.Settings.Mail.Subject -replace "VMNAME",$vmname
    [string]$Body = $null
    $Body += "VM Name: $($vmname) `n"
    $Body += "Hostname: $($hostname) `n"
    $Body += "IP Adresse: $($ip) `n"
    $Body += "CPUs: $totalcores `n"
    $Body += "RAM: $ram"

    try{ Send-MailMessage -to $To -Subject $Subject -from $Config.Settings.Mail.From -Body $Body -SmtpServer $Config.Settings.Mail.Smtp -Credential $anonCredentials }
    catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }

    # Remove Customization Spec
    Remove-OSCustomizationSpec -OSCustomizationSpec $CusSpecName -Confirm:$false

    # Calculate scribtblock runtime
    $EndDate = Get-Date
    $Duration = New-TimeSpan –Start $StartDate –End $EndDate
    $Text = "{0:mm} minutes and {0:ss} seconds" -f $Duration

    ##########################################
    # Enable clicked button & stop progressbar
    ########################################## 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Build and configure virtual machine, Duration: $Text"
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"   
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $True

    if (![string]::IsNullOrEmpty($output))
    { 
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("$($output | Out-String)",0,"New VM done!",64) | Out-Null
    }      
}

#####################################
# Set vmware tags
#####################################
function Set-Tags {
    # Calculate runtime
    $StartDate = Get-Date

    ############################################
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Set vmware tags"   
    
    # Create output variable for popup
    [array]$output = $null

    ####################################
    # Save Wpf Control value in variable
    ####################################
    $vmname = Get-WPFControl -ControlName "vmname" -PropertyName "Text"
    $ip = Get-WPFControl -ControlName "ip" -PropertyName "Text"
    $description = Get-WPFControl -ControlName "description" -PropertyName "Text"
    $ticket = Get-WPFControl -ControlName "ticket" -PropertyName "Text"
    
    # Get vm object
    $Vm = Get-VM $vmname

    ######################################################
    # Loop through all tags and check if a tag is selected
    # If a tag is selected then assign it to the vm
    ######################################################
    for ($i = 0; $i -lt ($TagCategories.count); $i++) 
    {
        if (![string]::IsNullOrWhiteSpace((Get-WPFControl -ControlName "tag$i" -PropertyName "SelectedItem")))
        {
            $tag = (Get-WPFControl -ControlName "tag$i" -PropertyName "SelectedItem")
            Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Tags: Set tag $tag"
            try{ $Vm | New-TagAssignment -Tag $tag }
            catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
        }
    }    
    
    ######################
    # Set Custom Attribute
    ######################
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Tags: Set custom attributes"
    $BuildDate = Get-Date
    $Notes = "VM Build Date: $BuildDate `n"
    $Notes += "Built by: $env:UserDomain\$env:UserName"
    $Vm | Set-VM -Description $Notes -Confirm:$false        
    New-CustomAttribute -Name "IP-Adresse" -TargetType VirtualMachine -ErrorAction SilentlyContinue
    New-CustomAttribute -Name "VM-Applikation" -TargetType VirtualMachine -ErrorAction SilentlyContinue
    New-CustomAttribute -Name "Ticket" -TargetType VirtualMachine -ErrorAction SilentlyContinue           
    try
    {
        $Vm | Set-Annotation -CustomAttribute "IP-Adresse" -Value $ip
        $Vm | Set-Annotation -CustomAttribute "VM-Applikation" -Value $description
        $Vm | Set-Annotation -CustomAttribute "Ticket" -Value $ticket
    }
    catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" } 

    # Calculate runtime
    $EndDate = Get-Date
    $Duration = New-TimeSpan –Start $StartDate –End $EndDate
    $Text = "{0:mm} minutes and {0:ss} seconds" -f $Duration

    ##########################################
    # Enable clicked button & stop progressbar
    ########################################## 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Set vmware tags, Duration: $Text"  
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $True
    
    if (![string]::IsNullOrEmpty($output))
    { 
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("$($output | Out-String)",0,"Set Tags done!",64) | Out-Null
    }    
}

#####################################
# Post config virtual machine
#####################################
function Invoke-PostConfig {
    # Calculate runtime
    $StartDate = Get-Date

    ############################################    
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True 
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Post config virtual machine"    
    
    # Create output variable for popup
    [array]$output = $null

    ####################################
    # Save Wpf Control value in variable
    ####################################
    $vmname = Get-WPFControl -ControlName "vmname" -PropertyName "Text"
    $hostname = Get-WPFControl -ControlName "hostname" -PropertyName "Text"
    $adminpassword = Get-WPFControl -ControlName "adminpassword" -PropertyName "Password"
    $ticket = Get-WPFControl -ControlName "ticket" -PropertyName "Text"
   
    ######################################################################
    # Loop through each command that are definied in config xml <postconfig>
    # to execute some commands with powershell to modify os parameters, 
    # move vm to ou's or add ad groups
    ###################################################################### 
    $i=0
    foreach ($PostConfigCategory in $Config.Settings.PostConfig.ChildNodes)
    {
        foreach ($PostConfig in $PostConfigCategory.ChildNodes)
        {
            $Name = $PostConfig.Name -replace "HOSTNAME",$hostname
            $Type = $PostConfig.Type
            $Command = "$($PostConfig.Command -replace "HOSTNAME",$hostname -replace "VMNAME",$vmname -replace "TICKET",$ticket)"
            
            if ((Get-WPFControl -ControlName "PostConfig$i" -PropertyName "IsChecked") -eq "True" -and $Type -eq "Invoke-VMScript")
            {                                  
                Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Config: Run $Name"          
                #$output += "Config: Run $($Name)" 
                
                try{ (Invoke-VMScript -VM $vmname -ScriptType Powershell -ScriptText $Command -GuestUser "Administrator" -GuestPassword $adminpassword -Confirm:$false -ErrorAction Stop) } #.ScriptOutput.Trim() }
                catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
            }
            elseif ((Get-WPFControl -ControlName "PostConfig$i" -PropertyName "IsChecked") -eq "True" -and $Type -eq "Powershell")
            {                                
                Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Config: Run $Name"          
                #$output += "Config: Run $($Name)" 

                try{ Invoke-Expression $Command -ErrorAction Stop }
                catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
            }
            $i++
            #Sleep 2 seconds after running command
            Start-Sleep -Seconds 5
        }
    }
    
    #Validate
    $i=0
    foreach ($PostConfigCategory in $Config.Settings.PostConfig.ChildNodes)
    {
        foreach ($PostConfig in $PostConfigCategory.ChildNodes)
        {
            $Name = $PostConfig.Name -replace "HOSTNAME",$hostname
            $Type = $PostConfig.Type
            $Validate = $PostConfig.Validate
            $Command = $PostConfig.ValidateCommand -replace "HOSTNAME",$hostname -replace "VMNAME",$vmname -replace "TICKET",$ticket
            
            if ((Get-WPFControl -ControlName "PostConfig$i" -PropertyName "IsChecked") -eq "True"  -and $Type -eq "Invoke-VMScript")
            {
                if ($Validate -eq "True")
                {
                    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Validate: $Name"
                    $output += "Validate: $Name"

                    #Start validation       
                    try{ $output += "Status: "+(Invoke-VMScript -VM $vmname -ScriptType Powershell -ScriptText $Command  -GuestUser "Administrator" -GuestPassword $adminpassword -Confirm:$false -ErrorAction Stop).ScriptOutput.Trim() }
                    catch{ $output += "$Name Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
                    $output += "---------------------------------------------------------" 
                }
            }
            elseif ((Get-WPFControl -ControlName "PostConfig$i" -PropertyName "IsChecked") -eq "True" -and $Type -eq "Powershell")
            {
                if ($Validate -eq "True")
                {
                    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Validate: $Name"
                    $output += "Validate: $Name"

                    #Start validation       
                    try{ $output += "Status: "+(Invoke-Expression $Command -ErrorAction Stop) }
                    catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
                    $output += "---------------------------------------------------------" 
                }
            }  
        $i++
        }
    } 
    
    # Calculate runtime
    $EndDate = Get-Date
    $Duration = New-TimeSpan –Start $StartDate –End $EndDate
    $Text = "{0:mm} minutes and {0:ss} seconds" -f $Duration

    ##########################################
    # Enable clicked button & stop progressbar
    ########################################## 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Post config virtual machine, Duration: $Text" 
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"      
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $True
    
    if (![string]::IsNullOrEmpty($output))
    { 
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("$(($output | Where-Object {$_} | Out-String).Trim())",0,"Post Config done!",64) | Out-Null
    }   
}

#####################################
# Software Installation
#####################################
function Install-Software {
    # Calculate runtime
    $StartDate = Get-Date

    ############################################
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Software Installation"    
    
    # Create output variable for popup
    [array]$output = $null

    ####################################
    # Save Wpf Control value in variable
    ####################################
    $vmname = Get-WPFControl -ControlName "vmname" -PropertyName "Text"
    $hostname = Get-WPFControl -ControlName "hostname" -PropertyName "Text"
    $adminpassword = Get-WPFControl -ControlName "adminpassword" -PropertyName "Password"
    $ticket = Get-WPFControl -ControlName "ticket" -PropertyName "Text"

    ############################################################################
    # Loop through each software that are definied in config xml <installsoftware> 
    # and install them if checked in gui
    # Copy setup file to vm
    # Uses Invoke-VMScript to start installation
    ############################################################################
    
    $i=0
    foreach ($SoftwareCategory in $Config.Settings.Software.ChildNodes)
    {
        foreach ($Software in $SoftwareCategory.ChildNodes)
        {
            $Name = $Software.Name
            $Type = $Software.Type
            $Source = $Software.Source
            $Destination = $Software.Destination  -replace "HOSTNAME",$hostname -replace "VMNAME",$vmname -replace "TICKET",$ticket
            $Command = $Software.InstallCommand  -replace "HOSTNAME",$hostname -replace "VMNAME",$vmname -replace "TICKET",$tickete
            $RemoveDestination = $Software.RemoveDestination

            if ((Get-WPFControl -ControlName "Software$i" -PropertyName "IsChecked") -eq "True")
            {
                Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Install: $Name"
                #$output += "Install: $Name"

                #Copy setup files to vm
                If ($Source -ne $null -and $Destination -ne $null)
                {
                    try{ Copy-Item $Source -Destination (New-Item -type directory -force $Destination) -Force -Recurse -ErrorAction Stop -Verbose 4>&1 }
                    catch{ $output += "$Name -> Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }          
                    Start-Sleep -Seconds 5
                }

                #Start installation        
                try{ $Script = (Invoke-VMScript -VM $vmname -ScriptType Powershell -ScriptText $Command -GuestUser Administrator -GuestPassword $adminpassword -Confirm:$false -ErrorAction Stop) } #; $output += $Script.ScriptOutput.Trim() ; $output += "Exit Code: "+$Script.ExitCode }
                catch{ $output += "$Name -> Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
                Start-Sleep -Seconds 5

                # Remove setup files
                if ($Destination -ne $null)
                {
                    if ($RemoveDestination -eq "True")
                    {
                        try{Remove-Item -Path $Destination -Recurse -Force -Confirm:$false -ErrorAction Stop -Verbose 4>&1 }
                        catch{ $output += "$Name -> Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
                        Start-Sleep -Seconds 5
                    }
                    #$output += "---------------------------------------------------------"
                    Start-Sleep -Seconds 5
                } 
            }
            $i++
        }
    }
    
    #Wait some time for installation to finish
    Start-Sleep -Seconds 15

    #Validate
    $i=0
    foreach ($SoftwareCategory in $Config.Settings.Software.ChildNodes)
    {
        foreach ($Software in $SoftwareCategory.ChildNodes)
        {
            $Name = $Software.Name
            $Validate = $Software.Validate
            $Command = $Software.ValidateCommand -replace "HOSTNAME",$hostname -replace "VMNAME",$vmname -replace "TICKET",$ticket

            if ((Get-WPFControl -ControlName "Software$i" -PropertyName "IsChecked") -eq "True")
            { 
                if ($Validate -eq "True")
                {
                    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Validate: $Name"
                    $output += "Validate: $Name"

                    #Start validation       
                    try{ $output += "Status: "+(Invoke-VMScript -VM $vmname -ScriptType Powershell -ScriptText $Command -GuestUser Administrator -GuestPassword $adminpassword -Confirm:$false -ErrorAction Stop).ScriptOutput.Trim() }
                    catch{ $output += "$Name Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
                    $output += "---------------------------------------------------------" 
                }
            }
            $i++
        }
    }

    # Calculate runtime
    $EndDate = Get-Date
    $Duration = New-TimeSpan –Start $StartDate –End $EndDate
    $Text = "{0:mm} minutes and {0:ss} seconds" -f $Duration

    ##########################################         
    # Enable clicked button & stop progressbar
    ########################################## 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Software Installation, Duration: $Text" 
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"  
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $True
    
    if (![string]::IsNullOrEmpty($output))
    { 
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("$(($output | Where-Object {$_} | Out-String).Trim())",0,"Software Installation done!",64) | Out-Null
    }
}

#####################################
# NSX config virtual machine
#####################################
function Invoke-NSXConfig {
    # Calculate runtime
    $StartDate = Get-Date

    ############################################    
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True 
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: NSX config virtual machine"    
    
    # Create output variable for popup
    [array]$output = $null

    ####################################
    # Save Wpf Control value in variable
    ####################################
    $vmname = Get-WPFControl -ControlName "vmname" -PropertyName "Text"
   
    ######################################################################
    # Loop through each command that are definied in config xml <nsxconfig>
    ###################################################################### 
    $i=0
    foreach ($NSXConfigCategory in $Config.Settings.NSXConfig.ChildNodes)
    {
        foreach ($NSXConfig in $NSXConfigCategory.ChildNodes)
        {
            $Name = $NSXConfig.Name -replace "VMNAME",$vmname
            $Type = $NSXConfig.Type
            $Command = "$($NSXConfig.Command -replace "VMNAME",$vmname)"
            
            if ((Get-WPFControl -ControlName "NSXConfig$i" -PropertyName "IsChecked") -eq "True" -and $Type -eq "PowerNSX")
            {                                  
                Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Config: Run $Name"          
                #$output += "Config: Run $($Name)" 
                
                try{ Invoke-Expression $Command -ErrorAction Stop} #.ScriptOutput.Trim() }
                catch{ $output += "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
            }
            $i++
            #Sleep 2 seconds after running command
            Start-Sleep -Seconds 5
        }
    }
    
    #Validate
    $i=0
    foreach ($NSXConfigCategory in $Config.Settings.NSXConfig.ChildNodes)
    {
        foreach ($NSXConfig in $NSXConfigCategory.ChildNodes)
        {
            $Name = $NSXConfig.Name -replace "VMNAME",$vmname
            $Type = $NSXConfig.Type
            $Validate = $NSXConfig.Validate
            $Command = $NSXConfig.ValidateCommand -replace "VMNAME",$vmname
            
            if ((Get-WPFControl -ControlName "NSXConfig$i" -PropertyName "IsChecked") -eq "True" -and $Type -eq "PowerNSX")
            {
                if ($Validate -eq "True")
                {
                    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Validate: $Name"
                    $output += "Validate: $Name"

                    #Start validation       
                    try{ $output += "Status: "+(Invoke-Expression $Command -ErrorAction Stop) }
                    catch{ $output += "$Name Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber)" }
                    $output += "---------------------------------------------------------" 
                }
            }
        $i++
        }
    } 
    
    # Calculate runtime
    $EndDate = Get-Date
    $Duration = New-TimeSpan –Start $StartDate –End $EndDate
    $Text = "{0:mm} minutes and {0:ss} seconds" -f $Duration

    ##########################################
    # Enable clicked button & stop progressbar
    ########################################## 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: NSX config virtual machine, Duration: $Text" 
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"      
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $True
    
    if (![string]::IsNullOrEmpty($output))
    { 
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("$(($output | Where-Object {$_} | Out-String).Trim())",0,"NSX Config done!",64) | Out-Null
    }   
}

#####################################
# Getting disks
#####################################
function Get-VMDisk {
    function Write-WpfError
    {
        param([string]$Text)
        Set-WPFControl -ControlName "GetVMDisk" -Property "IsEnabled" -Value $true
        Set-WPFControl -ControlName "progressbar" -Property "IsIndeterminate" -Value $False
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("$($Text)",0,"Error!",64) | Out-Null
    }
    ############################################
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $False 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Get vm disk"

    ####################################
    # Save Wpf Control value in variable
    ####################################
    $vmname = Get-WPFControl -ControlName "vmname1" -PropertyName "Text"
    $hostname = Get-WPFControl -ControlName "hostname1" -PropertyName "Text"

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
    Set-WpfControl -ControlName "vmname1" -PropertyName "Text" -Value $Vm.Name
    Set-WPFControl -ControlName "hostname1" -PropertyName "Text" -Value $Vm.Guest.HostName
    Set-WPFControl -ControlName "os" -PropertyName "Text" -Value $Vm.Guest.OSFullName
    Set-WPFControl -ControlName "driveletter" -PropertyName "ItemsSource" -Value $DiskData
    Set-WPFControl -ControlName "driveletter" -PropertyName "DisplayMemberPath" -Value "DriveLetter" 
    Set-WPFControl -ControlName "driveletter" -PropertyName "SelectedIndex" -Value "0" 
    
    ##########################################         
    # Enable clicked button & stop progressbar
    ########################################## 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $False
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Get vm disk" 
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100" 
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $True    
}

#####################################
# Resize disk
#####################################
function Set-VMDisk {
    function Write-WpfError
    {
        param([string]$Text)
        Set-WPFControl -ControlName "SetVMDisk" -Property "IsEnabled" -Value $true
        Set-WPFControl -ControlName "progressbar" -Property "IsIndeterminate" -Value $False
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup("$($Text)",0,"Error!",64) | Out-Null
    }
    ############################################
    # Disable clicked button & start progressbar
    ############################################
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $False
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $False 
    Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Set vm disk size and extend"

    ####################################
    # Save Wpf Control value in variable
    ####################################
    $Diskname = Get-WPFControl -ControlName "diskname" -PropertyName "Text"
    [int]$VmDiskSize = Get-WPFControl -ControlName "disksize_current" -PropertyName "Text"
    [int]$NewDiskSize = Get-WPFControl -ControlName "disksize_new" -PropertyName "Text"
    $DriveLetter = (Get-WPFControl -ControlName "driveletter" -PropertyName "SelectedItem").DriveLetter

    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Set: Check new disk size"
    if ($NewDiskSize -notmatch "^\d+$" -or $NewDiskSize -le $VmDiskSize)
    {Write-WpfError -Text "New disk size is not a number or less/equal current disk size";Return}
    
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Set: Set vm disk size"            
    try{$Vm | Get-HardDisk | Where-Object {$_.Name -eq $Diskname} | Set-HardDisk -CapacityGB $NewDiskSize -Confirm:$false}
    catch
    {Write-WpfError -Text "Exception: $($_.Exception.Message) `n At line $($_.InvocationInfo.ScriptLineNumber) `n";Return}

    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Set: Extend volume in windows"
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
    Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Set vm disk" 
    Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "100"
    Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $True
    Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $True 
}

#####################################
# Stop script and gui for current user
#####################################
function Stop-Gui
{
    Stop-Process -Id $pid
}
#endregion Functions

#===================================================
# Collect data and customize gui
#===================================================
# Calculate runtime
$StartDate = Get-Date
Clear-Host
Write-Host "########################################################################"
Write-Host "################                                        ################"
Write-Host "################             vBuild + vDisk             ################"
Write-Host "################                                        ################"
Write-Host "########################################################################"
Write-Host ""
Write-Host "=== Connect to vCenter and collect inventory ==="
Import-Inventory
Write-Host ""
Write-Host "=== Customize gui ==="
Add-TagElements -xaml $xaml
Add-WpfElements -xaml $xaml -name "PostConfig"
Add-WpfElements -xaml $xaml -name "Software"
Add-WpfElements -xaml $xaml -name "VMOptions"
Add-WpfElements -xaml $xaml -name "NSXConfig"
Hide-Console

#===================================================
# Create and open window/gui, set events and content
#===================================================
# Show gui
New-WPFWindow -xaml $xaml
# Start progressbar for setting button actions/events and wpf controls
Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Started: Add events, actions, content and set wpf controls" 
Set-WPFControl -ControlName "progressbar" -PropertyName "Value" -Value "0"
Set-WPFControl -ControlName "progressbar" -PropertyName "IsIndeterminate" -Value $True
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
Set-WPFControl -ControlName "progress" -PropertyName "Text" -Value "Finished: Add events, actions, content and set wpf controls, Duration: $Text"

# Enable all buttons
Set-WPFControl -ControlName "ImportVMConfig" -PropertyName "IsEnabled" -Value $True
Set-WPFControl -ControlName "AddNewVM" -PropertyName "IsEnabled" -Value $True
Set-WPFControl -ControlName "SetTags" -PropertyName "IsEnabled" -Value $True
Set-WPFControl -ControlName "InvokePostConfig" -PropertyName "IsEnabled" -Value $True
Set-WPFControl -ControlName "InstallSoftware" -PropertyName "IsEnabled" -Value $True
Set-WPFControl -ControlName "InvokeNSXConfig" -PropertyName "IsEnabled" -Value $True
Set-WPFControl -ControlName "GetVMDisk" -PropertyName "IsEnabled" -Value $True
Set-WPFControl -ControlName "SetVMDisk" -PropertyName "IsEnabled" -Value $True
# Leave the window/gui open
Start-WPFSleep