#########################
#region Logging functions
#########################
Function Log-Start{
  <#
  .SYNOPSIS
    Creates log file
  .DESCRIPTION
    Creates log file with path and name that is passed. Checks if log file exists, and if it does - moves it to directory oldlogs and creates a new one. Delete logfiles in oldlogs which are older than 7 days
    Once created, writes initial logging data
  .PARAMETER LogPath
    Mandatory. Path of where log is to be created. Example: C:\Windows\Temp
  .PARAMETER LogName
    Mandatory. Name of log file to be created. Example: Test_Script.log     
  .PARAMETER ScriptVersion
    Mandatory. Version of the running script which will be written in the log. Example: 1.5
  .INPUTS
    Parameters above
  .OUTPUTS
    Log file created
  .NOTES
    Version:        1.0
    Author:         Luca Sturlese
    Creation Date:  10/05/12
    Purpose/Change: Initial function development
    Version:        1.1
    Author:         Luca Sturlese
    Creation Date:  19/05/12
    Purpose/Change: Added debug mode support
    Version:        1.2
    Author:         Stephan Liebner
    Creation Date:  24/11/15
    Purpose/Change: comment line to remove old logs, add line to move old logs to oldlogs directory, change datetime settings from $([DateTime]::Now) to get-date -format "d.M.yyyy HH:mm:ss"
    Version:        1.3
    Author:         Stephan Liebner
    Creation Date:  14/12/15
    Purpose/Change: checks if logfiles are more than 7 days old from script and delete the oldest
  .EXAMPLE
    Log-Start -LogPath "C:\Windows\Temp" -LogName "Test_Script.log" -ScriptVersion "1.5"
  #>
    
  [CmdletBinding()]
  
  Param(
  [Parameter(Mandatory=$true)][string]$LogPath,
  [Parameter(Mandatory=$true)][string]$LogName,
  [Parameter(Mandatory=$true)][string]$ScriptVersion)
  
  Process{
    #Build fullpath to logfile
    $LogFullPath = Join-Path -Path $LogPath -ChildPath $LogName    
    #Folder in script directory for old log files
    $OldLogPath = $LogPath + "\" + "oldlogs"

    #################################################
    #Check if directory oldlogs exist, else create it
    #################################################
    If((Test-Path -Path $OldLogPath))
    {
    
        #Check if Logfile exist
        if (Test-Path -Path $LogFullPath)
        {
            #Find logfile and move it to oldlogs    
            Get-ChildItem $LogFullPath | Move-Item -destination $OldLogPath        
            #Build full path to old logfile for renaming
            $FullOldLogPath=Join-Path -Path $OldLogPath -ChildPath $LogName

            #Rename file and add file last access time in front (creation time did not work due to filesystem tunneling)
            [string]$CreationTime=(Get-ChildItem -Path $OldLogPath -File $LogName).LastAccessTime.ToString('d-M-yyyy_HH-mm-ss')
            $NewLogName=$CreationTime+"_"+$LogName

            #Check if logfile exist in oldlogs and rename it
            if (Test-Path -Path $FullOldLogPath)
            {
                Rename-Item $FullOldLogPath $NewLogName
                }
            else {}
        }
        else {}
    }
    else
    {
        #Create oldlogs directory
        $NewDir = New-Item $OldLogPath -type directory
        #Check if Logfile exist
        if (Test-Path -Path $LogFullPath)
        {
            #Find logfile and move it to oldlogs 
            Get-ChildItem $LogFullPath | Move-Item -destination $OldLogPath
            #Build full path to old logfile for renaming
            $FullOldLogPath=Join-Path -Path $OldLogPath -ChildPath $LogName
            #Rename file and add file last access time in front (creation time did not work due to filesystem tunneling)
            [string]$CreationTime=(Get-ChildItem -Path $OldLogPath -File $LogName).LastAccessTime.ToString('d-M-yyyy_HH-mm-ss')
            $NewLogName=$CreationTime+"_"+$LogName
            #Check if logfile exist in oldlogs and rename it
            if (Test-Path -Path $FullOldLogPath)
            {
                Rename-Item $FullOldLogPath $NewLogName}
            else {}
        }
        else {}
    }

    ##################################################################
    #Checks if logfiles are more than 7 days old and delete the oldest
    ##################################################################
    $Limit=(Get-Date).AddDays(-7)
    Get-ChildItem $OldLogPath -Filter *.log| Where-Object {$_.Name -like "*$LogName*" -and $_.LastWriteTime -lt $Limit} | Remove-Item -Force

    #####################################
    #Create new logfile and start logging
    #####################################
    $NewLogFile = New-Item -Path $LogPath -Name $LogName -ItemType File   
    Add-Content -Path $LogFullPath -Value "========================================================================================================="
    Add-Content -Path $LogFullPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [START] Starting Log. Running script version [$ScriptVersion]."
    Add-Content -Path $LogFullPath -Value "========================================================================================================="
  
    ###############################
    #Write to screen for debug mode
    ###############################
    write-debug "========================================================================================================="
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [START] Starting Log. Running script version [$ScriptVersion]."
    write-debug "========================================================================================================="
  }
}

Function Log-Write{
  <#
  .SYNOPSIS
    Writes to a log file
  .DESCRIPTION
    Appends a new line to the end of the specified log file  
  .PARAMETER LogPath
    Mandatory. Full path of the log file you want to write to. Example: C:\Windows\Temp\Test_Script.log 
  .PARAMETER LineValue
    Mandatory. The string that you want to write to the log      
  .INPUTS
    Parameters above
  .OUTPUTS
    None
  .NOTES
    Version:        1.0
    Author:         Luca Sturlese
    Creation Date:  10/05/12
    Purpose/Change: Initial function development
  
    Version:        1.1
    Author:         Luca Sturlese
    Creation Date:  19/05/12
    Purpose/Change: Added debug mode support
  .EXAMPLE
    Log-Write -LogPath "C:\Windows\Temp\Test_Script.log" -LineValue "This is a new line which I am appending to the end of the log file."
  #>
  
  [CmdletBinding()]
  
  Param(
  [Parameter(Mandatory=$true)][string]$LogPath, 
  [Parameter(Mandatory=$true)][string]$LineValue
  )
  
  Process{
    #####################################
    #Write to logfile
    #####################################
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [INFO] $LineValue"
  
    ###############################
    #Write to screen for debug mode
    ###############################
    write-host "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [INFO] $LineValue"
  }
}

