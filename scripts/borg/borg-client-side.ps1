param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install",
        "DownloadPackages",
        "CopyDemoConfigFile",
        "InitializeRepo",
        "Archive",
        "Prune",
        "BackupLocal",
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

. (Join-Path -Path $here -ChildPath 'borg-client-function.ps1')
. $Global:CommonUtil
. $Global:ClientUtil

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
                Invoke-ServerRunningPs1 -action $Action
            }
            else {
                "canceled."
            }
            break
        }
        "DownloadPublicKey" {
            $r = Invoke-ServerRunningPs1 -action $Action 
            $r = $r | Receive-LinesFromServer
            $sshInvoker = Get-SshInvoker
            $f = Get-ServerPublicKeyFile -NotResolve
            $sshInvoker.ScpFrom($r, $f, $false)
            $sshInvoker.invoke("rm $r")
            break
        }
        "InitializeRepo" {
            $r = Invoke-ServerRunningPs1 -Action InitializeRepo -notCombineError
            $r | Receive-LinesFromServer
            break
        }
        "Archive" {
            $r = Invoke-ServerRunningPs1 -Action Archive
            $r | Write-Verbose
            $v = $r | Receive-LinesFromServer
            if ($LogResult) {
                $v | Out-File -FilePath (Get-LogFile -group 'borgarchive')
            }
            $v
            break
        }
        "ArchiveAndDownload" {
            $rar = Invoke-ServerRunningPs1 -Action Archive 
            "$Action raw output from server:" | Write-Verbose
            $rar | Write-Verbose
            $ar = $rar | Receive-LinesFromServer | ConvertFrom-Json
            $dr = Copy-BorgRepoFiles
            $success = $ar.archive -and $dr.copied
            [array]$files = $dr.total.files # change from stream to array.
            $dr.total.files = $files
            $v = @{result = $ar; download = $dr; success=$success; timespan=(Get-Date) - $scriptstarttime}
            $v | Write-ActionResultToLogFile -Action $Action -LogResult:$LogResult
            $v | Out-JsonOrOrigin -Json:$Json
            break
        }
        "PruneAndDownload" {
            $pr = Invoke-ServerRunningPs1 -Action Prune | Receive-LinesFromServer | ConvertFrom-Json
            $dr = Copy-BorgRepoFiles
            [array]$files = $dr.total.files # change from stream to array.
            $dr.total.files = $files
            $success = $pr.archives -and ($pr.archives -is [array]) -and $dr.copied
            $v = @{result = $pr; download = $dr; success=$success; timespan=(Get-Date) - $scriptstarttime}
            $v | Write-ActionResultToLogFile -Action $Action -LogResult:$LogResult
            $v | Out-JsonOrOrigin -Json:$Json
            break
        }
        "Prune" {
            $r = Invoke-ServerRunningPs1 -Action Prune
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
        "BackupLocal" {
            # $d = Get-MaxLocalDir
            # $newd = Backup-LocalDirectory -Path $d -keepOrigin
            # $pruned = Resize-BackupFiles -BasePath $d -Pattern $configuration.BorgPrunePattern
            # $success = [bool]$d -and [bool]$newd
            # $result = @()
            # if ($pruned) {
            #     $pruned | Select-Object -Property FullName | ForEach-Object {
            #         $result += $_
            #     }
            # }
            # $v = @{result=$result;success=$success; timespan=(Get-Date) - $scriptstarttime}
            # $v | Write-ActionResultToLogFile -Action $Action -LogResult:$LogResult
            # $v | Out-JsonOrOrigin -Json:$Json
            Invoke-ClientCommonActions -Action $Action -ConfigFile $ConfigFile -scriptstarttime $scriptstarttime -LogResult:$LogResult -Json:$Json $configuration.BorgPrunePattern
            break
        }
        Default {
            Invoke-ClientCommonActions -Action $Action -ConfigFile $ConfigFile -scriptstarttime $scriptstarttime -LogResult:$LogResult -Json:$Json
        }
    }
}