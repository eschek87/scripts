#requires -version 5
#requires -module Posh-SSH
#requires -module slr
<#
.SYNOPSIS
  Establish a ssh session to an isilon cluster and searches for open file handles that are definied in the search textbox. After selecting the line with the file it is possible to close this file handle.
  Beginning in OneFS 8.0.0, the 'isi smb sessions' and 'isi smb openfiles' commands were changed to use PAPI (Platform Application Programming Interface), 
  and are restricted to the System zone, as they lack the '--zone' option like many other commands that are "zone aware".
  see kb 000497099
  the script will check the onefs version and if it is affected it will use another command and queries the zone id for open file handles: isi_run -z 2 isi_classic smb file list
  So you need to define your zone id.
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
  Creation Date:  03.11.2017
  Purpose/Change: Initial script development
  
.EXAMPLE
  .\close_file_handle.ps1
#>
#---------------------------------------------------------[Define variables]--------------------------------------------------------
#Define your variables here if possible

#isilon clusters
$Clusters = ""

#Hostname where script runs
$ScriptHostname= $env:computername

#OneFS Version which contains the fix
$OneFsVersionFix="8.0.0.5"

#ZoneID
$ZoneId=""
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
		                        <ColumnDefinition Width="Auto" />
		                        <ColumnDefinition Width="Auto" />
	                        </Grid.ColumnDefinitions>
    
                            <Label Name="l_clusters" Grid.Row="0" Grid.Column="0" Content="Select isilon cluster" />   
	                        <Label Name="l_root" Grid.Row="1" Grid.Column="0" Content="Enter root user" />                           
                            <Label Name="l_password" Grid.Row="2" Grid.Column="0" Content="Enter root password" />   
                            <Label Name="l_file" Grid.Row="3" Grid.Column="0" Content="Enter file name to search for" /> 

                            <ComboBox Name="cb_clusters" Grid.Row="0" Grid.Column="1" Margin="3" />
                            <TextBox Name="tb_root" Grid.Row="1" Grid.Column="1" Margin="3" />                         
                            <PasswordBox Name="tb_rootpw" Grid.Row="2" Grid.Column="1" PasswordChar="*" Margin="3" />
                            <TextBox Name="tb_file" Grid.Row="3" Grid.Column="1" Margin="3" /> 

                            <DataGrid Name="dg_details" Grid.Row="5" Grid.Column="1" HorizontalAlignment="Left" Margin="3" Height="200" Width="500" AlternationCount="1" IsReadOnly="True" SelectionMode="Single"/>

                            <Button Name="b_search" Grid.Row="4" Grid.Column="0" HorizontalAlignment="left" MinWidth="100" Margin="3" Content="Search" />
                            <Button Name="b_close" Grid.Row="6" Grid.Column="0" HorizontalAlignment="left" MinWidth="100" Margin="3" Content="Close File Handle" />
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
$syncHash.Window.Title = 'Close file handle'

foreach ($StackPanel in $StackPanels)
{$StackPanel.Children[0].Margin = '10,10,10,30'}

####################################
#Load vCenters and update type in ComboBox
####################################
$syncHash.cb_clusters.ItemsSource = $Clusters