Function Log-Warning{
  <#
  .SYNOPSIS
    Writes an warning to a log file
  .DESCRIPTION
    Writes the passed error to a new line at the end of the specified log file 
  .PARAMETER LogPath
    Mandatory. Full path of the log file you want to write to. Example: C:\Windows\Temp\Test_Script.log  
  .PARAMETER ErrorDesc
    Mandatory. The description of the error you want to pass (use $Error[0] for the last error in the error record) 
  .INPUTS
    Parameters above
  .OUTPUTS
    None
  .NOTES
    Version:        1.0
    Author:         Luca Sturlese
    Creation Date:  10/05/12
    Purpose/Change: Initial function development
    
    Version:        1.1
    Author:         Luca Sturlese
    Creation Date:  19/05/12
    Purpose/Change: Added debug mode support. Added -ExitGracefully parameter functionality

    Version:        1.2
    Author:         Stephan Liebner
    Creation Date:  27/12/15
    Purpose/Change: change the way of displaying errors and accept errors

  .EXAMPLE
    Log-Warning -LogPath "C:\Windows\Temp\Test_Script.log" -ErrorDesc $_.Exception -ExitGracefully $True
  #>

  [CmdletBinding()]
  
  Param(
  [Parameter(Mandatory=$true)][string]$LogPath,
  #[Parameter(Mandatory=$true)][string]$LineValue,
  [Parameter(Mandatory=$true)]$ErrorDesc)
  #,
  #[Parameter(Mandatory=$true)]$ErrorDesc)
  
  Process{
    
    ###################################
    #Define variables for error logging
    ###################################
    $ErrorSev=$ErrorDesc.Exception.Severity
    $ErrorID=$ErrorDesc.FullyQualifiedErrorId
    $ErrorExcep=$ErrorDesc.Exception.Message
    $ErrorCom=$ErrorDesc.InvocationInfo.MyCommand.Name
    $ErrorScp=$ErrorDesc.InvocationInfo.ScriptName
    $ErrorLn=$ErrorDesc.InvocationInfo.ScriptLineNumber
    $ErrorOLn=$ErrorDesc.InvocationInfo.OffsetInLine

    #####################################
    #Write error to logfile
    #####################################
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [WARNING] Error Severity: $ErrorSev" 
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [WARNING] Error FullyQualifiedErrorId: $ErrorID"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [WARNING] Error Message: $ErrorExcep"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [WARNING] Error in CMDlet: $ErrorCom"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [WARNING] Error in ScriptName: $ErrorScp"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [WARNING] Error in ScriptLineNumber: $ErrorLn"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [WARNING] Error in OffsetInLine: $ErrorOLn"
    Add-Content -Path $LogPath -Value ""
  
    ###############################
    #Write to screen for debug mode
    ###############################
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error Severity: $ErrorSev" 
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error FullyQualifiedErrorId: $ErrorID" 
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error Message: $ErrorExcep"
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error in CMDlet: $ErrorCom"
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error in ScriptName: $ErrorScp"
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error in ScriptLineNumber: $ErrorLn"
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error in OffsetInLine: $ErrorOLn"
  }
}

Function Log-Error{
  <#
  .SYNOPSIS
    Writes an error to a log file
  .DESCRIPTION
    Writes the passed error to a new line at the end of the specified log file 
  .PARAMETER LogPath
    Mandatory. Full path of the log file you want to write to. Example: C:\Windows\Temp\Test_Script.log  
  .PARAMETER ErrorDesc
    Mandatory. The description of the error you want to pass (use $Error[0] for the last error in the error record) 
  .INPUTS
    Parameters above
  .OUTPUTS
    None
  .NOTES
    Version:        1.0
    Author:         Luca Sturlese
    Creation Date:  10/05/12
    Purpose/Change: Initial function development
    
    Version:        1.1
    Author:         Luca Sturlese
    Creation Date:  19/05/12
    Purpose/Change: Added debug mode support. Added -ExitGracefully parameter functionality

    Version:        1.2
    Author:         Stephan Liebner
    Creation Date:  27/12/15
    Purpose/Change: change the way of displaying errors and accept errors

  .EXAMPLE
    Log-Error -LogPath "C:\Windows\Temp\Test_Script.log" -ErrorDesc $_.Exception -ExitGracefully $True
  #>

  [CmdletBinding()]
  
  Param(
  [Parameter(Mandatory=$true)][string]$LogPath,
  [Parameter(Mandatory=$true)]$ErrorDesc)
  
  Process{
    
    ###################################
    #Define variables for error logging
    ###################################
    $ErrorSev=$ErrorDesc.Exception.Severity
    $ErrorID=$ErrorDesc.FullyQualifiedErrorId
    $ErrorExcep=$ErrorDesc.Exception.Message
    $ErrorCom=$ErrorDesc.InvocationInfo.MyCommand.Name
    $ErrorScp=$ErrorDesc.InvocationInfo.ScriptName
    $ErrorLn=$ErrorDesc.InvocationInfo.ScriptLineNumber
    $ErrorOLn=$ErrorDesc.InvocationInfo.OffsetInLine

    #####################################
    #Write error to logfile
    #####################################
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [ERROR] Error Severity: $ErrorSev" 
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [ERROR] Error FullyQualifiedErrorId: $ErrorID"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [ERROR] Error Message: $ErrorExcep"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [ERROR] Error in CMDlet: $ErrorCom"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [ERROR] Error in ScriptName: $ErrorScp"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [ERROR] Error in ScriptLineNumber: $ErrorLn"
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [ERROR] Error in OffsetInLine: $ErrorOLn"
    Add-Content -Path $LogPath -Value ""
  
    ###############################
    #Write to screen for debug mode
    ###############################
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error Severity: $ErrorSev" 
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error FullyQualifiedErrorId: $ErrorID" 
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error Message: $ErrorExcep"
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error in CMDlet: $ErrorCom"
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error in ScriptName: $ErrorScp"
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error in ScriptLineNumber: $ErrorLn"
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] Error in OffsetInLine: $ErrorOLn"
  }
}

Function Log-Finish{
  <#
  .SYNOPSIS
    Write closing logging data & exit
  .DESCRIPTION
    Writes finishing logging data to specified log and then exits the calling script 
  .PARAMETER LogPath
    Mandatory. Full path of the log file you want to write finishing data to. Example: C:\Windows\Temp\Test_Script.log 
  .INPUTS
    Parameters above
  .OUTPUTS
    None
  .NOTES
    Version:        1.0
    Author:         Luca Sturlese
    Creation Date:  10/05/12
    Purpose/Change: Initial function development
    
    Version:        1.1
    Author:         Luca Sturlese
    Creation Date:  19/05/12
    Purpose/Change: Added debug mode support
  
  .EXAMPLE
    Log-Finish -LogPath "C:\Windows\Temp\Test_Script.log"
  #>
  
  [CmdletBinding()]
  
  Param(
  [Parameter(Mandatory=$true)][string]$LogPath
  )
  
  Process{

    #####################################
    #Finish logfile
    #####################################
    Add-Content -Path $LogPath -Value "========================================================================================================="
    Add-Content -Path $LogPath -Value "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [FINISH] Stopping log"
    Add-Content -Path $LogPath -Value "========================================================================================================="
  
    ###############################
    #Write to screen for debug mode
    ###############################
    write-debug "========================================================================================================="
    write-debug "[$(get-date -format 'd.M.yyyy HH:mm:ss')] [FINISH] Stopping log"
    write-debug "========================================================================================================="  
  }
}

