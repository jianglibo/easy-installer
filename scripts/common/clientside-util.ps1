$deployUtilFile = $MyInvocation.MyCommand.Path
$deployUtilFolder = $deployUtilFile | Split-Path -Parent
function  Get-SshInvoker {
    param (
        [Parameter(Mandatory = $true, Position = 0)][DeployConfig]$dconfig
    )
    $sshInvoker = [SshInvoker]::new($dconfig.config.HostName, $dconfig.config.ifile)
    $sshInvoker
}

function Get-MaxBackupNumber {
    param (
        [Parameter(Mandatory = $false, Position = 1)][string]$Path
    )
    $r = Get-ChildItem -Path "${Path}*" | 
        # Where-Object Name -Match ".*\.\d+$" |
    Foreach-Object {@{base = $_; dg = [int](Select-String -InputObject $_.Name -Pattern '(\d*)$' -AllMatches).matches.groups[1].Value}} |
        Sort-Object -Property @{Expression = {$_.dg}; Descending = $true} |
        # Where-Object {$_ -is [System.IO.DirectoryInfo]} |
    # We can not handle this situation, mixed files and directories.
    Select-Object -First 1 | ForEach-Object {$_.dg}
    if (-not $r) {
        0
    }
    else {
        $r
    }
}
function Get-NextBackup {
    param (
        [Parameter(Mandatory = $false, Position = 1)][string]$Path
    )
    $mn = 1 + (Get-MaxBackupNumber -Path $Path)
    "${Path}.${mn}"
}


function Get-MaxBackup {
    param (
        [Parameter(Mandatory = $false, Position = 1)][string]$Path
    )
    $mn = Get-MaxBackupNumber -Path $Path
    if ($mn -eq 0) {
        $Path
    }
    else {
        "${Path}.${mn}"
    }
}

<#
may run in remote server.
#>
function Backup-LocalDirectory {
    param (
        [Parameter(Mandatory = $false, Position = 1)][string]$Path,
        [switch]$keepOrigin
    )
    $nx = Get-NextBackup -Path $Path
    if (-not (Test-Path -Path $Path)) {
        throw "$Path does'nt exists."
    }

    if (Test-Path -Path $Path -Type Container) {
        if ($keepOrigin) {
            Copy-Item -Path $Path -Recurse -Destination $nx
        }
        else {
            Move-Item -Path $Path -Destination $nx
        }
    }
    else {
        if ($keepOrigin) {
            Copy-Item -Path $Path -Destination $nx
        }
        else {
            Move-Item -Path $Path -Destination $nx
        }
    }
    $nx
}

function Test-Verbose {
    [bool](Write-Verbose ([String]::Empty) 4>&1)
}

function Get-Verbose {
    $b = [bool](Write-Verbose ([String]::Empty) 4>&1)
    if ($b) {
        "-Verbose"
    }
    else {
        ""
    }
}

function Start-DeployClientSide {
    param (
        [Parameter(Mandatory = $true, Position = 0)][DeployConfig]$dconfig
    )
    $pb = $deployUtilFolder |Split-Path -Parent| Split-Path -Parent
    $zip = Find-NewestByExt -Path $pb -Ext "zip"
    if (-not $zip) {throw "There's no zip file under ${pb}."}
    $sshInvoker = Get-SshInvoker -dconfig $dconfig

    $MkdirStr = "rm -rf {0}/*;mkdir -p {1};mkdir -p {2};mkdir -p {3}" -f $dconfig.tmpDir, $dconfig.deployDir, $dconfig.scriptDir, $dconfig.tmpDir
    $MkdirStr | Write-Verbose

    $sshInvoker.invoke($MkdirStr)

    # /opt/weblized/tmp/xxx.zip
    $uploaded = $sshInvoker.scp($zip, $dconfig.tmpDir, $true)

    $dconfig.uploaded = $uploaded

    if (-not $uploaded) {
        throw "upload zip $zip failed."
    }
    # move to server side.
    # $sshInvoker.unzip($uploaded, $dconfig.unzipDir)
    # trans running code to server side.
    # $scriptLines = ,'Start-DeployServerSide'
    # $rscript = New-RemoteScriptFile -sshInvoker $sshInvoker -DeployConfig $dconfig -scriptLines $scriptLines
    # $sshInvoker.Invoke("pwsh -f $rscript")
    $rcmd = "pwsh -f {0} -action Deploy {1} {2}" -f $dconfig.runningps1, (Get-Verbose), $uploaded
    $rcmd | Write-Verbose
    $sshInvoker.Invoke($rcmd)
    $sshInvoker | Out-String | Write-Verbose
}