############################################
#Open file
############################################
function getopenfiles
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
    $Runspace.SessionStateProxy.SetVariable("file",$syncHash.tb_file.Text)

    $code = {
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = ""})
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 25})    
    $password = ConvertTo-SecureString "$password" -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ("$user", $password)

    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Connect to Isilon Cluster"})
    New-SSHSession -ComputerName $cluster -AcceptKey -Credential $creds -Force | Out-Null
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 50})

    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Search for open file handles"})

    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Checking OneFS Version"})
    $OneFsVersionCurrent=(Invoke-SSHCommand -SessionId 0 -TimeOut 600 -Command "uname -r").Output
    $OneFsVersionCurrent = $OneFsVersionCurrent -replace "v",""
    $filelist = New-Object System.Collections.ArrayList
    $Check = [version]"$OneFsVersionCurrent" -ge [version]"$OneFsVersionFix"

    if ($Check -eq $true)
    {        
        [System.Collections.ArrayList]$openfiles= (Invoke-SSHCommand -SessionId 0 -TimeOut 600 -Command "isi_for_array -s isi smb openfiles list --format csv -v | grep -i '$file'").Output
        $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 75})
        $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Build the list with open file handles"})
        
        foreach ($openfile in $openfiles)
        {
            #split by comma but exclude quotes
            $openfile = $openfile -split(',(?=(?:[^"]*"[^"]*")*[^"]*$)')

            #gibt den Isilon Node aus
            $node = $openfile[0] -replace (" ",",") | %{$_.split(",")[0]} | foreach-object { $_ -replace (":","") }

            #gibt das File ID aus
            $id = $openfile[0] -replace (" ",",") | %{$_.split(",")[1]}

            #gibt den Pfad der Datei aus
            $path = $openfile[1]

            #gibt den User aus der die Datei geöffnet hat
            $username = $openfile[2]
 
            #build csv with own header for datagridview output
            $obj = new-object PSObject
            $obj | add-member -membertype NoteProperty -name "Node" -value "$node"
            $obj | add-member -membertype NoteProperty -name "ID" -value "$id"
            $obj | add-member -membertype NoteProperty -name "Path" -value "$path"
            $obj | add-member -membertype NoteProperty -name "User" -value "$username"
            $filelist.AddRange(@($obj))
        }
    }
    else
    {
        [System.Collections.ArrayList]$openfiles = (Invoke-SSHCommand -SessionId 0 -TimeOut 600 -Command "isi_for_array -s isi_run -z $ZoneId isi_classic smb file list | egrep '$file' -B 2 -A 3").Output    
        $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 75})
        $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Build the list with open file handles"})
        $count = $openfiles.Count

        switch ($count)
        {
            {$_ -gt 6}
                {
                $openfiles.Remove("--")
                $a = Split-Every $openfiles 6
                for ($i=0; $i -lt $a.length; $i++)
                    {
                    $node = $a[$i][0] -replace ":","," | %{$_.split(",")[0]}
                    $id = $a[$i][1] -replace ":","," | %{$_.split(",")[2]}
                    $path = $a[$i][2] -replace ":","," -replace "\\","/" | %{$_.split(",")[3]}
                    $username = $a[$i][3] -replace ":","," | %{$_.split(",")[2]}
                    $nmrlocks = $a[$i][4] -replace ":","," | %{$_.split(",")[2]}
                    $permissons = $a[$i][5] -replace ":","," | %{$_.split(",")[2]}
                    $obj = new-object PSObject
                    $obj | add-member -membertype NoteProperty -name "Node" -value "$node"
                    $obj | add-member -membertype NoteProperty -name "ID" -value "$id"
                    $obj | add-member -membertype NoteProperty -name "Path" -value "$path"
                    $obj | add-member -membertype NoteProperty -name "Username" -value "$username"
                    $obj | add-member -membertype NoteProperty -name "Number of locks" -value "$nmrlocks"
                    $obj | add-member -membertype NoteProperty -name "Permissions" -value "$permissons"
                    $filelist.AddRange(@($obj))
                    }
                }
            {$_ -le 6}
                {
                $a = $openfiles
                $node = $a[0] -replace ":","," | %{$_.split(",")[0]}
                $id = $a[1] -replace ":","," | %{$_.split(",")[2]}
                $path = $a[2] -replace ":","," -replace "\\","/" | %{$_.split(",")[3]}
                $username = $a[3] -replace ":","," | %{$_.split(",")[2]}
                $nmrlocks = $a[4] -replace ":","," | %{$_.split(",")[2]}
                $permissons = $a[5] -replace ":","," | %{$_.split(",")[2]}
                $obj = new-object PSObject
                $obj | add-member -membertype NoteProperty -name "Node" -value "$node"
                $obj | add-member -membertype NoteProperty -name "ID" -value "$id"
                $obj | add-member -membertype NoteProperty -name "Path" -value "$path"
                $obj | add-member -membertype NoteProperty -name "Username" -value "$username"
                $obj | add-member -membertype NoteProperty -name "Number of locks" -value "$nmrlocks"
                $obj | add-member -membertype NoteProperty -name "Permissions" -value "$permissons"
                $filelist.AddRange(@($obj))
                }
        }
    } 

                              
    $syncHash.Window.Dispatcher.invoke([action]{
    $syncHash.dg_details.clear() 
    $syncHash.dg_details.ItemsSource = $filelist
    $syncHash.dg_details.IsReadOnly = $true
    })
    Remove-SSHSession -SessionID 0 -Verbose
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
function closeopenfile
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
    $Runspace.SessionStateProxy.SetVariable("node",$syncHash.dg_details.SelectedValue.Node)
    $Runspace.SessionStateProxy.SetVariable("id",$syncHash.dg_details.SelectedValue.ID)

    $code = {
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = ""})
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 25})
    $password = ConvertTo-SecureString "$password" -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ("$user", $password)
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Connect to Isilon Cluster"})
    New-SSHSession -ComputerName $cluster -AcceptKey -Credential $creds -Force | Out-Null
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.sb_progressbar.Value = 50})
    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.tb_progress.Text = "Close open file handle"})
    Invoke-SSHCommand -SessionID 0 -Command "isi_for_array -n $node -s isi_run -z 2 isi_classic smb file close --file-id=$id"
    Remove-SSHSession -SessionID 0 -Verbose    
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
    $syncHash.tb_file.Clear()
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
$syncHash.b_search.add_Click({getopenfiles})
$syncHash.b_close.add_Click({closeopenfile})
$syncHash.b_clear.add_Click({clearboxes})
$syncHash.b_quit.add_Click({quit})
$syncHash.Window.ShowDialog() | Out-Null