Function Log-Email{
  <#
  .SYNOPSIS
    Emails log file to list of recipients
  .DESCRIPTION
    Emails the contents of the specified log file to a list of recipients 
  .PARAMETER LogPath
    Mandatory. Full path of the log file you want to email. Example: C:\Windows\Temp\Test_Script.log  
  .PARAMETER EmailFrom
    Mandatory. The email addresses of who you want to send the email from. Example: "admin@9to5IT.com"
  .PARAMETER EmailTo
    Mandatory. The email addresses of where to send the email to. Seperate multiple emails by ",". Example: "admin@9to5IT.com, test@test.com" 
  .PARAMETER EmailSubject
    Mandatory. The subject of the email you want to send. Example: "Cool Script - [" + (Get-Date).ToShortDateString() + "]"
  .INPUTS
    Parameters above
  .OUTPUTS
    Email sent to the list of addresses specified
  .NOTES
    Version:        1.0
    Author:         Luca Sturlese
    Creation Date:  05.10.12
    Purpose/Change: Initial function development
  .EXAMPLE
    Log-Email -LogPath "C:\Windows\Temp\Test_Script.log" -EmailFrom "admin@9to5IT.com" -EmailTo "admin@9to5IT.com, test@test.com" -EmailSubject "Cool Script - [" + (Get-Date).ToShortDateString() + "]" -SmtpServer "mydomain.com"
  #>
  
  [CmdletBinding()]
  
  Param(
  [Parameter(Mandatory=$true)][string]$LogPath,
  [Parameter(Mandatory=$true)][string]$EmailFrom,
  [Parameter(Mandatory=$true)][string]$EmailTo,
  [Parameter(Mandatory=$true)][string]$EmailSubject,
  [Parameter(Mandatory=$true)][string]$SmtpServer
  )
  
  Process{
    Try{
      $sBody = (Get-Content $LogPath | out-string)
      
      #Create SMTP object and send email
      $sSmtpServer = "$SmtpServer"
      $oSmtp = new-object Net.Mail.SmtpClient($sSmtpServer)
      $oSmtp.Send($EmailFrom, $EmailTo, $EmailSubject, $sBody)
      Exit 0
    }   
    Catch{Exit 1} 
  }
}
############################
#endregion Logging functions
############################

#########################
#region General functions
#########################
Function remove-logs{
Param($myscript_path)
New-Item $myscript_path\archiv -type directory -EA SilentlyContinue
Get-ChildItem $myscript_path -recurse -include *.log, *.csv, *.html, *.txt | Move-Item -destination $myscript_path\archiv
}

Function get-consolecommand{
$ext = $env:pathext -split ';' -replace '\.','*.'
$desc = @{N='Description'; e={$_.FileVersionInfo.FileDescription}}
Get-Command -Name $ext | Select-Object Name, Extension, $desc | Out-GridView
}

Function Split-Every($list, $count=4) {
    $aggregateList = @()

    $blocks = [Math]::Floor($list.Count / $count)
    $leftOver = $list.Count % $count
    for($i=0; $i -lt $blocks; $i++) {
        $end = $count * ($i + 1) - 1

        $aggregateList += @(,$list[$start..$end])
        $start = $end + 1
    }    
    if($leftOver -gt 0) {
        $aggregateList += @(,$list[$start..($end+$leftOver)])
    }

    $aggregateList    
    }

function Get-WebRequestTable
{
param(
    [Parameter(Mandatory = $true)]

    $HTML,

   

    [Parameter(Mandatory = $true)]

    [int] $TableNumber

)

## Extract the tables out of the web request
$tables = @($HTML.getElementsByTagName("table"))

$table = $tables[$TableNumber]

$titles = @()

$rows = @($table.Rows)

## Go through all of the rows in the table

foreach($row in $rows)

{

    $cells = @($row.Cells)

   

    ## If we've found a table header, remember its titles

    if($cells[0].tagName -eq "TH")

    {

        $titles = @($cells | % { ("" + $_.InnerText).Trim() })

        continue

    }

    ## If we haven't found any table headers, make up names "P1", "P2", etc.

    if(-not $titles)

    {

        $titles = @(1..($cells.Count + 2) | % { "P$_" })

    }

    ## Now go through the cells in the the row. For each, try to find the

    ## title that represents that column and create a hashtable mapping those

    ## titles to content

    $resultObject = [Ordered] @{}

    for($counter = 0; $counter -lt $cells.Count; $counter++)

    {

        $title = $titles[$counter]

        if(-not $title) { continue }

       

        $resultObject[$title] = ("" + $cells[$counter].InnerText).Trim()

    }

    ## And finally cast that hashtable to a PSCustomObject

    [PSCustomObject] $resultObject

}
}

#Function Definitions
# Credits to - http://powershell.cz/2013/04/04/hide-and-show-console-window-from-gui/
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

function Show-Console 
{
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 5)
}

function Hide-Console 
{
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)
}
############################
#endregion General functions
############################

#####################
#region Form function
#####################
function Import-ComboBox{
<#
    .SYNOPSIS
        This functions helps you load items into a ComboBox.
    .DESCRIPTION
        Use this function to dynamically load items into the ComboBox control.
    .PARAMETER  ComboBox
        The ComboBox control you want to add items to.
    .PARAMETER  Items
        The object or objects you wish to load into the ComboBox's Items collection.  
    .PARAMETER  Append
        Adds the item(s) to the ComboBox without clearing the Items collection.
#>
    Param (
        [Parameter(Mandatory=$true)][Windows.Controls.ComboBox]$ComboBox,
        [Parameter(Mandatory=$true)]$Items,
        [Parameter(Mandatory=$false)][string]$DisplayMember,
        [switch]$Append
    )
    
    if(-not $Append)
    {
        $comboBox.Items.Clear()    
    }
    
    if($Items -is [Array])
    {
        foreach ($Item in $Items){
        $comboBox.Items.Add($Item)
        }
    }
    else
    {
        $comboBox.Items.Add($Items)    
    }
}
########################
#endregion Form function
########################