function Invoke-ServerRunningPs1 {
    param (
        [Parameter(Mandatory = $true, Position = 0)][DeployConfig]$dconfig,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$action,
        [parameter(Mandatory = $false,
            ValueFromRemainingArguments = $true)]
        [String[]]
        $hints
    )
    $sshInvoker = Get-SshInvoker -dconfig $dconfig
    
    $rcmd = "pwsh -f {0} -action {1} {2} {3}" -f $dconfig.runningps1, $action, (Get-Verbose), ($hints -join ' ')
    $rcmd | Out-String | Write-Verbose
    $sshInvoker.Invoke($rcmd)
}

function Stop-JavaProcess {
    param (
        [Parameter(Mandatory = $true, Position = 0)][DeployConfig]$dconfig
    )
    $myapppid = Get-Content -Path $dconfig.pidFile -ErrorAction SilentlyContinue
    if ($myapppid) {
        $myappProcess = Get-Process -Id $myapppid -ErrorAction SilentlyContinue
    }

    if ($myappProcess) {
        $myappProcess | Stop-Process
    }
    else {
        Get-Process | Where-Object Name -Like "*java*"|  Stop-Process
    }
}

function Test-TmuxSession {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$tmuxsess
    )
    tmux ls | Where-Object {$_ -match "^${tmuxsess}:"} | Select-Object -First 1
}

function Start-Tmux {
    param (
        [Parameter(Mandatory = $true, Position = 0)][DeployConfig]$dconfig
    )
    $tmuxsess = $dconfig.config.tmuxsess
    if ((Test-TmuxSession -tmuxsess $tmuxsess)) {
        "tmux with ${tmuxsess} session name is runing now. Please stop first.`n"
    }
    else {
        $startshc = Get-Content -Path $dconfig.startSh | ForEach-Object {$_ -replace 'serverWorkingDir', $dconfig.workingDir} | ForEach-Object {$_.Trim()}
        $startshc | Set-Content -Path $dconfig.startSh
        chmod a+x $dconfig.startSh
        "start run: tmux new-sessio -d -s $($dconfig.config.tmuxsess) $($dconfig.startSh)`n"
        tmux new-sessio -d -s asession $dconfig.startSh
    }

}

function Start-RollbackServerSide {
    param (
        [Parameter(Mandatory = $true, Position = 0)][DeployConfig]$dconfig
    )
    $maxBackup = Get-MaxBackup -Path $dconfig.workingDir
    $pi1 = Resolve-Path -Path $maxBackup
    $pi2 = Resolve-Path -Path $dconfig.workingDir
    if ($pi1.FullName -ne $pi2.FullName) {
        Stop-JavaProcess -dconfig $dconfig
        if ((Test-Path -Path $dconfig.rollback)) {
            Remove-Item -Recurse -Force $dconfig.rollback
        }
        Move-Item -Path $dconfig.workingDir -Destination $dconfig.rollback
        Move-Item -Path $maxBackup -Destination $dconfig.workingDir
        Start-Tmux -dconfig $dconfig
    }
}
<#
may run in remote server. $dconfig alreay defined.
#>
function Start-DeployServerSide {
    param (
        [Parameter(Mandatory = $true, Position = 0)][DeployConfig]$dconfig,
        [Parameter(Mandatory = $true, Position = 1)][string]$uploaded
    )
    unzip -o -q -d $dconfig.unzipDir $uploaded
    $workingExists = Test-Path -Path $dconfig.workingDir
    if ($workingExists) {
        Stop-JavaProcess -dconfig $dconfig
        Backup-LocalDirectory -Path $dconfig.workingDir
    }

    if (Test-Path $dconfig.workingDir) {
        throw "move working dir faile.`n"
    }

    Move-Item -Path $dconfig.unzipDir -Destination $dconfig.workingDir
    # modify start.sh.
    Start-Tmux -dconfig $dconfig
}

