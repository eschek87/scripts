#requires -version 5
#requires -module slr
<#
.SYNOPSIS
  Query onefs isilon for existing quotas with the name from the search textbox and let you modify the quota after selecting the correct line. It uses the onefs papi with powershell invoke-restmethod.
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
  Creation Date:  13.11.2017
  Purpose/Change: Initial script development
  
.EXAMPLE
  .\modify_quota.ps1
#>
#---------------------------------------------------------[Define variables]--------------------------------------------------------
#Define your variables here if possible

#isilon clusters
$Clusters = ""

#Hostname where script runs
$ScriptHostname= $env:computername

#quota unit types
$Type = "GB","TB"
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
#Set error action to silently continue
#$ErrorActionPreference = "SilentlyContinue"

#Set debug action to continue if you want debug messages at console
$DebugPreference="Continue"

#Determine path of script
$scriptDir = $(Split-Path $MyInvocation.MyCommand.Definition)
#Get filename of script and use the same name for the logfile without file extension
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptName = $scriptName.Replace(".ps1","")
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
$OutputPath=$scriptDir
$OutputName = "$Today"+"_"+"$ScriptName.csv"
$OutputFile = Join-Path -Path $OutputPath -ChildPath $OutputName
#-----------------------------------------------------------[Start Logging]------------------------------------------------------------
Log-Start -LogPath $LogPath -LogName $LogName -ScriptVersion $ScriptVersion
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Write -LogPath $LogFile -LineValue "Execution starts"
##################################
#initalize wpf
##################################
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -Assembly System.Windows.Forms

##################################
#xaml definition
##################################
[xml]$xaml = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Name="Window" WindowStartupLocation="CenterScreen"
        MinWidth="300" MinHeight="200"
        Width="Auto" Height="Auto" ShowInTaskbar="True">
        <DockPanel LastChildFill="False">
                <StatusBar Name="sb" DockPanel.Dock="Bottom" VerticalAlignment="Bottom">
                    <StatusBar.ItemsPanel>
                        <ItemsPanelTemplate>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="100" />
                                    <ColumnDefinition Width="Auto" />
                                    <ColumnDefinition Width="260" />
                                    <ColumnDefinition Width="Auto" />
                                    <ColumnDefinition Width="200" />
                                </Grid.ColumnDefinitions>
                            </Grid>
                        </ItemsPanelTemplate>
                    </StatusBar.ItemsPanel>
                    <StatusBarItem Grid.Column="0">
                        <TextBlock>Loading...</TextBlock>
                    </StatusBarItem>
                    <Separator Grid.Column="1" />
                    <StatusBarItem Grid.Column="2">
                        <ProgressBar Name="sb_progressbar" Width="260" Height="15" Value="0" Margin="2" />
                    </StatusBarItem>
                    <Separator Grid.Column="3" />
                    <StatusBarItem Grid.Column="4">
                        <TextBlock Name="tb_progress" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis" Padding="2,0"></TextBlock>
                    </StatusBarItem>
                </StatusBar>

                    <StackPanel Name="sp" xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
                        <Grid>
	                        <Grid.RowDefinitions>
		                        <RowDefinition Height="*" />
		                        <RowDefinition Height="*" />
		                        <RowDefinition Height="*" />
		                        <RowDefinition Height="*" />
                                <RowDefinition Height="*" />
                                <RowDefinition Height="*" />
                                <RowDefinition Height="*" />
                                <RowDefinition Height="*" />
                                <RowDefinition Height="*" />
                                <RowDefinition Height="*" />
                                <RowDefinition Height="*" />
	                        </Grid.RowDefinitions>
	                        <Grid.ColumnDefinitions>
		                        <ColumnDefinition Width="200" />
		                        <ColumnDefinition Width="550" />
                                <ColumnDefinition Width="50" />
	                        </Grid.ColumnDefinitions>
    
                            <Label Name="l_clusters" Grid.Row="0" Grid.Column="0" Content="Select isilon cluster" />   
	                        <Label Name="l_root" Grid.Row="1" Grid.Column="0" Content="Enter root user" />                           
                            <Label Name="l_password" Grid.Row="2" Grid.Column="0" Content="Enter root password" />   
                            <Label Name="l_search" Grid.Row="3" Grid.Column="0" Content="Enter folder name to search a quota for" />
                            <Label Name="l_quota" Grid.Row="6" Grid.Column="1" Content="Enter new quota size and select unit" HorizontalAlignment="left" />

                            <ComboBox Name="cb_clusters" Grid.Row="0" Grid.Column="1" Margin="3" />
                            <TextBox Name="tb_root" Grid.Row="1" Grid.Column="1" Margin="3" />                         
                            <PasswordBox Name="tb_rootpw" Grid.Row="2" Grid.Column="1" PasswordChar="*" Margin="3" />
                            <TextBox Name="tb_search" Grid.Row="3" Grid.Column="1" Margin="3" /> 
                            <TextBox Name="tb_quota" Grid.Row="6" Grid.Column="1" Margin="3" Width="100" HorizontalAlignment="right" /> 
                            <ComboBox Name="cb_unit" Grid.Row="6" Grid.Column="2" Margin="3" />

                            <DataGrid Name="dg_details" Grid.Row="5" Grid.Column="1" HorizontalAlignment="Left" Margin="3" Height="200" Width="500" AlternationCount="1" IsReadOnly="True" SelectionMode="Single"/>

                            <Button Name="b_search" Grid.Row="4" Grid.Column="0" HorizontalAlignment="left" MinWidth="100" Margin="3" Content="Search" />
                            <Button Name="b_change" Grid.Row="7" Grid.Column="1" HorizontalAlignment="left" MinWidth="100" Margin="3" Content="Change quota" />
                            <Button Name="b_clear" Grid.Row="7" Grid.Column="0" HorizontalAlignment="left" MinWidth="100" Margin="3" Content="Clear" />
                            <Button Name="b_quit" Grid.Row="8" Grid.Column="0" HorizontalAlignment="left" MinWidth="100" Margin="3" Content="Quit" />
                        </Grid>
                    </StackPanel>
        </DockPanel>
