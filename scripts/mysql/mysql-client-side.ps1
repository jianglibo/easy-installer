param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install",
        "Start",
        "Stop", 
        "Restart",
        "CopyDemoConfigFile",
        "Status", 
        "DownloadPackages",
        "SendPackages", 
        "Uninstall", 
        "FlushLogs",
        "Dump",
        "BackupLocal",
        "DownloadPublicKey")]
    [string]$Action,
    [parameter(Mandatory = $false)]
    [string]$ConfigFile,
    [parameter(Mandatory = $false)]
    [ValidateSet("55", "56", "57", "80")]
    [string]$Version,
    [switch]$LogResult,
    [switch]$Json
)

<#
    Put configuration values in Global scope is a choice.
    1. openssl executable(client and server)
    2. private key file.
    3. configuration it's self.
#>

$vb = $PSBoundParameters.ContainsKey('Verbose')
if ($vb) {
    $PSDefaultParameterValues['*:Verbose'] = $true
}
else {
    $PSDefaultParameterValues['*:Verbose'] = $false
}

$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent

. ($here | Split-Path -Parent | Join-Path -ChildPath 'global-variables.ps1')

. (Join-Path -Path $here -ChildPath 'mysql-client-function.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'ssh-invoker.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'common-util.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'clientside-util.ps1')

$isInstall = $Action -eq "Install"

$scriptstarttime = Get-Date

if ($isInstall -and (-not $Version)) {
    Write-ParameterWarning -wstring "If action is Install then Version parameter is required."
    return
}

if ($Action -eq "CopyDemoConfigFile") {
    Copy-DemoConfigFile -MyDir $here -ToFileName "mysql-config.json"
}
else {
    if (-not $ConfigFile) {
        Write-ParameterWarning -wstring ", If you don't know what ConfigFile is, run Action 'CopyDemoConfigFile' first."
        return
    }

    $configuration = Get-Configuration -ConfigFile $ConfigFile
    if (-not $configuration) {
        return
    }
    Copy-PsScriptToServer -ConfigFile $ConfigFile
    switch ($Action) {
        "DownloadPackages" {
            $configuration.DownloadPackages()
            break
        }
        "SendPackages" {
            Send-SoftwarePackages
            break
        }
        "Uninstall" {
            if ($PSCmdlet.ShouldContinue("Are you sure?", "")) {
                Invoke-ServerRunningPs1 -action $Action $Version
            }
            else {
                "canceled."
            }
            break
        }
        "DownloadPublicKey" {
            $r = Invoke-ServerRunningPs1 -action $Action | Receive-LinesFromServer
            $sshInvoker = Get-SshInvoker
            $f = Get-PublicKeyFile -NotResolve
            $sshInvoker.ScpFrom($r, $f, $false)
            break
        }
        "Dump" {
            $dumpraw = Invoke-ServerRunningPs1 -action $Action
            $dumpraw | Write-Verbose
            $dumpr = $dumpraw | Receive-LinesFromServer | ConvertFrom-Json
            $copyr = Copy-MysqlDumpFile -RemoteDumpFileWithHashValue $dumpr

            $success = $dumpr.Length -and $dumpr.Path -and $copyr.Length
            $v = @{result = $dumpr; download = $copyr; success=$success; timespan=(Get-Date) - $scriptstarttime}
            $v | Write-ActionResultToLogFile -Action $Action -LogResult:$LogResult
            $v | Out-JsonOrOrigin -Json:$Json
            break
        }
        "FlushLogs" {
            $flushraw = Invoke-ServerRunningPs1 -action $Action
            $flushraw | Write-Verbose
            [array]$flushr = $flushraw | Receive-LinesFromServer | ConvertFrom-Json
            $copyr = Copy-MysqlLogFiles -RemoteLogFilesWithHashValue $flushr

            $success = $flushr[0].Length -and $flushr[0].Path -and $copyr.Length
            $v = @{result = $flushr; download = $copyr; success=$success; timespan=(Get-Date) - $scriptstarttime}
            $v | Write-ActionResultToLogFile -Action $Action -LogResult:$LogResult
            $v | Out-JsonOrOrigin -Json:$Json
            break
        }
        "BackupLocal" {
            $d = Get-MaxLocalDir
            $newd = Backup-LocalDirectory -Path $d -keepOrigin
            $pruned = Resize-BackupFiles -BasePath $d -Pattern $configuration.DumpPrunePattern
            $success = [bool]$d -and [bool]$newd
            $result = @()
            if ($pruned) {
                $pruned | Select-Object -Property FullName | ForEach-Object {
                    $result += $_
                }
            }
            $v = @{result=$result;success=$success; timespan=(Get-Date) - $scriptstarttime}
            $v | Write-ActionResultToLogFile -Action $Action -LogResult:$LogResult
            $v | Out-JsonOrOrigin -Json:$Json
            break
        }
        Default {
            Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action $Version
            # $configuration = Get-Configuration -ConfigFile $ConfigFile
            # $configuration | ConvertTo-Json -Depth 10
        }
    }
}