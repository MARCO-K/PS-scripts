#requires -Version 2.0 -Modules PSFramework
function Invoke-SqlPackage 
{    
  <#
      .SYNOPSIS
      Invoke the sqlpackage executable.
 
      .DESCRIPTION
      Invoke the sqlpackage executable and pass the necessary parameters to it.

      .PARAMETER Executable
      Path to executable SqlPackage.exe

      .PARAMETER Action
      Can either be import/export or extract/publich.
 
      .PARAMETER DatabaseServer
      The name of the database server.
 
      If on-premises or classic SQL Server, use either short name og Fully Qualified Domain Name (FQDN).
      If Azure use the full address to the database server, e.g. server.database.windows.net
 
      .PARAMETER DatabaseName
      The name of the database
 
      .PARAMETER SqlUser
      The login name for the SQL Server instance.
 
      .PARAMETER SqlPwd
      The password for the SQL Server user.
 
      .PARAMETER UseTrustedConnection
      Should the sqlpackage work with TrustedConnection or not.

      .PARAMTER Diagnostics
      Should Diagnostics information be written.

      .PARAMETER DiagnosticsFile
      Path to the diagnostics file.
 
      .PARAMETER OverwriteFiles
      Specifies if it should overwrite existing files.

      .PARAMETER FilePath
      Path to the file, used for either import or export.

      .PARAMETER MaxParallelism
      Degree of Parallelism. Default value is 4.
 
      .PARAMETER Properties
      Array of all the properties that needs to be parsed to the sqlpackage.exe
 
      .EXAMPLE

      $BaseParams = @{
      Executable= path_to_executable
      DatabaseServer = 'Server\Instance'
      DatabaseName = 'db_name'
      UseTrustedConnection = $true
      Action = 'export'
      FilePath = path_to_file
      }
 
      $ExtendedParams = @{
      Diagnostics = $true
      DiagnosticsFile = path_to_diag_file
      MaxParallelism = 4
      }
     
      Invoke-SqlPackage @BaseParams @ExtendedParams
 
      This will start the sqlpackage.exe file and pass all the needed parameters.
  #>
  [CmdletBinding()]
  param (
    [string]$Executable,
    [ValidateSet('Import', 'Export','Extract','Publish')][string]$Action, 
    [string]$DatabaseServer,
    [string]$DatabaseName,
    [string]$SqlUser,
    [string]$SqlPwd,
    [switch]$UseTrustedConnection,
    [string]$FilePath,
    [switch]$OverwriteFiles,
    [string[]]$Properties,
    [switch]$Diagnostics,
    [string]$DiagnosticsFile,
    [int]$MaxParallelism = 4  
  ) 

  begin {               
    $stopwatch = [Diagnostics.StopWatch]::StartNew()
    
    if (!(Test-Path -Path $Executable -PathType Leaf -ErrorAction Stop)) 
    {
      Write-PSFMessage -Level Critical -Message 'Cannot find executable for sqlpackage.exe' -Exception $Executable
      return
    }
    
    Write-PSFMessage -Level Output -Message 'Starting to prepare the parameters for sqlpackage.exe'
    $Params = [Collections.ArrayList]@()

    #Export
    if ($Action -eq 'Export') 
    {
      $null = $Params.Add('/Action:export')
      $null = $Params.Add("/SourceServerName:$DatabaseServer")
      $null = $Params.Add("/SourceDatabaseName:$DatabaseName")
      $null = $Params.Add("/OverwriteFiles:$OverwriteFiles")
      $null = $Params.Add("/TargetFile:$FilePath")
      $null = $Params.Add('/Properties:CommandTimeout=1200')
      $null = $Params.Add("/MaxParallelism:$MaxParallelism")
    
      if (!$UseTrustedConnection) 
      {
        $null = $Params.Add("/SourceUser:$SqlUser")
        $null = $Params.Add("/SourcePassword:$SqlPwd")
      }
    
      if ($Diagnostics) 
      {
        $null = $Params.Add("/Diagnostics:$Diagnostics")
        $null = $Params.Add("/DiagnosticsFile:$DiagnosticsFile")
      }   
    }
    #Import
    elseif ($Action -eq 'Import') 
    {
      if (!(Test-Path -Path $FilePath -PathType Leaf -ErrorAction Stop)) 
      {
        Write-PSFMessage -Level Critical -Message 'Cannot find file for import' -Exception $FilePath
        return
      }
      $null = $Params.Add('/Action:import')
      $null = $Params.Add("/TargetServerName:$DatabaseServer")
      $null = $Params.Add("/TargetDatabaseName:$DatabaseName")
      $null = $Params.Add("/SourceFile:$FilePath")
      $null = $Params.Add("/MaxParallelism:$MaxParallelism")
      $null = $Params.Add('/Properties:CommandTimeout=1200')
        
      if (!$UseTrustedConnection) 
      {
        $null = $Params.Add("/TargetUser:$SqlUser")
        $null = $Params.Add("/TargetPassword:$SqlPwd")
      }   
        
      if ($Diagnostics) 
      {
        $null = $Params.Add("/Diagnostics:$Diagnostics")
        $null = $Params.Add("/DiagnosticsFile:$DiagnosticsFile")
      }
    }
    #Extract
    elseif ($Action -eq 'Extract')
    {
      $null = $Params.Add('/Action:extract')
      $null = $Params.Add("/SourceServerName:$DatabaseServer")
      $null = $Params.Add("/SourceDatabaseName:$DatabaseName")
      $null = $Params.Add("/OverwriteFiles:$OverwriteFiles")
      $null = $Params.Add("/TargetFile:$FilePath")
      $null = $Params.Add('/Properties:CommandTimeout=1200')
      $null = $Params.Add('/Properties:ExtractReferencedServerScopedElements=False')
      $null = $Params.Add('/Properties:ExtractUsageProperties=False')
      $null = $Params.Add('/Properties:IgnoreExtendedProperties=True')
      $null = $Params.Add('/Properties:IgnorePermissions=True')
      $null = $Params.Add('/Properties:IgnoreUserLoginMappings=True')
      $null = $Params.Add("/MaxParallelism:$MaxParallelism")

      if (!$UseTrustedConnection) 
      {
        $null = $Params.Add("/SourceUser:$SqlUser")
        $null = $Params.Add("/SourcePassword:$SqlPwd")
      }           
      if ($Diagnostics) 
      {
        $null = $Params.Add("/Diagnostics:$Diagnostics")
        $null = $Params.Add("/DiagnosticsFile:$DiagnosticsFile")
      }
    } 
    #Publish
    elseif ($Action -eq 'Publish') 
    {
      if (!(Test-Path -Path $FilePath -PathType Leaf -ErrorAction Stop)) 
      {
        Write-PSFMessage -Level Critical -Message 'Cannot find file for import' -Exception $FilePath
        return
      }
      $null = $Params.Add('/Action:publish')
      $null = $Params.Add("/TargetServerName:$DatabaseServer")
      $null = $Params.Add("/TargetDatabaseName:$DatabaseName")
      $null = $Params.Add("/OverwriteFiles:$OverwriteFiles")
      $null = $Params.Add("/SourceFile:$FilePath")
      $null = $Params.Add("/MaxParallelism:$MaxParallelism")
      $null = $Params.Add('/Properties:CommandTimeout=1200')
        
      if (!$UseTrustedConnection) 
      {
        $null = $Params.Add("/TargetUser:$SqlUser")
        $null = $Params.Add("/TargetPassword:$SqlPwd")
      }   
        
      if ($Diagnostics) 
      {
        $null = $Params.Add("/Diagnostics:$Diagnostics")
        $null = $Params.Add("/DiagnosticsFile:$DiagnosticsFile")
      }
    }

    foreach ($item in $Properties) 
    {
      $null = $Params.Add("/Properties:$item")
    }
  }
  process { 
    Write-PSFMessage -Level Output -Message "Starting $Action with sqlpackage.exe"
    try 
    { 
      Write-PSFMessage -Level Verbose -Message "Start sqlpackage.exe with parameters: $Params"
      Start-Process -FilePath $Executable -ArgumentList ($Params -join ' ') -NoNewWindow -Wait
    }
    catch 
    {
      Write-PSFMessage -Level Critical -Message 'Failed to change password for sa account' -ErrorRecord $_ -Exception $_.Exception
    }
  }
  end { 
    $stopwatch.Stop()
    Write-PSFMessage -Level Output -Message "Successfully run $Action with sqlpackage.exe in: $($stopwatch.Elapsed.TotalSeconds)"
  }
}