</Window>
"@

##################################
#read xaml and convert to controls
##################################
$syncHash = [hashtable]::Synchronized(@{})
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$syncHash.Window=[Windows.Markup.XamlReader]::Load($reader)

#============================================
# Store Form Objects in PowerShell
#============================================
$xaml.SelectNodes("//*[@Name]") | %{ $syncHash."$($_.Name)" = $syncHash.Window.FindName($_.Name)}
$StackPanels = $syncHash.Window.FindName("sp_*")

###################################
#Create and configure window
###################################
$syncHash.Window.SizeToContent = 'WidthAndHeight'
$syncHash.Window.ResizeMode = 'NoResize'
$syncHash.Window.Title = 'Modify Quota'

foreach ($StackPanel in $StackPanels)
{$StackPanel.Children[0].Margin = '10,10,10,30'}

####################################
#Load and update ComboBox
####################################
$syncHash.cb_clusters.ItemsSource = $Clusters
$syncHash.cb_unit.ItemsSource = $Type

############################################
#Open file
############################################
function getquota
{
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash) 
    $Runspace.SessionStateProxy.SetVariable("cluster",$syncHash.cb_clusters.SelectedItem)
    $Runspace.SessionStateProxy.SetVariable("LogFile",$LogFile)
    $Runspace.SessionStateProxy.SetVariable("password",$syncHash.tb_rootpw.Password)
    $Runspace.SessionStateProxy.SetVariable("user",$syncHash.tb_root.Text)
    $Runspace.SessionStateProxy.SetVariable("Search",$syncHash.tb_search.Text)

    $code = {
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = ""})     
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 50})
    $AllQuotas = IsiPapi -User $user -Password $password -IsilonIp $cluster -ResourceUrl "/platform/1/quota/quotas" -Method Get
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Search for quotas"})
    $Quotas = $AllQuotas.quotas | Where-Object {$_.path -like "*$Search*"}  
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 75})

    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Build the list with found quotas"})
    $filelist = New-Object System.Collections.ArrayList     
    foreach ($Quota in $Quotas)
        {
        $QuotaPath = $Quota.path
        $QuotaHard = ([math]::round($quota.thresholds.hard/1GB,2)) -replace "\.",","
        $QuotaUsage = ([math]::round($quota.usage.logical/1GB,2)) -replace "\.",","
        $QuotaId = $Quota.id
 
        #build csv with own header for datagridview output
        $obj = new-object PSObject
        $obj | add-member -membertype NoteProperty -name "Path" -value "$QuotaPath"
        $obj | add-member -membertype NoteProperty -name "Quota in GB" -value "$QuotaHard"
        $obj | add-member -membertype NoteProperty -name "Usage in GB" -value "$QuotaUsage"
        $obj | add-member -membertype NoteProperty -name "ID" -value "$QuotaId"
        $filelist.AddRange(@($obj))
        }
                              
    $syncHash.Window.Dispatcher.invoke([action]{
    $syncHash.dg_details.clear() 
    $syncHash.dg_details.ItemsSource = $filelist
    $syncHash.dg_details.IsReadOnly = $true
    $syncHash.dg_details.Columns[3].Visible = $false
    })
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 100}) 
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Finished"})
    $PSinstanceRunspace.EndInvoke($RunspaceJob)
    $Runspace.Close()
    $PSinstanceRunspace.Dispose()  
    }
    $PSinstanceRunspace = [powershell]::Create().AddScript($code)
    $PSinstanceRunspace.Runspace = $Runspace
    $RunspaceJob = $PSinstanceRunspace.BeginInvoke()
}
############################################
#Close file
############################################
function modifyquota
{
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash) 
    $Runspace.SessionStateProxy.SetVariable("cluster",$syncHash.cb_clusters.SelectedItem)
    $Runspace.SessionStateProxy.SetVariable("LogFile",$LogFile)
    $Runspace.SessionStateProxy.SetVariable("user",$syncHash.tb_root.Text)
    $Runspace.SessionStateProxy.SetVariable("password",$syncHash.tb_rootpw.Password)
    $Runspace.SessionStateProxy.SetVariable("quota",$syncHash.tb_quota.Text)
    $Runspace.SessionStateProxy.SetVariable("unit",$syncHash.cb_unit.SelectedItem)
    $Runspace.SessionStateProxy.SetVariable("id",$syncHash.dg_details.SelectedValue.ID)

    $code = {
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = ""})
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 25})        
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 50})
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Modify selected quota"})
    switch ($unit)
    {
        "GB" {[long]$quota = [long]$quota*1GB}
        "TB" {[long]$quota = [long]$quota*1TB}
    }  

    $QuotaObject = @"
    {"thresholds":{"hard":$quota}}
"@

    IsiPapi -User $user -Password $password -IsilonIp $cluster -ResourceUrl "/platform/1/quota/quotas/$id" -Method Put -JsonObject $QuotaObject

    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 100}) 
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Finished"})
    $PSinstanceRunspace.EndInvoke($RunspaceJob)
    $Runspace.Close()
    $PSinstanceRunspace.Dispose()  
    }
    $PSinstanceRunspace = [powershell]::Create().AddScript($code)
    $PSinstanceRunspace.Runspace = $Runspace
    $RunspaceJob = $PSinstanceRunspace.BeginInvoke()
}
############################################
#Clear all
############################################
function clearboxes
{
    $syncHash.tb_root.Clear()
    $syncHash.tb_rootpw.Clear()
    $syncHash.tb_search.Clear()
    $syncHash.dg_details.clear() 
}  

############################################
#Quit
############################################
function quit
{
    $syncHash.Window.close()
    Log-Finish -LogPath $LogFile
}
$syncHash.b_search.add_Click({getquota})
$syncHash.b_change.add_Click({modifyquota})
$syncHash.b_clear.add_Click({clearboxes})
$syncHash.b_quit.add_Click({quit})
$syncHash.Window.ShowDialog() | Out-Null