#######################
#region ip address test
#######################
function Test-IPAddressString{
<#
        .SYNOPSIS
        Tests to see if an IP address string is a valid address and can determine
        if IP Address is responding on network.

        .DESCRIPTION
        Implements the .Net.IPAddress classes to validate that the string provided
        can parse into an IP Address. If the parse is successful, the function returns
        boolean $true unless the -FailIfInUse switch is provided.
        
        If -FailIfInUse is specified, a $true is only returned if the IP Address
        does not respond to a ping three times.

        This function supports the -Verbose switch as well.
        
        .PARAMETER IPaddressString
        This is a string value representing the address that you want to test.
        
        This value can be passed either from pipeline or as a parameter.
        
        .PARAMETER FailIfInUse 
        This is a switch parameter. Specifying this in the parameter list will
        cause the IP Address, if successfully parsed, to attempt to be pinged.
        
        A successful ping result will result in a $false value being returned
        if this switch is used.
        
        
        .EXAMPLE
        Test-IPAddressString -IPAddressString "192.168.1.1"
        
        Using full parameter name

        .EXAMPLE
        Test-IPAddressString "192.168.1.1" -FailIfInUse
        
        Using Positional parameters and specifiying to fail test if IP Address responds to ping.
        
        .EXAMPLE
        ("192.168.1.1", "192.123456", "IsThisAnIP") | Test-IPAddressString -Verbose
        
        Passing serveral potential IP Address strings to the function through the pipeline. 
        
        FailIfInUse is ommitted, so no ping attempts will be made on valid IP Addresses.
        
        This function supports the verbose switch. Using this switch will provide you with
        several indicators of progress through the process.
        
        .NOTES
        
        Author:    Kyle Neier
        Blog: http://sqldbamusings.blogspot.com
        Twitter: Kyle_Neier
        
        .LINK
        http://sqldbamusings.blogspot.com/2012/04/powershell-validating-ip-address.html
    #>

    param(
    [parameter(
            Mandatory=$true, 
            Position=0,
            ValueFromPipeline= $true
        )]
        [string]$IPaddressString,
    [parameter(
            Mandatory=$false, 
            Position=1,
            ValueFromPipeline= $false
        )]
        [switch]$FailIfInUse
    )

    process
    {
        [System.Net.IPAddress]$IPAddressObject = $null    
        if([System.Net.IPAddress]::tryparse($IPaddressString,[ref]$IPAddressObject) -and
             $IPaddressString -eq $IPAddressObject.tostring())
        {
            Write-Verbose "$IPaddressString successfully parsed."
            if($FailIfInUse -eq $true)
            {
                $Pinger = new-object System.Net.NetworkInformation.Ping
                $p = 1
                $p_max = 3
                do 
                {
                    Write-Verbose "Attempting to ping $IPaddressString - Attempt $p of $p_max"
                    $PingResult = $Pinger.Send("$IPaddressString")
                    Write-Verbose "Connection Result: $($PingResult.Status)"
                    $p++
                    Start-Sleep -Milliseconds 500

                } until ($PingResult.Status -eq "Success" -or $p -gt $p_max)

                if($PingResult.Status -eq "Success")
                {
                    Write-Verbose "The IP Address $IPAddressString parsed successfully but is responding to ping."
                    Write-Output $false
                }
                else
                {
                    Write-Verbose "The IP Address $IPAddressString parsed successfully and is not responding to ping."
                    Write-Output $true
                }
            }
            else
            {
                Write-Verbose "The IP Address $IPAddressString parsed successfull - No ping attempt made."
                Write-Output $true
            }
        
        }
        else
        {
            Write-Verbose "The IP Address $IPAddressString could not be parsed."
            Write-Output $false
        }
    }
}
#######################
#endregion ip address test
#######################

#######################
#region emc isilon
#######################
Function IsiPapi
{
    Param(
      [Parameter(Mandatory=$true)][string]$User,
      [Parameter(Mandatory=$true)][string]$Password,
      [Parameter(Mandatory=$true)][string]$IsilonIp,
      [Parameter(Mandatory=$true)][string]$ResourceUrl,
      [Parameter(Mandatory=$true)][string]$Method,
      [Parameter(Mandatory=$false)][string]$JsonObject
      )
    
    # With a default cert you would normally see a cert error (code from blogs.msdn.com)
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;

    public class TrustAll : ICertificatePolicy {
    public TrustAll() {}
    public bool CheckValidationResult(
        ServicePoint sPoint, X509Certificate cert,
        WebRequest req, int problem) {
        return true;
    }
}
"@
    [System.Net.ServicePointManager]::CertificatePolicy = new-object TrustAll
    [System.Net.ServicePointManager]::SecurityProtocol = 'TLS11','TLS12','ssl3'
    #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
    
    # create header
    $EncodedAuthorization = [System.Text.Encoding]::UTF8.GetBytes($User + ':' + $Password)
    $EncodedPassword = [System.Convert]::ToBase64String($EncodedAuthorization)
    $Headers = @{"Authorization"="Basic $($EncodedPassword)"}     
    
    # create Uri
    $BaseUrl = 'https://' + $IsilonIp +":8080" 
    $Uri = $BaseUrl + $ResourceUrl
    switch ($Method)
    {
        "Get" {$IsiObject = Invoke-RestMethod -Uri $Uri -Method Get -Headers $Headers}
        "Put" {$IsiObject = Invoke-RestMethod -Uri $Uri -Method Put -Headers $Headers -Body $JsonObject -ContentType "application/json; charset=utf-8"}
        "Post" {$IsiObject = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $JsonObject -ContentType "application/json; charset=utf-8"}
        "Delete" {$IsiObject = Invoke-RestMethod -Uri $Uri -Method Delete -Headers $Headers -Body $JsonObject -ContentType "application/json; charset=utf-8"}
    }
    $IsiObject
}
#######################
#endregion emc isilon
#######################

