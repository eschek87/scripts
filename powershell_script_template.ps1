#requires -version 2
#requires -module slr
<#
.SYNOPSIS
  <Overview of script>
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
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
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

#Dot source required function libraries
#.$ScriptDir\logging_functions.ps1
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
$OutputPath=$scriptDir
$OutputName = "$Today"+"_"+"$ScriptName.csv"
$OutputFile = Join-Path -Path $OutputPath -ChildPath $OutputName
#---------------------------------------------------------[Define variables]--------------------------------------------------------
#Define your variables here if possible

#Hostname where script runs
$ScriptHostname= $env:computername

#Generate credentials for login cmdlets
#you need to run the following onetime before
#Get-Credential | Export-Clixml -Path C:\scripts\${env:USERNAME}_cred.xml
#$Credentials = Import-Clixml -Path C:\scripts\${env:USERNAME}_cred.xml
#-----------------------------------------------------------[Start Logging]------------------------------------------------------------
Log-Start -LogPath $LogPath -LogName $LogName -ScriptVersion $ScriptVersion
#-----------------------------------------------------------[Functions]------------------------------------------------------------
<#
Function <FunctionName>{
  Param()
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "<description of what is going on>..."
  }
  
  Process{
    Try{
      <code goes here>
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $Error[0] -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}
#>
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
#-----------------------------------------------------------[Stop logging, remove variables]------------------------------------------------------------
Log-Finish -LogPath $LogFile