<#
Concat SshInvoker.ps1 and this file in to one file.
#>
function New-RemoteScriptFile {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$sshInvoker,
        [Parameter(Mandatory = $true, Position = 1)]$DeployConfig,
        [Parameter(Mandatory = $true, Position = 2)][string[]]$scriptLines
    )
    $tf = New-TemporaryFile 
    $c = @()
    $c += Get-Content -Path (Join-Path -Path $deployUtilFolder -ChildPath "deploy-config.ps1")
    $c += Get-Content -Path (Join-Path -Path $deployUtilFolder -ChildPath "SshInvoker.ps1")
    $c += (Get-Content -Path $deployUtilFile | Where-Object {$_ -notmatch '#exclude from remote$'})

    $h = '$dconfigstr=@"', ($DeployConfig | ConvertTo-Json) , '"@', '$dconfig = $dconfigstr | ConvertFrom-Json'
    $c += $h
    $c += $scriptLines
    Set-Content -Path $tf -Value $c
    $rf = "{0}/running.ps1" -f $DeployConfig.scriptDir
    $rf = $sshInvoker.scp($tf, $rf, $false)
    if ($sshInvoker.isFileExists($rf)) {
        $rf
    }
    else {
        $null
    }
}

function sanitizePath {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$Path
    )
    $separator = '\'
    $ptn = '\\+'
    if ($Path.Contains("/")) {
        if ($Path.Contains("\")) {
            $Path = $Path -replace "\\", "/"
        }
        $separator = '/';
        $ptn = '/+'
    }
    $Path = $Path -replace $ptn, $separator
    if ($Path.EndsWith($separator)) {
        $Path = $Path.Substring(0, $Path.Length - 1)
    }
    @{sanitized = $Path; separator = $separator}
}

function Join-UniversalPath {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Path,
        [Parameter(Mandatory = $true, Position = 1)][string]$ChildPath
    )
    $sanitizedParent = sanitizePath -Path $Path
    $pp = $sanitizedParent.sanitized
    $sp = $sanitizedParent.separator
    $sanitizedChild = sanitizePath -Path $ChildPath
    $cp = $sanitizedChild.sanitized
    $sc = $sanitizedChild.separator

    if ($sp -ne $sc) {
        if ($sc -eq '\') {
            $sc = '\\'
        }
        $cp = $cp -replace $sc, $sp
    }

    if ($cp.StartsWith($sp)) {
        $cp = $cp.Substring(1)
    }
    "${pp}${sp}${cp}"
}

function Split-UniversalPath {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Path,
        [switch]$Parent
    )
    $sanitized = sanitizePath -Path $Path
    $Path = $sanitized.sanitized
    $separator = $sanitized.separator

    $idx = $Path.LastIndexOf($separator)
    if ($idx -ne -1) {
        if ($Parent) {
            $Path = $Path.Substring(0, $idx)
        }
        else {
            $Path = $Path.Substring($idx + 1)
        }
    }
    $Path
}

function Find-NewestByExt {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$Path,
        [Parameter(Mandatory = $true, Position = 1)]$Ext
    )
    if (-not $Ext.StartsWith("*.")) {
        $Ext = "*.$Ext"
    }
    Get-ChildItem -Path $Path -Recurse -Include $Ext | Sort-Object @{Expression = {$_.LastWriteTime}; Descending = $true} | Select-Object -First 1
}

function Copy-PsScriptToServer {
    param (
        [Parameter(Mandatory = $true, Position = 0)][DeployConfig]$dconfig,
        [Parameter(Mandatory = $false, Position = 0)][switch]$Detail
    )
    # $df = New-TemporaryFile | Split-Path -Parent | Join-Path -ChildPath "deploy.json"
    # $dconfig | ConvertTo-Json | Set-Content -Path $df
    $df = $deployUtilFolder | Split-Path -Parent | Join-Path -ChildPath deploy.json

    $filesToCopy = "{0}\deploy-config.ps1 {1}\SshInvoker.ps1 {2}\deploy-util.ps1 {3} {4}\running-at-server.ps1" -f $deployUtilFolder, $deployUtilFolder, $deployUtilFolder, $df, $deployUtilFolder
    $sshInvoker = Get-SshInvoker -dconfig $dconfig
    $r = $sshInvoker.scp($filesToCopy, $dconfig.scriptDir, $true)
    $sshInvoker | Out-String | Write-Verbose
    "copied files:"
    $r -split ' '
}

# Export-ModuleMember -Function Backup-LocalDirectory,
# New-RemoteScriptFile,
# Get-MaxBackup,
# Find-NewestByExt,
# Split-UniversalPath,
# Join-UniversalPath,
# Start-DeployClientSide,
# Start-DeployServerSide,
# Copy-PsScriptToServer,
# Get-SshInvoker,
# Invoke-ServerRunningPs1,
# Stop-JavaProcess