#######################
#region superna eyelgass
#######################
Function EyeglassApi
{
    Param(
      [Parameter(Mandatory=$true)][string]$Apikey,
      [Parameter(Mandatory=$true)][string]$EyeglassIP,
      [Parameter(Mandatory=$true)][string]$ResourceUrl,
      [Parameter(Mandatory=$true)][string]$Method,
      [Parameter(Mandatory=$false)][string]$JsonObject
      )
    
    # With a default cert you would normally see a cert error (code from blogs.msdn.com)
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;

    public class TrustAll : ICertificatePolicy {
    public TrustAll() {}
    public bool CheckValidationResult(
        ServicePoint sPoint, X509Certificate cert,
        WebRequest req, int problem) {
        return true;
    }
}
"@
    [System.Net.ServicePointManager]::CertificatePolicy = new-object TrustAll
    [System.Net.ServicePointManager]::SecurityProtocol = 'TLS11','TLS12','ssl3'
    #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
    
    # create header
    $Headers = @{“api_key"= $apiKey}   
    
    # create Uri
    $BaseUrl = 'https://' + $EyeglassIP 
    $Uri = $BaseUrl + $ResourceUrl
    switch ($Method)
    {
        "Get" {$EyeglassObject = Invoke-RestMethod -Uri $Uri -Method Get -Headers $Headers -ContentType "application/json"}
        "Put" {$EyeglassObject = Invoke-RestMethod -Uri $Uri -Method Put -Headers $Headers -Body $JsonObject -ContentType "application/json; charset=utf-8"}
        "Post" {$EyeglassObject = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $JsonObject -ContentType "application/json; charset=utf-8"}
        "Delete" {$EyeglassObject = Invoke-RestMethod -Uri $Uri -Method Delete -Headers $Headers -Body $JsonObject -ContentType "application/json; charset=utf-8"}
    }
    $EyeglassObject
}
#######################
#endregion emc isilon
#######################

#######################
#region vmware
#######################
function Get-Stat2 {
<#
.SYNOPSIS  Retrieve vSphere statistics
.DESCRIPTION The function is an alternative to the Get-Stat cmdlet.
  It's primary use is to provide functionality that is missing
  from the Get-Stat cmdlet.
.NOTES  Author:  Luc Dekens
.PARAMETER Entity
  Specify the VIObject for which you want to retrieve statistics
  This needs to be an SDK object
.PARAMETER Start
  Start of the interval for which to retrive statistics
.PARAMETER Finish
  End of the interval for which to retrive statistics
.PARAMETER Stat
  The identifiers of the metrics to retrieve
.PARAMETER Instance
  The instance property of the statistics to retrieve
.PARAMETER Interval
  Specify for which interval you want to retrieve statistics.
  Allowed values are RT, HI1, HI2, HI3 and HI4
.PARAMETER MaxSamples
  The maximum number of samples for each metric
.PARAMETER QueryMetrics
  Switch to indicate that the function should return the available
  metrics for the Entity specified
.PARAMETER QueryInstances
  Switch to indicate that the function should return the valid instances
  for a specific Entity and Stat
.EXAMPLE
  PS> Get-Stat2 -Entity $vm.Extensiondata -Stat "cpu.usage.average" -Interval "RT"
#>
 
  [CmdletBinding()]
  param (
  [parameter(Mandatory = $true,  ValueFromPipeline = $true)]
  [PSObject]$Entity,
  [DateTime]$Start,
  [DateTime]$Finish,
  [String[]]$Stat,
  [String]$Instance = "",
  [ValidateSet("RT","HI1","HI2","HI3","HI4")]
  [String]$Interval = "RT",
  [int]$MaxSamples,
  [switch]$QueryMetrics,
  [switch]$QueryInstances)
 
  # Test if entity is valid
  $EntityType = $Entity.GetType().Name
 
  if(!(("HostSystem",
        "VirtualMachine",
        "ClusterComputeResource",
        "Datastore",
        "ResourcePool") -contains $EntityType)) {
    Throw "-Entity parameters should be of type HostSystem, VirtualMachine, ClusterComputeResource, Datastore or ResourcePool"
  }
 
  $perfMgr = Get-View (Get-View ServiceInstance).content.perfManager
 
  # Create performance counter hashtable
  $pcTable = New-Object Hashtable
  $keyTable = New-Object Hashtable
  foreach($pC in $perfMgr.PerfCounter){
    if($pC.Level -ne 99){
      if(!$pctable.containskey($pC.GroupInfo.Key + "." + $pC.NameInfo.Key + "." + $pC.RollupType)){
        $pctable.Add(($pC.GroupInfo.Key + "." + $pC.NameInfo.Key + "." + $pC.RollupType),$pC.Key)
        $keyTable.Add($pC.Key, $pC)
      }
    }
  }
 
  # Test for a valid $Interval
  if($Interval.ToString().Split(" ").count -gt 1){
    Throw "Only 1 interval allowed."
  }
 
  $intervalTab = @{"RT"=$null;"HI1"=0;"HI2"=1;"HI3"=2;"HI4"=3}
  $dsValidIntervals = "HI2","HI3","HI4"
  $intervalIndex = $intervalTab[$Interval]
 
  if($EntityType -ne "datastore"){
    if($Interval -eq "RT"){
      $numinterval = 20
    }
    else{
      $numinterval = $perfMgr.HistoricalInterval[$intervalIndex].SamplingPeriod
    }
  }
  else{
    if($dsValidIntervals -contains $Interval){
      $numinterval = $null
      if(!$Start){
        $Start = (Get-Date).AddSeconds($perfMgr.HistoricalInterval[$intervalIndex].SamplingPeriod - $perfMgr.HistoricalInterval[$intervalIndex].Length)
      }
      if(!$Finish){
        $Finish = Get-Date
      }
    }
    else{
      Throw "-Interval parameter $Interval is invalid for datastore metrics."
    }
  }
 
  # Test if QueryMetrics is given
  if($QueryMetrics){
    $metrics = $perfMgr.QueryAvailablePerfMetric($Entity.MoRef,$null,$null,$numinterval)
    $metricslist = @()
    foreach($pmId in $metrics){
      $pC = $keyTable[$pmId.CounterId]
      $metricslist += New-Object PSObject -Property @{
        Group = $pC.GroupInfo.Key
        Name = $pC.NameInfo.Key
        Rollup = $pC.RollupType
        Id = $pC.Key
        Level = $pC.Level
        Type = $pC.StatsType
        Unit = $pC.UnitInfo.Key
      }
    }
    return ($metricslist | Sort-Object -unique -property Group,Name,Rollup)
  }
 
  # Test if start is valid
  if($Start -ne $null -and $Start -ne ""){
    if($Start.gettype().name -ne "DateTime") {
      Throw "-Start parameter should be a DateTime value"
    }
  }
 
  # Test if finish is valid
  if($Finish -ne $null -and $Finish -ne ""){
    if($Finish.gettype().name -ne "DateTime") {
      Throw "-Start parameter should be a DateTime value"
    }
  }
 
  # Test start-finish interval
  if($Start -ne $null -and $Finish -ne $null -and $Start -ge $Finish){
    Throw "-Start time should be 'older' than -Finish time."
  }
 
  # Test if stat is valid
  $unitarray = @()
  $InstancesList = @()
 
  foreach($st in $Stat){
    if($pcTable[$st] -eq $null){
      Throw "-Stat parameter $st is invalid."
    }
    $pcInfo = $perfMgr.QueryPerfCounter($pcTable[$st])
    $unitarray += $pcInfo[0].UnitInfo.Key
    $metricId = $perfMgr.QueryAvailablePerfMetric($Entity.MoRef,$null,$null,$numinterval)
 
    # Test if QueryInstances in given
    if($QueryInstances){
      $mKey = $pcTable[$st]
      foreach($metric in $metricId){
        if($metric.CounterId -eq $mKey){
          $InstancesList += New-Object PSObject -Property @{
            Stat = $st
            Instance = $metric.Instance
          }
        }
      }
    }
    else{
      # Test if instance is valid
      $found = $false
      $validInstances = @()
      foreach($metric in $metricId){
        if($metric.CounterId -eq $pcTable[$st]){
          if($metric.Instance -eq "") {$cInstance = '""'} else {$cInstance = $metric.Instance}
          $validInstances += $cInstance
          if($Instance -eq $metric.Instance){$found = $true}
        }
      }
      if(!$found){
        Throw "-Instance parameter invalid for requested stat: $st.`nValid values are: $validInstances"
      }
    }
  }
  if($QueryInstances){
    return $InstancesList
  }
 
  $PQSpec = New-Object VMware.Vim.PerfQuerySpec
  $PQSpec.entity = $Entity.MoRef
  $PQSpec.Format = "normal"
  $PQSpec.IntervalId = $numinterval
  $PQSpec.MetricId = @()
  foreach($st in $Stat){
    $PMId = New-Object VMware.Vim.PerfMetricId
    $PMId.counterId = $pcTable[$st]
    if($Instance -ne $null){
      $PMId.instance = $Instance
    }
    $PQSpec.MetricId += $PMId
  }
  $PQSpec.StartTime = $Start
  $PQSpec.EndTime = $Finish
  if($MaxSamples -eq 0 -or $numinterval -eq 20){
    $PQSpec.maxSample = $null
  }
  else{
    $PQSpec.MaxSample = $MaxSamples
  }
  $Stats = $perfMgr.QueryPerf($PQSpec)
 
  # No data available
  if($Stats[0].Value -eq $null) {return $null}
 
  # Extract data to custom object and return as array
  $data = @()
  for($i = 0; $i -lt $Stats[0].SampleInfo.Count; $i ++ ){
    for($j = 0; $j -lt $Stat.Count; $j ++ ){
      $data += New-Object PSObject -Property @{
        CounterId = $Stats[0].Value[$j].Id.CounterId
        CounterName = $Stat[$j]
        Instance = $Stats[0].Value[$j].Id.Instance
        Timestamp = $Stats[0].SampleInfo[$i].Timestamp
        Interval = $Stats[0].SampleInfo[$i].Interval
        Value = $Stats[0].Value[$j].Value[$i]
        Unit = $unitarray[$j]
        Entity = $Entity.Name
        EntityId = $Entity.MoRef.ToString()
      }
    }
  }
  if($MaxSamples -eq 0){
    $data | Sort-Object -Property Timestamp -Descending
  }
  else{
    $data | Sort-Object -Property Timestamp -Descending | select -First $MaxSamples
  }
}

function Get-FolderPath{
<#
.SYNOPSIS
	Returns the folderpath for a folder
.DESCRIPTION
	The function will return the complete folderpath for
	a given folder, optionally with the "hidden" folders
	included. The function also indicats if it is a "blue"
	or "yellow" folder.
.NOTES
	Authors:	Luc Dekens
.PARAMETER Folder
	On or more folders
.PARAMETER ShowHidden
	Switch to specify if "hidden" folders should be included
	in the returned path. The default is $false.
.EXAMPLE
	PS> Get-FolderPath -Folder (Get-Folder -Name "MyFolder")
.EXAMPLE
	PS> Get-Folder | Get-FolderPath -ShowHidden:$true
#>
 
	param(
	[parameter(valuefrompipeline = $true,
	position = 0,
	HelpMessage = "Enter a folder")]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl[]]$Folder,
	[switch]$ShowHidden = $false
	)
 
	begin{
		$excludedNames = "Datacenters","vm","host"
	}
 
	process{
		$Folder | %{
			$fld = $_.Extensiondata
			$fldType = "yellow"
			if($fld.ChildType -contains "VirtualMachine"){
				$fldType = "blue"
			}
			$path = $fld.Name
			while($fld.Parent){
				$fld = Get-View $fld.Parent
				if((!$ShowHidden -and $excludedNames -notcontains $fld.Name) -or $ShowHidden){
					$path = $fld.Name + "\" + $path
				}
			}
			$row = "" | Select Name,Path,Type
			$row.Name = $_.Name
			$row.Path = $path
			$row.Type = $fldType
			$row
		}
	}
}

