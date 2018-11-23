param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install",
        "DownloadPackages",
        "CopyDemoConfigFile",
        "InitializeRepo",
        "Archive",
        "Prune",
        "ArchiveAndDownload",
        "PruneAndDownload",
        "DownloadRepo",
        "SendPackages", 
        "Uninstall", 
        "DiskFree",
        "MemoryFree",
        "DownloadPublicKey")]
    [string]$Action,
    [parameter(Mandatory = $false)]
    [string]$ConfigFile,
    [switch]$CopyScripts,
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
$ScriptDir = $here | Split-Path -Parent
$CommonDir = $ScriptDir | Join-Path -ChildPath "common"

$Global:ProjectRoot = $ScriptDir | Split-Path -Parent

. (Join-Path -Path $here -ChildPath 'borg-client-function.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'ssh-invoker.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'common-util.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'clientside-util.ps1')

$scriptstarttime = Get-Date

if ($Action -eq "CopyDemoConfigFile") {
    Copy-DemoConfigFile -MyDir $here -ToFileName "borg-config.json"
}
else {
    if (-not $ConfigFile) {
        Write-ParameterWarning -wstring "This action need ConfigFile parameter, If you don't know what ConfigFile is, run Action 'CopyDemoConfigFile' first."
        return
    }

    $configuration = Get-Configuration -ConfigFile $ConfigFile
    if (-not $configuration) {
        return
    }
    if ($CopyScripts) {
        Copy-PsScriptToServer -ConfigFile $ConfigFile -ServerSideFileListFile ($here | Join-Path -ChildPath "serversidefilelist.txt")
    }
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
                Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action
            }
            else {
                "canceled."
            }
            break
        }
        "DownloadPublicKey" {
            $r = Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action | Receive-LinesFromServer
            $sshInvoker = Get-SshInvoker
            $f = Get-PublicKeyFile -NotResolve
            $sshInvoker.ScpFrom($r, $f, $false)
            break
        }
        "InitializeRepo" {
            $r = Invoke-ServerRunningPs1 -ConfigFile $ConfigFile -Action InitializeRepo -notCombineError
            $r | Receive-LinesFromServer
            break
        }
        "Archive" {
            $r = Invoke-ServerRunningPs1 -ConfigFile $ConfigFile -Action Archive
            $r | Write-Verbose
            $v = $r | Receive-LinesFromServer
            if ($LogResult) {
                $v | Out-File -FilePath (Get-LogFile -group 'borgarchive')
            }
            $v
            break
        }
        "ArchiveAndDownload" {
            $ar = Invoke-ServerRunningPs1 -ConfigFile $ConfigFile -Action Archive | Receive-LinesFromServer | ConvertFrom-Json
            $dr = Copy-BorgRepoFiles
            $success = $ar.archive -and $dr.copied
            $v = @{result = $ar; download = $dr; success=$success; timespan=(Get-Date) - $scriptstarttime}
            $v | Write-ActionResultToLogFile -Action $Action -LogResult:$LogResult
            $v | Out-JsonOrOrigin -Json:$Json
            break
        }
        "PruneAndDownload" {
            $pr = Invoke-ServerRunningPs1 -ConfigFile $ConfigFile -Action Prune | Receive-LinesFromServer | ConvertFrom-Json
            $dr = Copy-BorgRepoFiles
            $success = $pr.archives -and ($pr.archives -is [array]) -and $dr.copied
            $v = @{result = $pr; download = $dr; success=$success; timespan=(Get-Date) - $scriptstarttime}
            $v | Write-ActionResultToLogFile -Action $Action -LogResult:$LogResult
            $v | Out-JsonOrOrigin -Json:$Json
            break
        }
        "Prune" {
            $r = Invoke-ServerRunningPs1 -ConfigFile $ConfigFile -Action Prune
            $r | Write-Verbose
            $v = $r | Receive-LinesFromServer
            if ($LogResult) {
                $v | Out-File -FilePath (Get-LogFile -group 'borgprune')
            }
            $v
            break
        }
        "DownloadRepo" {
            $r = Copy-BorgRepoFiles -LogResult:$LogResult -Json:$Json
            $r | Write-Verbose
            $r
            break
        }
        "DiskFree" {
            $r = Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action
            $r | Write-Verbose
            $jr = $r | Receive-LinesFromServer | ConvertFrom-Json
            $success = ($jr -is [array]) -and $jr[0].Name
            $v = @{result=$jr;success=$success; timespan=(Get-Date) - $scriptstarttime}

            if ($LogResult) {
                $v | ConvertTo-Json | Out-File -FilePath (Get-LogFile -group $Action)
            }
            $v
            break
        }
        "MemoryFree" {
            $r = Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action
            $r | Write-Verbose
            $jr = $r | Receive-LinesFromServer | ConvertFrom-Json
            $success = $jr.Total -and $jr.Free
            $v = @{result=$jr;success=$success; timespan=(Get-Date) - $scriptstarttime}
            if ($LogResult) {
                $v | ConvertTo-Json | Out-File -FilePath (Get-LogFile -group $Action)
            }
            $v
            break
        }
        Default {
            $r = Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action
            $r | Write-Verbose
            $r
        }
    }
}