Function Connect-VMwareAPI {
    Param(
      [Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$Credentials,
      [Parameter(Mandatory=$true)][string]$Server,
      [Parameter(Mandatory=$true)][string]$AuthURL,
      [Parameter(Mandatory=$true)][ValidateSet("vROPS","vRLI","NSX","vRNI")][string]$Type
      )

    if ($Type -eq "vROPS")
    {
        $AuthJSON =@{
            "username" = $Credentials.Username
            "password" = $Credentials.GetNetworkCredential().Password
            }
        $requestBody = ConvertTo-Json $AuthJSON

        $SessionResponse = Invoke-RestMethod -Method POST -Uri $AuthURL -Body $requestBody -ContentType "application/json"
         $SessionHeader = @{"Authorization"="vRealizeOpsToken"+$SessionResponse.'auth-token'.token
        "Accept"="application/json"}
        $SessionHeader
    }
    elseif ($Type -eq "vRLI")
    {
        $AuthJSON =@{
            "username" = $Credentials.Username
            "password" = $Credentials.GetNetworkCredential().Password
            }
        $requestBody = ConvertTo-Json $AuthJSON

        $SessionResponse = Invoke-RestMethod -Method POST -Uri $AuthURL -Body $requestBody -ContentType "application/json"
        $SessionHeader = @{"Authorization"="Bearer "+$SessionResponse.sessionId
        "Accept"="application/json"}
        $SessionHeader
    }
    elseif ($Type -eq "NSX")
    {
        #$AuthJSON =@{
        #    "username" = $Credentials.Username
        #    "password" = $Credentials.GetNetworkCredential().Password
        #    }
        #$requestBody = ConvertTo-Json $AuthJSON

        #$SessionResponse = Invoke-RestMethod -Method POST -Uri $AuthURL -Body $requestBody -ContentType "application/json"
        #$SessionHeader = @{"Authorization"="NetworkInsight "+$SessionResponse.'auth-token'.token
        #"Accept"="application/json"}
        #$SessionHeader
    }
    elseif ($Type -eq "vRNI")
    {
        $AuthJSON =@{
            "username" = $Credentials.Username
            "password" = $Credentials.GetNetworkCredential().Password
            }

        $AuthJSON.domain =@{
            "domain_type" = "LOCAL"
            "value" = "local"
            }
        $requestBody = ConvertTo-Json $AuthJSON

        $SessionResponse = Invoke-RestMethod -Method POST -Uri $AuthURL -Body $requestBody -ContentType "application/json"
        $SessionHeader = @{"Authorization"="NetworkInsight "+$SessionResponse.token
        "Accept"="application/json"}
        $SessionHeader
    }
}

Function Get-VCVersion {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function extracts the vCenter Server (Windows or VCSA) build from your env
        and maps it to https://kb.vmware.com/kb/2143838 to retrieve the version and release date
    .EXAMPLE
        Get-VCVersion
#>
    param(
        [Parameter(Mandatory=$false)][VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$Server
    )

    if(-not $Server) {
        $Server = $global:DefaultVIServer
    }
    $OsType = $Server.ExtensionData.Content.about.OsType -replace "-.+"

    # Pulled from https://www.virten.net/repo/vcenterReleases.json
    $vCenterReleases = @{}
    foreach ( $webdata in ((Invoke-RestMethod -Uri https://www.virten.net/repo/vcenterReleases.json).data.vcenterReleases | Where-Object {$_.OSType -like $OsType}) )
    {
    $Build = $webdata.Build
    $friendlyName = $webdata.fullName
    $releaseDate = $webdata.releaseDate
    $vCenterReleases.add($Build,"$friendlyName`,$releaseDate")
    }

    $vcBuildNumber = $Server.Build
    $vcName = $Server.Name
    $vcOS = $Server.ExtensionData.Content.About.OsType
    $vcVersion,$vcRelDate = "Unknown","Unknown"

    if($vCenterReleases.ContainsKey($vcBuildNumber)) {
        ($vcVersion,$vcRelDate) = $vCenterReleases[$vcBuildNumber].split(",")
    }

    $tmp = [pscustomobject] @{
        Name = $vcName;
        Build = $vcBuildNumber;
        Version = $vcVersion;
        OS = $vcOS;
        ReleaseDate = $vcRelDate;
    }
    $tmp
}

Function Get-ESXiVersion {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function extracts the ESXi build from your env and maps it to
        https://kb.vmware.com/kb/2143832 to extract the version and release date
    .PARAMETER ClusterName
        Name of the vSphere Cluster to retrieve ESXi version information
    .EXAMPLE
        Get-ESXiVersion -ClusterName Cluster
#>
    param(
        [Parameter(Mandatory=$true)][string]$ClusterOrHostName,
        [Parameter(Mandatory=$true)][string]$Type
    )

    # Pulled from https://www.virten.net/repo/esxiReleases.json
    $ESXiReleases = @{}
    foreach ( $webdata in ((Invoke-RestMethod -Uri https://www.virten.net/repo/esxiReleases.json).data.esxiReleases) )
    {
    $Build = $webdata.build
    $friendlyName = $webdata.friendlyName
    $releaseDate = $webdata.releaseDate
    $ESXiReleases.add($Build,"$friendlyName`,$releaseDate")
    }

    if ($Type -eq "Host")
    {
        $ClusterOrHost = Get-VMHost -Name $ClusterOrHostName -ErrorAction SilentlyContinue
        #$Data = $ClusterOrHost
    }
    elseif ($Type -eq "Cluster")
    {
        $ClusterOrHost = Get-Cluster -Name $ClusterOrHostName -ErrorAction SilentlyContinue
        #$Data = $ClusterOrHost.ExtensionData.Host
    }
    if($ClusterOrHostName -eq $null) {
        Write-Host -ForegroundColor Red "Error: Unable to find Cluster/Host $ClusterOrHostName ..."
        break
    }

    $results = @()
    foreach ($vmhost in $ClusterOrHost) 
    {
        $vmhost_view = Get-View $vmhost -Property Name, Config, ConfigManager.ImageConfigManager

        $esxiName = $vmhost_view.name
        $esxiBuild = $vmhost_view.Config.Product.Build
        $esxiVersionNumber = $vmhost_view.Config.Product.Version
        
        $esxiVersion,$esxiRelDate,$esxiOrigInstallDate = "Unknown","Unknown","N/A"
        if($ESXiReleases.ContainsKey($esxiBuild)) {
            ($esxiVersion,$esxiRelDate) = $ESXiReleases[$esxiBuild].split(",")
        }

        # Install Date API was only added in 6.5
        if($esxiVersionNumber -eq "6.5.0") {
            $imageMgr = Get-View $vmhost_view.ConfigManager.ImageConfigManager
            $esxiOrigInstallDate = $imageMgr.installDate()
        }

        $tmp = [pscustomobject] @{
            Name = $esxiName;
            Build = $esxiBuild;
            Version = $esxiVersion;
            ReleaseDate = $esxiRelDate;
            OriginalInstallDate = $esxiOrigInstallDate;
        }
        $results+=$tmp
    }
    $results
}

Function Get-VSANVersion {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives the vSAN software version for both VC/ESXi
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VSANVersion -Cluster VSAN-Cluster
#>
   param(
        [Parameter(Mandatory=$true)][String]$Cluster
    )
    $vchs = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
    $cluster_view = (Get-Cluster -Name $Cluster).ExtensionData.MoRef
    $results = $vchs.VsanVcClusterQueryVerifyHealthSystemVersions($cluster_view)

    #Write-Host "`nVC Version:"$results.VcVersion
    $results.HostResults | Select Hostname, Version
}
#######################
#endregion vmware
#######################

#######################
#region graphite
#######################
function Send-ToGraphite
{
    param(
        [string]$carbonServer,
        [string]$carbonServerPort,
        [string[]]$metrics
    )
      try
      {
            $socket = New-Object System.Net.Sockets.TCPClient 
            $socket.connect($carbonServer, $carbonServerPort) 
            $stream = $socket.GetStream() 
            $writer = new-object System.IO.StreamWriter($stream)
            foreach ($metric in $metrics)
            {
                #Write-Host $metric
                $newMetric = $metric.TrimEnd()
                $writer.WriteLine($newMetric) 
            }
			$writer.flush()
			$writer.close()
			$stream.close()
			$socket.close()
        }
        catch
        {
            #Log-Error -LogPath $LogFile -ErrorDesc $Error[0] -ExitGracefully $False
        }
}
#######################
#endregion graphite
#######################

#######################
#region influxdb
#######################

function Send-ToInfluxDb
{
        param(
        [string]$InfluxHost,
        [string]$InfluxHostPort,
        [string]$InfluxDbName,
        [string]$MeasurementName,
        [string]$Tags,
	    [array]$MetricValue,
        [switch]$addTimestamp,
        [switch]$IsArray
	    )
    # Set null value for timestamp
    $TimeStamp = $null
    
    # Build Uri and send timestamp with precision level second
    $uri = "http://$InfluxHost" + ":" + "$InfluxHostPort/write?&db=$InfluxDbName&precision=s"
    
    # Create timestamp if requested in UTC
    If ($addTimestamp)
    {
        $TimeStamp = (Get-Date).ToUniversalTime()
    	$TimeStamp = [int][double]::Parse((Get-Date $TimeStamp -UFormat %s))
    }
    
    if ($IsArray)
    {
        Invoke-RestMethod -Uri $uri -Method Post -Body ($MetricValue -join "`n")
    }
    else
    {
        Invoke-RestMethod -Uri $uri -Method Post -Body "$MeasurementName,$Tags $MetricValue $TimeStamp"
    }
}
#######################
#endregion influxdb
#######################

#######################
#region runspace
#######################
function Create-Runspace{
    param(
    $scriptblock,
    [hashtable]$WpfHashtable,
    [hashtable]$CfgHashtable,
    $RunspaceName
    )

    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
    $Runspace.Name = $RunspaceName
    $WpfHashtable.Keys | Foreach  {
        $KeyName = $WpfHashtable[$_].Name
        switch ($WpfHashtable[$_].GetType().Name)
        {    
            ComboBox
            {
                $RsVariable = New-Object PSCustomObject
                $RsVariable | Add-Member -type NoteProperty -name Name -Value $KeyName
                $RsVariable | Add-Member -type NoteProperty -name Type -Value $WpfHashtable."$($KeyName)".GetType().Name
                $RsVariable | Add-Member -type NoteProperty -name Value -Value $WpfHashtable."$($KeyName)".SelectedItem
                $RsVariable | Add-Member -type NoteProperty -name TabItem -Value $WpfHashtable."$($KeyName)".Parent.Parent.Header
                $Runspace.SessionStateProxy.SetVariable($RsVariable.Name,$RsVariable)
                break
            }
            TextBox
            {
                $RsVariable = New-Object PSCustomObject
                $RsVariable | Add-Member -type NoteProperty -name Name -Value $KeyName
                $RsVariable | Add-Member -type NoteProperty -name Type -Value $WpfHashtable."$($KeyName)".GetType().Name
                $RsVariable | Add-Member -type NoteProperty -name Value -Value $WpfHashtable."$($KeyName)".Text
                $RsVariable | Add-Member -type NoteProperty -name TabItem -Value $WpfHashtable."$($KeyName)".Parent.Parent.Header
                $Runspace.SessionStateProxy.SetVariable($RsVariable.Name,$RsVariable)
                break
            }
            PasswordBox
            {
                $RsVariable = New-Object PSCustomObject
                $RsVariable | Add-Member -type NoteProperty -name Name -Value $KeyName
                $RsVariable | Add-Member -type NoteProperty -name Type -Value $WpfHashtable."$($KeyName)".GetType().Name
                $RsVariable | Add-Member -type NoteProperty -name Value -Value $WpfHashtable."$($KeyName)".Password
                $RsVariable | Add-Member -type NoteProperty -name TabItem -Value $WpfHashtable."$($KeyName)".Parent.Parent.Header
                $Runspace.SessionStateProxy.SetVariable($RsVariable.Name,$RsVariable)
                break
            }
            CheckBox
            {
                $RsVariable = New-Object PSCustomObject
                $RsVariable | Add-Member -type NoteProperty -name Name -Value $KeyName
                $RsVariable | Add-Member -type NoteProperty -name Type -Value $WpfHashtable."$($KeyName)".GetType().Name
                $RsVariable | Add-Member -type NoteProperty -name Value -Value $WpfHashtable."$($KeyName)".IsChecked
                $RsVariable | Add-Member -type NoteProperty -name Content -Value $WpfHashtable."$($KeyName)".Content
                $RsVariable | Add-Member -type NoteProperty -name TabItem -Value $WpfHashtable."$($KeyName)".Parent.Parent.Header
                $Runspace.SessionStateProxy.SetVariable($RsVariable.Name,$RsVariable)
                break
            }
            Slider
            {
                $RsVariable = New-Object PSCustomObject
                $RsVariable | Add-Member -type NoteProperty -name Name -Value $KeyName
                $RsVariable | Add-Member -type NoteProperty -name Type -Value $WpfHashtable."$($KeyName)".GetType().Name
                $RsVariable | Add-Member -type NoteProperty -name Value -Value $WpfHashtable."$($KeyName)".Value
                $RsVariable | Add-Member -type NoteProperty -name TabItem -Value $WpfHashtable."$($KeyName)".Parent.Parent.Header
                $Runspace.SessionStateProxy.SetVariable($RsVariable.Name,$RsVariable)
                break
            }
            DataGrid
            {
                $RsVariable = New-Object PSCustomObject
                $RsVariable | Add-Member -type NoteProperty -name Name -Value $KeyName
                $RsVariable | Add-Member -type NoteProperty -name Type -Value $WpfHashtable."$($KeyName)".GetType().Name
                $RsVariable | Add-Member -type NoteProperty -name Value -Value $WpfHashtable."$($KeyName)".SelectedValue.ID
                $RsVariable | Add-Member -type NoteProperty -name Node -Value $WpfHashtable."$($KeyName)".SelectedValue.Node
                $RsVariable | Add-Member -type NoteProperty -name TabItem -Value $WpfHashtable."$($KeyName)".Parent.Parent.Header
                $Runspace.SessionStateProxy.SetVariable($RsVariable.Name,$RsVariable)
                break
            }
            ListBox
            {
                $RsVariable = New-Object PSCustomObject
                $RsVariable | Add-Member -type NoteProperty -name Name -Value $KeyName
                $RsVariable | Add-Member -type NoteProperty -name Type -Value $WpfHashtable."$($KeyName)".GetType().Name
                $RsVariable | Add-Member -type NoteProperty -name Value -Value $WpfHashtable."$($KeyName)".SelectedItem
                $RsVariable | Add-Member -type NoteProperty -name TabItem -Value $WpfHashtable."$($KeyName)".Parent.Parent.Header
                $Runspace.SessionStateProxy.SetVariable($RsVariable.Name,$RsVariable)
                break                
            }
            Default
            {break}   
        }
    }
    $Runspace.SessionStateProxy.SetVariable("Hash",$WpfHashtable)
    $Runspace.SessionStateProxy.SetVariable("Cfg",$CfgHashtable)

    $Powershell = [powershell]::Create().AddScript($scriptblock)
    $Powershell.Runspace = $Runspace
    $AsyncHandle = $Powershell.BeginInvoke()
}

function Update-WPFControl
{
    Param(
    [hashtable]$hashtable,
    $Control,
    $Property,
    $Value
    )
    # This updates the control based on the parameters passed to the function
    if ([string]::IsNullOrEmpty($value))
    {$hashtable.Window.Dispatcher.Invoke([action]{$hashtable.$Control.$Property},"Normal")}
    else {$hashtable.Window.Dispatcher.Invoke([action]{$hashtable.$Control.$Property = $Value},"Normal")}                        }
#######################
#endregion runspace
#######################