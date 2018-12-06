class OsDetail {
    [string]$Name
    [string]$Version
    [string]$Platform

    OsDetail ([string]$Platform, [string]$Name, [string]$Version) {
        $this.Platform = $Platform
        $this.Name = $Name
        $this.Version = $Version
    }

    [bool]IsWin() {
        return $this.Platform -like '*win*'
    }

    [bool]IsUnix() {
        return $this.Platform -like '*unix*'
    }

    [bool]IsCentos() {
        return $this.Name -like '*centos*'
    }


    [bool]IsCentos7() {
        return ($this.Name -like '*centos*') -and ($this.Version -like '*7*')
    }

}
function Split-Url {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Url,
        [Parameter()]
        [ValidateSet("Container", "Leaf")]
        [string]$ItemType = "Leaf"
    )

    $parts = $Url -split '://', 2

    if ($parts.Count -eq 2) {
        $hasProtocal = $true
        $beforeProtocol = $parts[0]
        $afterProtocol = $parts[1]
    }
    else {
        $hasProtocal = $false
        $afterProtocol = $parts[0]
    }
    $idx = $afterProtocol.LastIndexOf('/')
    if ($idx -eq -1) {
        if ($ItemType -eq "Leaf") {
            ''
        }
        else {
            $Url
        }
    }
    else {
        if ($ItemType -eq "Leaf") {
            $afterProtocol.Substring($idx + 1)
        }
        else {
            $afterProtocol = $afterProtocol.Substring(0, $idx + 1)
            if ($hasProtocal) {
                "${beforeProtocol}://${afterProtocol}"
            }
            else {
                $afterProtocol
            }
        }
    }
}

<#
.SYNOPSIS
This function may invoke both at client and server side.

.DESCRIPTION
Long description

.PARAMETER TargetDir
Parameter description

.PARAMETER Softwares
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-SoftwarePackages {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$TargetDir,
        [Parameter(Mandatory = $true, Position = 1)]$Softwares
    )
    if (-not (Test-Path -Path $TargetDir -PathType Container)) {
        New-Item -Path $TargetDir -ItemType "directory" | Out-Null
    }
    $Softwares | ForEach-Object {
        $url = $_.PackageUrl
        $ln = $_.LocalName
        if (-not $ln) {
            $ln = Split-Url -Url $url
        }
        $lf = Join-Path -Path $TargetDir -ChildPath $ln
        if (-not (Test-Path -Path $lf -PathType Leaf)) {
            Invoke-WebRequest -Uri $url -OutFile $lf
        }
    }
}

function Get-SoftwarePackagePath {
    param (
        [Parameter(Mandatory = $false, Position = 0)]$SoftwareName
    )

    $TargetDir = $Global:configuration.OsConfig.ServerSide.PackageDir

    "Server Side package dir: $TargetDir" | Write-Verbose

    if (-not $SoftwareName) {
        $SoftwareName = $Global:configuration.OsConfig.Softwares | ForEach-Object {
            $url = $_.PackageUrl
            $ln = $_.LocalName
            if (-not $ln) {
                $ln = Split-Url -Url $url
            }
            $ln
        } | Select-Object -First 1
    }
    $d = Get-ChildItem -Path $TargetDir | Where-Object {$_.Name -eq $SoftwareName} | Select-Object -First 1
    "found package file: $($d.FullName)" | Write-Verbose
    $d.FullName
}


function Get-Configuration {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$ConfigFile,
        [Parameter()][switch]$ServerSide
    )
    $vcf = Resolve-Path -Path $ConfigFile -ErrorAction SilentlyContinue
    if (-not $vcf) {
        $m = "ConfigFile ${ConfigFile} doesn't exists."
        Write-ParameterWarning -wstring $m -ThrowIt
    }

    $c = Get-Content -Path $vcf -Encoding UTF8 | ConvertFrom-Json
    if (-not $ServerSide) {

        if (-not ($c.IdentityFile -or $c.ServerPassword)) {
            Write-ParameterWarning -wstring "Neither IdentityFile Nor ServerPassword property exists in ${vcf}." -ThrowIt
        }
        if ($c.IdentityFile) {
            if (-not (Test-Path -Path $c.IdentityFile -PathType Leaf)) {
                Write-ParameterWarning -wstring "IdentityFile property in $vcf point to an unexist file." -ThrowIt
            }
        }
        $c | Add-Member -MemberType ScriptMethod -Name "DownloadPackages" -Value {
            $dl = Join-Path -Path $ProjectRoot -ChildPath "downloads" | Join-Path -ChildPath $this.AppName
            $osConfig = $this.SwitchByOs.($this.OsType)
            Get-SoftwarePackages -TargetDir $dl -Softwares $osConfig.Softwares
        }

    }
    else {
        $c | Add-Member -MemberType ScriptMethod -Name "DownloadPackages" -Value {
            $osConfig = $this.SwitchByOs.($this.OsType)
            $packageDir = $osConfig.ServerSide.PackageDir
            Get-SoftwarePackages -TargetDir $packageDir -Softwares $osConfig.Softwares
        }
    }

    $c | Add-Member -MemberType ScriptProperty -Name OsConfig -Value {
        $osConfig = $this.SwitchByOs.($this.OsType)
        if (-not $osConfig) {
            $s = "The 'OsType' property is $($this.OsType), But there is no corresponding item in 'SwitchByOs': $ConfigFile"
            Write-ParameterWarning -wstring $s -level 2 -ThrowIt
        }
        $osConfig
    }

    if ($ServerSide) {
        $TargetDir = $c.OsConfig.ServerSide.PackageDir
        $c.OsConfig.Softwares | ForEach-Object {
            $url = $_.PackageUrl
            $ln = $_.LocalName
            if (-not $ln) {
                $ln = Split-Url -Url $url
            }
            $lf = Join-Path -Path $TargetDir -ChildPath $ln
            $_ | Add-Member -MemberType NoteProperty -Value $lf -Name LocalPath
        }
    }
    $Global:configuration = $c
    $Global:sshinvoker = Get-SshInvoker
    $c
}
function Join-UniversalPath {
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Path,
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

function Get-FileHashsInDirectory {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Directory
    )
    Get-ChildItem -Recurse $Directory |
        Where-Object {$_ -is [System.IO.FileInfo]} |
        ForEach-Object {$_ | Get-FileHash | Add-Member @{Length=$_.Length} -PassThru} | 
        ConvertTo-Json |
        Send-LinesToClient
}

function Copy-ChangedFiles {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$RemoteDirectory,
        [Parameter(Mandatory = $true, Position = 1)][string]$LocalDirectory,
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][switch]$OnlySum
    )
    if (-not (Test-Path -Path $LocalDirectory -PathType Container)) {
        New-Item -Path $LocalDirectory -ItemType Directory | Out-Null
    }
    if (-not $configuration) {
        $configuration = $Global:configuration
    }

    if (-not $configuration.ServerExec) {
        throw 'Missing ServerExec property in configuration file.'
    }
    $sshInvoker = [SshInvoker]::new($configuration.HostName, $configuration.IdentityFile)
    # $str = "Get-ChildItem -Recurse $RemoteDirectory | Where-Object {`$_ -is [System.IO.FileInfo]} | ForEach-Object {`$_ | Get-FileHash | Add-Member @{Length=`$_.Length} -PassThru} | ConvertTo-Json"
    # $bytes = [System.Text.Encoding]::Unicode.GetBytes($str)
    # $encodedCommand = [Convert]::ToBase64String($bytes)
    # $cmd = "$($configuration.ServerExec) -e '${encodedCommand}'"
    # [array]$filelist = $sshInvoker.invoke($cmd) | ConvertFrom-Json
    $rawResult = Invoke-ServerRunningPs1 -Action FileHashes $RemoteDirectory
    $rawResult | Write-Verbose
    [array]$filelist = $rawResult | Receive-LinesFromServer | ConvertFrom-Json

    $mo = $filelist | Select-Object -Property Algorithm, Path, Length, LocalPath | Measure-Object -Property Length -Sum

    $total = @{
        Length = $mo.Sum;
        Count  = $mo.Count
    }

    if (-not $OnlySum) {
        $total.files = $filelist
    }

    if (-not $total.Length) {
        $total.Length = 0
    }

    $failedFiles = @()

    $copiedFiles = $filelist | ForEach-Object {
        $relativePath = Resolve-RelativePathToAnotherPath -ParentPath $RemoteDirectory -FullPath $_.Path
        $localPath = Join-UniversalPath -Path $LocalDirectory -ChildPath $relativePath
        $_ | Add-Member @{LocalPath = $localPath} -PassThru
    } | ForEach-Object {
        $pp = Split-Path -Path $_.LocalPath -Parent
        if (-not (Test-Path -Path $pp -PathType Container)) {
            "creating new directory: $pp" | Write-Verbose
            New-Item -Path $pp -ItemType Directory | Out-Null
        }
        $_
    } | Where-Object {
        if ($_.Length -ne 0) {
            -not ((Test-Path -Path $_.LocalPath -PathType Leaf) -and ((Get-FileHash -Path $_.LocalPath).Hash -eq $_.Hash))
        }
        else {
            if (Test-Path -Path $_.LocalPath -PathType Leaf) {
                "file has zero length: $($_.Path), and already exists locally, skipping..." | Write-Verbose
                $false
            }
            else {
                "file has zero length: $($_.Path), and has'nt exist locally." | Write-Verbose
                $true
            }
        }
    } | ForEach-Object {
        if (Test-Path -Path $_.LocalPath -PathType Leaf) {
            "deleting local file $($_.LocalPath) because of unmatch hash." | Write-Verbose
        }
        $copied = $sshInvoker.ScpFrom($_.Path, $_.LocalPath, $false)
        if (($_.Length -ne 0) -and (Get-FileHash -Path $copied).Hash -ne $_.Hash) {
            Write-Error -Category ReadError -CategoryReason 'scp failed' -Message 'scp failed' -TargetObject $_ -ErrorId 'SCP_FROM'
            # throw "copy file from $($_.Path) to $($_.LocalPath) failed, file length is: $($_.Length), hash wasn't match."
            $failedFiles += $_
        }
        else {
            $_
        }
    }
    $mo = $copiedFiles | Measure-Object -Property Length -Sum
    $copied = @{
        Length = $mo.Sum;
        Count  = $mo.Count
    }

    if (-not $OnlySum) {
        $copied.files = $copiedFiles
    }
    if (-not $copied.Length) {
        $copied.Length = 0
    }

    $mo = $failedFiles | Measure-Object -Property Length -Sum
    $failed = @{
        Length = $mo.Sum;
        files  = $failedFiles;
        Count  = $mo.Count
    }

    if (-not $OnlySum) {
        $failed.files = $failedFiles
    }
    if (-not $failed.Length) {
        $failed.Length = 0
    }
    @{total = $total; copied = $copied; failed = $failed}
}


function Copy-FilesFromServer {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string[]]$RemotePathes,
        [Parameter(Mandatory = $true, Position = 1)][string]$LocalDirectory,
        [Parameter(Mandatory = $false)]$configuration
    )
    if (-not (Test-Path -Path $LocalDirectory -PathType Container)) {
        throw "${LocalDirectory} does'nt exist or is'nt a directory."
    }
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    $sshInvoker = [SshInvoker]::new($configuration.HostName, $configuration.IdentityFile)
    # discard return value.
    $r = $sshInvoker.ScpFrom($RemotePathes, $LocalDirectory)
    $r = $RemotePathes | ForEach-Object {
        Join-UniversalPath -Path $LocalDirectory -ChildPath (Split-UniversalPath -Path $_ -Leaf)
    }
    $r | Write-Verbose
    $r
}

function Get-MemoryFree {
    if ($PSVersionTable.Platform -eq 'unix') {
        $o = free | Where-Object {$_ -match 'Mem:\s+(\d+)\s+(\d+)'} | Select-Object -First 1
        $Total = ($Matches[1] -as [long]) * 1024
        $Used = ($Matches[2] -as [long]) * 1024
        $Free = $Total - $Used
        $Percent = '{0:p1}' -f ($Used / $Total)
        $Usedm = '{0:f1}' -f ($Used / 1048576)
        $Freem = '{0:f1}' -f ($Free / 1048576)
        $r = @{
            Total = $Total;
            Free = $Free;
            Used = $Used;
            Percent = $Percent
            Usedm = $Usedm;
            Freem = $Freem;
        }
    } else {
        $o = Get-CimInstance -ClassName win32_operatingsystem | Select-Object FreePhysicalMemory,TotalVisibleMemorySize
        $r = @{
            Total=$o.TotalVisibleMemorySize * 1024;
            Free=$o.FreePhysicalMemory * 1024;
        }
        $r.Used = $r.Total - $r.Free
        $r.Percent = '{0:p1}' -f ($r.Used / $r.Total)
        $r.Usedm = '{0:f1}' -f ($r.Used / 1048576)
        $r.Freem = '{0:f1}' -f ($r.Free / 1048576)
    }
    $r | ConvertTo-Json | Send-LinesToClient
}

function Get-DiskFree {
    if ($PSVersionTable.Platform -eq 'unix') {
        $r = df -l | Select-Object -Skip 1 | ForEach-Object {
            $a = $_ -split '\s+';
            $h = @{Name = $a[5];
                Used = (1024 * $a[2]) -As [Long]; 
                Free = (1024 * $a[3]) -As [Long];
            }
            $h.Percent = '{0:p1}' -f ($h.Used / ($h.Used + $h.Free))
            $h.Usedm = '{0:f1}' -f ($h.Used / 1048576)
            $h.Freem = '{0:f1}' -f ($h.Free / 1048576)
            $h
        }
    }
    else {
        $r = Get-PSDrive | Where-Object Name -Match '^.{1}$' | Select-Object -Property Name,Used,Free |
        Where-Object Used -GT 0 |
        ForEach-Object {
            $total = $_.Used + $_.Free
            $pc = '{0:p1}' -f ($_.Used / $total)
            $Usedm = '{0:f1}' -f ($_.Used / 1048576)
            $Freem = '{0:f1}' -f ($_.Free / 1048576)
            $_ | Add-Member @{Percent=$pc;Usedm=$Usedm;Freem=$Freem} -PassThru
        }
    }
    $r | ConvertTo-Json | Send-LinesToClient
}

function Find-BackupFilesToDelete {
    param (
        [Parameter(Mandatory = $true, Position = 0)][array]$FileOrFolders,
        [Parameter(Mandatory = $false, Position = 1)][string]$Pattern
    )
    [array]$pts = $Pattern.Trim() -split '\s+'
    $pts = $pts | ForEach-Object {[int]$_}

    if ($pts.Count -ne 7) {
        throw 'wrong prune pattern, must have 7 fields.'
    }
    if (($pts[1] -gt 0) -and ($pts[2] -gt 0)) {
        throw 'one of week and month field must be 0.'
    }
    $ga = @(
        '{0:yyyy}',
        '{0:yyyyMM}',
        '{0:yyyy}',
        '{0:yyyyMMdd}',
        '{0:yyyyMMddHH}',
        '{0:yyyyMMddHHmm}',
        '{0:yyyyMMddHHmmss}'
    )

    $ToIterator = $FileOrFolders
    for ($i = 0; $i -lt $pts.Count; $i++) {
        $pt = $pts[$i]
        $mftstr = $ga[$i]
        if ($pt -gt 0) {
            if ($i -ne 2) {
                $grps = $ToIterator |
                    Sort-Object -Property CreationTime | 
                    Group-Object -Property {$mftstr -f $_.CreationTime} |
                    Sort-Object -Property Name
            }
            else {
                $grps = $ToIterator |
                    Sort-Object -Property CreationTime |
                    Group-Object -Property {($mftstr -f $_.CreationTime) + [int]($_.CreationTime.DayOfYear / 7)} |
                    Sort-Object -Property Name
            }
            $toDeleteGrps = $grps | Select-Object -SkipLast $pt
            $remainGrpsButLast = $grps | Select-Object -Last $pt | Select-Object -SkipLast 1
            $lastGrp = $grps | Select-Object -Last 1

            $toDeleteGrps | ForEach-Object {
                $PSItem.Group | ForEach-Object {$_}
            }
            $remainGrpsButLast | ForEach-Object {
                $PSItem.Group | Select-Object -SkipLast 1
            }
            $ToIterator = $lastGrp.Group
        }
    }
}

<#
.SYNOPSIS
Prune backup files.

.DESCRIPTION
Prune backup files.

.PARAMETER BasePath
For files /a/a, /a/a.0, /a/a.1, /a/a is the base path.

.PARAMETER Pattern
7 segments, year,month,week,day,hour,minute, second.

.EXAMPLE
2 0 0 0 0 0 0, keep last 2 yearly copies in last minutes.
4 4 0 0 0 0 0, keep last 4 yearly and lastest monthly copies.

.NOTES
General notes
#>
function Resize-BackupFiles {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$BasePath,
        [Parameter(Mandatory = $false, Position = 1)][string]$Pattern
    )
    $p = Split-Path -Path $BasePath -Parent
    $FilesOrFolders = Get-ChildItem -Path $p

    $toDeletes = Find-BackupFilesToDelete -FileOrFolders $FilesOrFolders -Pattern $Pattern

    $toDeletes | Write-Verbose

    $toDeletes | ForEach-Object {
        $fn = $_.FullName
        if (Test-Path -Path $fn -PathType Container) {
            Remove-Item -Recurse -Path $fn -Force | Out-Null
        }
        else {
            Remove-Item -Path $fn -Force | Out-Null
        }
    }
    $toDeletes
}

function sanitizePath {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$Path
    )
    if ($Path -match "^'(.*)'$") {
        $Path = $Matches[1]
    }
    elseif ($Path -match '^"(.*)"$') {
        $Path = $Matches[1]
    }
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
function Split-UniversalPath {
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path,
        [switch]$Parent,
        [switch]$Leaf
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

function Get-Verbose {
    $b = [bool](Write-Verbose ([String]::Empty) 4>&1)
    if ($b) {
        "-Verbose"
    }
    else {
        ""
    }
}

function Resolve-RelativePathToAnotherPath {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$ParentPath,
        [Parameter(Mandatory = $true)]$FullPath,
        [Parameter(Mandatory = $false)]$Separator
    )
    if (-not [System.IO.Path]::IsPathRooted($FullPath)) {
        throw "Path is not absolute: $FullPath"
    }
    else {
        $pp = $ParentPath -replace '\\', '/'
        $FullPath = $FullPath -replace "^${pp}", ''
        $FullPath = $FullPath -replace '^/', ''

        if ($Separator -and ($Separator -in '/', '\')) {
            $FullPath -replace '/', $Separator
        }
        elseif ($ParentPath.IndexOf('\') -ne -1) {
            $FullPath -replace '/', '\'
        }
        else {
            $FullPath
        }
    }
}


function Write-ParameterWarning {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$wstring,
        [Parameter(Mandatory = $false)][int]$level = 1,
        [Parameter()][switch]$ThrowIt
    )
    $stars = (1..$wstring.Length | ForEach-Object {'*'}) -join ''
    $l = (Get-PSCallStack)[$level].Location
    "`n`n{0}`n`n`{1}`n`n{2}`n`n{3}`n`n" -f $stars, $l, $wstring, $stars | Write-Warning
    if ($ThrowIt) {
        throw $wstring
    }
}

function Install-SoftwareByExpression {
    param (
        [Parameter(Mandatory = $false, Position = 0)]$OneSoftware
    )
    if ($OneSoftware -and $OneSoftware.Install -and $OneSoftware.Install.Command) {
        $cmd = $OneSoftware.Install.Command
        $cmd = $cmd -f $OneSoftware.LocalPath
        Invoke-Expression -Command $cmd
    }
}

function Show-FilesInRPM {
    param (
        [Parameter(Mandatory = $false, Position = 0)]$rpm
    )
    # mysql57-community-release
    $cmd = "rpm -ql $rpm"
    $cmd | Write-Verbose
    Invoke-Expression -Command $cmd
}

function Test-SoftwareInstalled {
    param (
        [Parameter(Mandatory = $false, Position = 0)]$OneSoftware
    )
    if (-not $OneSoftware) {
        return $false
    }
    $idt = $OneSoftware.InstallDetect
    $idt.command | Write-Verbose
    $idt.expect | Write-Verbose
    $idt.unexpect | Write-Verbose
    $r = Invoke-Expression -Command $idt.command
    $r | Write-Verbose
    if ($idt.expect) {
        if ($idt.expect -eq 'aru') {
            $r
        }
        else {
            $r -match $idt.expect
        }
    }
    else {
        -not ($r -match $idt.unexpect)
    }
}

function Get-MaxBackupNumber {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Path
    )
    $p = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $p -PathType Container)) {
        New-Item -Path $p -ItemType Directory | Out-Null
    }
    $r = Get-ChildItem -Path "${Path}*" | 
        Foreach-Object {@{base = $_; dg = [int](Select-String -InputObject $_.Name -Pattern '(\d*)$' -AllMatches).matches.groups[1].Value}} |
        Sort-Object -Property @{Expression = {$_.dg}; Descending = $true} |
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
        [Parameter(Mandatory = $false, Position = 0)][string]$Path
    )
    $mn = 1 + (Get-MaxBackupNumber -Path $Path)
    "${Path}.${mn}"
}

<#
.SYNOPSIS
Given path /tmp/abc, get max abc.xxx folder.

.DESCRIPTION
Long description

.PARAMETER Path
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-MaxBackup {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Path
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Path,
        [switch]$keepOrigin
    )
    if ($Path -match '^(.*)\.\d+$') {
        $nx = Get-NextBackup -Path $Matches[1]
    }
    else {
        $nx = Get-NextBackup -Path $Path
    }

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
<#
.SYNOPSIS
Given a hashtable and an one level depth hashtable, Alter the vaule in the hashtable by the value in the one level hashtable.

.DESCRIPTION
Given a hashtable and an one level depth hashtable. if onelevelhashtable is {'a.b.c'=5}, then the hashtable.a.b.c will change to value 5.

.PARAMETER customob
Parameter description

.PARAMETER OneLevelHashTable
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-ChangedHashtable {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$customob,
        [Parameter(Mandatory = $false, Position = 1)][hashtable]$OneLevelHashTable
    )
    if (-not $OneLevelHashTable) {
        return $customob
    }
    $OneLevelHashTable.GetEnumerator() | ForEach-Object {
        $v = $_.Value
        [array]$ks = $_.Key -split "\."
        $lastKey = $ks | Select-Object -Last 1
        $preKeys = $ks | Select-Object -SkipLast 1
        $node = $customob
        foreach ($k in $preKeys) {
            if ($k -match "^(.*?)\[(\d+)\]$") {
                if (-not $node.($Matches[1])) {
                    throw "Key: $k does'nt exists."
                }
                $node = ($node.($Matches[1]))[$Matches[2]]
            }
            else {
                $node = $node.$k
            }
        }
        # $node.abc[0] = xx ?
        if ($lastKey -match "^(.*?)\[(\d+)\]$") {
            if (-not $node.($Matches[1])) {
                throw "lastKey: $lastKey does'nt exists."
            }
            ($node.($Matches[1]))[$Matches[2]] = $v
        }
        else {
            $node.$lastKey = $v
        }
    }
    $customob
}

function Get-OsDetail {
    $plt = [System.Environment]::OSVersion.Platform
    if ($plt -eq 'unix') {
        $h = Get-Content -Path "/etc/os-release" -ErrorAction SilentlyContinue | ConvertFrom-StringData
        if ($h) {
            [OsDetail]::new($plt, $h.ID, $h.VERSION_ID)
        }
        else {
            [OsDetail]::new($plt, $(uname -s), $(uname -r))
        }
    }
    else {
        [OsDetail]::new($plt, $plt, [System.Environment]::OSVersion.Version.ToString())
    }
}

function Start-PasswordPromptCommandSync {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Command,
        [Parameter(Mandatory = $false, Position = 1)][string]$Arguments,
        [Parameter(Mandatory = $false, Position = 2)][string]$mysqlpwd
    )
    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo.FileName = $Command
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardInput = $true
    $p.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::Default
    # $p.StartInfo.RedirectStandardError = $true
    $p.StartInfo.Arguments = $Arguments
    $p.StartInfo.CreateNoWindow = $true

    # https://docs.microsoft.com/en-us/dotnet/api/system.io.streamreader?view=netframework-4.7.2
    # https://docs.microsoft.com/en-us/dotnet/api/system.threading.tasks.task-1?view=netframework-4.7.2
    # https://docs.microsoft.com/en-us/dotnet/api/system.runtime.compilerservices.taskawaiter-1.iscompleted?view=netframework-4.7.2

    $v = $p.Start()
    # $OutputEncoding = [System.Text.Encoding]::Unicode

    $inputStreamWriter = $p.StandardInput
    $outputStreamReader = $p.StandardOutput
    $errorStreamReader = $p.StandardErro

    # $stream = [System.IO.StreamReader]::new($outputStreamReader,  [System.Text.Encoding]::Default)
    $outstr = ""

    # $p.StandardOutput.CurrentEncoding | Out-Host
    # [System.Text.Encoding]::Default | Out-Host
    # while (!$p.HasExited) {
    while ($true) {
        $start = Get-Date
        # $p.Kill()
        # $p.StandardError.ReadToEnd() | Out-Host
        # $t = $outputStreamReader.ReadLineAsync()

        # if ($t.GetAwaiter().IsCompleted) {
        #     $s = $t.Result
        #     if ($s -like '*序列号是*') {
        #         'oooooooooo' | Out-Host
        #     }
        #     if ($s -eq $null) {
        #         break
        #     }
        #     $s | Out-Host
        # } else {
        #     '------------------' | Out-Host
        # }


        # $s = $stream.ReadLine()

        
        # [System.text.Encoding]::Convert([System.Text.Encoding]::UTF8, [System.Text.Encoding]::Default, [System.Text.Encoding]::UTF8.GetBytes($s))
        # Start-Sleep -Seconds 1
    }


    # do {
    #     $line = $errorStreamReader.ReadLine()
    #     $line = $outputStreamReader.ReadToEnd()
    #     $line | Out-Host
    #     if (!$line) {
    #         $inputStreamWriter.WriteLine("dir");
    #     }
    #     elseif ($line -match '.*>\s*') {
    #         break
    #     }
    # } while ($true)
    
    # $p.WaitForExit()
    $p.Close()

}

function Start-PasswordPromptCommandAsync {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Command,
        [Parameter(Mandatory = $false, Position = 1)][string]$Arguments,
        [Parameter(Mandatory = $false, Position = 2)][string]$mysqlpwd
    )
    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo.FileName = $Command
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardInput = $true
    $p.StartInfo.RedirectStandardError = $true
    $p.StartInfo.Arguments = $Arguments
    $p.StartInfo.CreateNoWindow = $true
    # $inputStreamWriter = $p.StandardInput
    # $p | Out-Host
    $outvar = @{outstr = "55"; outp = $p; mcount = @{}}

    # $outvar | Out-Host

    
    Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -action {
        $emd = $Event.MessageData
        $emd.outstr += $EventArgs.data
        $ms = 'password:\s*$'
        if ($emd.outstr -match $ms) {
            if ($emd.mcount.ContainsKey($ms)) {
                $emd.mcount[$ms] += 1
            }
            else {
                $emd.mcount[$ms] = 0
            }
            if ($emd.mcount[$ms] -eq 0) {
                $emd.outp.StandardInput.WriteLine("dir")    
            }
            else {
                $emd.outp.StandardInput.WriteLine('exit')
            }
        }
    } -MessageData $outvar

    $script:OdrJob = Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -action {
        $emd = $Event.MessageData
        $emd.outstr += $EventArgs.data
        $ms = 'password:\s*$'
        if ($emd.outstr -match $ms) {
            if ($emd.mcount.ContainsKey($ms)) {
                $emd.mcount[$ms] += 1
            }
            else {
                $emd.mcount[$ms] = 0
            }
            if ($emd.mcount[$ms] -eq 0) {
                $emd.outp.StandardInput.WriteLine("dir")    
            }
            else {
                $emd.outp.StandardInput.WriteLine('exit')
            }
        }
    } -MessageData $outvar

    $running = $true

    Register-ObjectEvent -InputObject $p -EventName Exited -Action {
        $Event.MessageData.outstr | Out-Host
        $Event.MessageData.mcount | Out-Host
        $Event.MessageData | Out-Host
        $running = $false
    } -MessageData $outvar
    
    $v = $p.Start()
    # $jc = $script:OdrJob | Receive-Job
    $p.BeginOutputReadLine()
    $p.BeginErrorReadLine()

    # Start-Sleep -Seconds 3
    # $p.StandardInput.WriteLine($mysqlpwd)
    # $v = $p.StandardOutput.ReadToEnd()


    # do {
    #     if ($outvar.outstr) {
    #         $outvar.outstr | Out-Host
    #         $outvar.outstr = ""
    #     } else {
    #         Start-Sleep -Milliseconds 100
    #     }
    # } while ($running)
    # Get-Job -IncludeChildJob
    # $p.StandardInput.WriteLine("exit")
    $p.WaitForExit()
    $p.Close()

    # $psi = New-Object System.Diagnostics.ProcessStartInfo;
    # $psi.FileName = $Command; #process file
    # $psi.UseShellExecute = $false; #start the process from it's own executable file
    # $psi.RedirectStandardInput = $true; #enable the process to read from standard input
    # $p = [System.Diagnostics.Process]::Start($psi);

    # Start-Sleep -s 2 #wait 2 seconds so that the process can be up and running
    # $p.StandardInput.WriteLine(""); #StandardInput property of the Process is a .NET StreamWriter object
}

function Invoke-Executable {
    # Runs the specified executable and captures its exit code, stdout
    # and stderr.
    # Returns: custom object.
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$sExeFile,
        [Parameter(Mandatory = $false)]
        [String[]]$cArgs,
        [Parameter(Mandatory = $false)]
        [String]$sVerb
    )

    # Setting process invocation parameters.
    $oPsi = New-Object -TypeName System.Diagnostics.ProcessStartInfo
    $oPsi.CreateNoWindow = $true
    $oPsi.UseShellExecute = $false
    $oPsi.RedirectStandardOutput = $true
    $oPsi.RedirectStandardError = $true
    $oPsi.FileName = $sExeFile
    if (! [String]::IsNullOrEmpty($cArgs)) {
        $oPsi.Arguments = $cArgs
    }
    if (! [String]::IsNullOrEmpty($sVerb)) {
        $oPsi.Verb = $sVerb
    }

    # Creating process object.
    $oProcess = New-Object -TypeName System.Diagnostics.Process
    $oProcess.StartInfo = $oPsi

    # Creating string builders to store stdout and stderr.
    $oStdOutBuilder = New-Object -TypeName System.Text.StringBuilder
    $oStdErrBuilder = New-Object -TypeName System.Text.StringBuilder

    # Adding event handers for stdout and stderr.
    $sScripBlock = {
        if (! [String]::IsNullOrEmpty($EventArgs.Data)) {
            $EventArgs.Data
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    }
    $oStdOutEvent = Register-ObjectEvent -InputObject $oProcess `
        -Action $sScripBlock -EventName 'OutputDataReceived' `
        -MessageData $oStdOutBuilder
    $oStdErrEvent = Register-ObjectEvent -InputObject $oProcess `
        -Action $sScripBlock -EventName 'ErrorDataReceived' `
        -MessageData $oStdErrBuilder

    # Starting process.
    [Void]$oProcess.Start()
    $oProcess.BeginOutputReadLine()
    $oProcess.BeginErrorReadLine()
    [Void]$oProcess.WaitForExit()

    # Unregistering events to retrieve process output.
    Unregister-Event -SourceIdentifier $oStdOutEvent.Name
    Unregister-Event -SourceIdentifier $oStdErrEvent.Name

    $oResult = New-Object -TypeName PSObject -Property ([Ordered]@{
            "ExeFile"  = $sExeFile;
            "Args"     = $cArgs -join " ";
            "ExitCode" = $oProcess.ExitCode;
            "StdOut"   = $oStdOutBuilder.ToString().Trim();
            "StdErr"   = $oStdErrBuilder.ToString().Trim()
        })

    return $oResult
}

function New-TemporaryDirectory {
    $t = New-TemporaryFile
    Remove-Item $t
    New-Item -Path $t -ItemType Container
}

function Split-Files {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$CombinedFile,
        [Parameter(Mandatory = $false, Position = 1)][string]$dstFolder,
        [Parameter(Mandatory = $false, Position = 2)][int]$bufsize = 1024

    )

    $instream = [System.IO.File]::OpenRead($CombinedFile)
    $barr = New-Object byte[] $bufsize
    if (-not $dstFolder) {
        $dstFolder = New-TemporaryDirectory
    }
    else {
        if (-not (Test-Path -Path $dstFolder -PathType Container)) {
            New-Item -Path $dstFolder -ItemType "directory" | Out-Null
        }
    }

    $step = 0 # 0 start, 1 filename length read, 2 filename read, 3 file length read, 4 file content read.
    [array]$tmpBytesHolder = @()
    $fnlen = 0
    $readLen = $true
    $utf8 = [System.Text.Encoding]::UTF8
    while ( $readLen ) {
        switch ($step) {
            0 { 
                if ($tmpBytesHolder.Length -ge 4) {
                    $fnlenBytes = $tmpBytesHolder | Select-Object -First 4
                    $fnlen = [bitconverter]::ToInt32($fnlenBytes, 0)
                    $tmpBytesHolder = $tmpBytesHolder | Select-Object -Skip 4
                    $step = 1
                }
                else {
                    $readLen = $instream.Read($barr, 0, $bufsize)
                    $tmpBytesHolder += $barr | Select-Object -First $readLen
                }
                break
            }
            1 {
                if ($tmpBytesHolder.Length -ge $fnlen) {
                    $fnBytes = $tmpBytesHolder | Select-Object -First $fnlen
                    $tmpBytesHolder = $tmpBytesHolder | Select-Object -Skip $fnlen
                    $fn = $utf8.GetString($fnBytes)
                    $step = 2
                }
                else {
                    $readLen = $instream.Read($barr, 0, $bufsize)
                    $tmpBytesHolder += $barr | Select-Object -First $readLen
                }
                break
            }
            2 {
                if ($tmpBytesHolder.Length -ge 4) {
                    $fclenBytes = $tmpBytesHolder | Select-Object -First 4
                    $fclen = [bitconverter]::ToInt32($fclenBytes, 0)
                    $tmpBytesHolder = $tmpBytesHolder | Select-Object -Skip 4
                    $step = 3
                }
                else {
                    $readLen = $instream.Read($barr, 0, $bufsize)
                    $tmpBytesHolder += $barr | Select-Object -First $readLen
                }
                break
            }
            3 {
                $dst = Join-Path -Path $dstFolder -ChildPath $fn
                $ostream = [System.IO.File]::OpenWrite($dst)

                if ($tmpBytesHolder.Length -ge $fclen) {
                    $ostream.write(($tmpBytesHolder | Select-Object -First $fclen), 0, $fclen)
                    $tmpBytesHolder = $tmpBytesHolder | Select-Object -Skip $fclen
                    $step = 0 #process one file over.
                }
                else {
                    if ($tmpBytesHolder.Length -gt 0) {
                        $ostream.write($tmpBytesHolder, 0, $tmpBytesHolder.Length)
                        $fclen -= $tmpBytesHolder.Length
                        $tmpBytesHolder = @()
                    }
                    while ($readLen = $instream.Read($barr, 0, $bufsize)) {
                        if ($readLen -eq $bufsize) {
                            $readed = $barr
                        }
                        else {
                            $readed = $barr | Select-Object -First $readLen
                        }
                        if ($fclen -gt $readLen) {
                            $ostream.write($readed, 0, $readLen)
                            $fclen -= $readLen
                        }
                        else {
                            $lastBytes = $readed | Select-Object -First $fclen
                            $ostream.write($lastBytes, 0, $fclen)
                            $tmpBytesHolder = $readed | Select-Object -Skip $fclen
                            $step = 0 # process one file over.
                            break # should break out this loop. readed bytes alreay save to tempBytesHolder.
                        }
                    }
                }
                $ostream.flush()
                $ostream.close()
                $ostream.dispose()
            }
            Default {}
        }
    }
    $instream.close()
    $instream.dispose()

    $dstFolder
}

<#
#>
function Join-Files {
    param (
        [Parameter(Mandatory = $true, Position = 0)][object[]]$FileNamePairs,
        [Parameter(Mandatory = $false, Position = 1)][int]$bufsize = 1024
    )
    
    $hts = $FileNamePairs | ForEach-Object {
        if ($_ -is [string]) {
            @{file = $_; name = (Split-Path -Path $_ -Leaf)}
        }
        else {
            $_
        }
    }
    $combined = New-TemporaryFile
    $ostream = [System.IO.File]::OpenWrite($combined)

    $utf8 = [System.Text.Encoding]::UTF8
    foreach ($item in $hts) {
        [int32]$flen = (Get-Item -Path $item.file).Length
        $name = $item.name
        $nbytes = $utf8.GetBytes($name)
        [int32]$nlen = $nbytes.Length
        $ostream.write([bitconverter]::GetBytes($nlen), 0, 4) # write int32 of name length
        $ostream.write($nbytes, 0, $nlen) # write name bytes.
        $ostream.write([bitconverter]::GetBytes($flen), 0, 4) # write int32 of file length

        $instream = [System.IO.File]::OpenRead($item.file) # write file content.

        $barr = New-Object byte[] $bufSize
        while ( $bytesRead = $instream.Read($barr, 0, $bufsize)) {
            $ostream.Write($barr, 0, $bytesRead);
        }
        $instream.close()
        $instream.dispose()       
    }
    $ostream.flush()
    $ostream.close()
    $ostream.dispose()
    $combined
}


# https://wiki.openssl.org/index.php/Command_Line_Utilities
function Protect-ByOpenSSL {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$PublicKeyFile,
        [Parameter(Mandatory = $true, Position = 1)][string]$PlainFile
    )

    try {
        $openssl = $Global:configuration.ClientOpenssl

        if ($Global:configuration.ClientEnv) {
            $Global:configuration.ClientEnv | Get-Member -MemberType NoteProperty | Foreach-Object {
                $k = $_.Name
                $v = $Global:configuration.ClientEnv.$k
                Set-Item Env:$k -Value $v
            }
        }
        $plainPassFile = New-TemporaryFile
        Invoke-Command -Command {& $openssl rand -base64 64 | Out-File $plainPassFile -Encoding ascii -NoNewline}

        # Get-Content -Path $plainPassFile | Out-Host

        $encryptPassFile = New-TemporaryFile
        $encryptFile = New-TemporaryFile
        $cmd = "& '${openssl}' enc -aes256 -e -in $PlainFile -out $encryptFile -pass file:$plainPassFile"
        "encrypt large file: $cmd" | Write-Verbose
        Invoke-Expression -Command $cmd

        $cmd = "& '${openssl}' pkeyutl -encrypt -inkey $PublicKeyFile -pubin -in $plainPassFile -out $encryptPassFile"
        "encrypt password file: $cmd" | Write-Verbose
        Invoke-Expression -Command $cmd
        Join-Files -FileNamePairs @{file = $encryptPassFile; name = "pass"}, @{file = $encryptFile; name = "content"}
    }
    finally {
        if ((Test-Path -Path $plainPassFile)) {
            Remove-Item -Path $plainPassFile
        }
    }
}

function UnProtect-ByOpenSSL {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$PrivateKeyFile,
        [Parameter(Mandatory = $true, Position = 1)][string]$CombinedEncriptedFile,
        [Parameter(Mandatory = $false, Position = 2)][string]$openssl
    )
    try {
        if (-not $openssl) {
            $openssl = $Global:configuration.openssl
        }

        $d = Split-Files -CombinedFile $CombinedEncriptedFile # pass.txt and content.txt
        $encryptedKeyFile = Join-Path -Path $d -ChildPath "pass"
        $encryptedFile = Join-Path -Path $d -ChildPath "content"
        $decryptedKeyFile = New-TemporaryFile
        $cmd = "& '${openssl}' pkeyutl -decrypt -inkey $PrivateKeyFile -in $encryptedKeyFile -out $decryptedKeyFile"
        "decrypt key file: $cmd" | Write-Verbose
        Invoke-Expression -Command $cmd
        $decryptedFile = New-TemporaryFile
        $cmd = "& '${openssl}' enc -aes256 -d -in $encryptedFile -out $decryptedFile -pass file:$decryptedKeyFile"
        if ($LASTEXITCODE -ne 0) {
            throw "decrypt error."
        }
        "decrypt large file: $cmd" | Write-Verbose
        Invoke-Expression -Command $cmd
        $decryptedFile
    }
    finally {
        # if ((Test-Path -Path $d)) {
        #     Remove-Item -Recurse -Force -Path $d
        # }
        # if ((Test-Path -Path $decryptedKeyFile)) {
        #     Remove-Item -Force -Path $decryptedKeyFile
        # }
    }
}

function Get-Base64FromFile {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$File
    )
    $bytes = Get-Content -Path $File -Encoding Byte
    [Convert]::ToBase64String($Bytes)
}

function Get-FileFromBase64 {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Base64,
        [Parameter(Mandatory = $false, Position = 1)][string]$OutFile
    )
    $bytes = [Convert]::FromBase64String($Base64)
    if (-not $OutFile) {
        $OutFile = New-TemporaryFile
    }
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        Set-Content -Path $OutFile -Value $bytes -AsByteStream
    }
    else {
        Set-Content -Path $OutFile -Value $bytes -Encoding Byte
    }
    $OutFile
}

function ConvertFrom-NameValuePair {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]$piped
    )
    Begin {
        $ht = @{}
    }
    Process {
        foreach ($item in $_) {
            $ht[$item.name] = $item.value
        }
    }
    End {
        $ht
    }
}

<#
.SYNOPSIS
convert output like bellow to hash table.
Id      : 21860
Handles : 277
CPU     : 1
SI      : 2
Name    : YunDetectService

.DESCRIPTION
Long description

.PARAMETER ListFormatOutput
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ConvertFrom-ListFormatOutput {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]$ListFormatOutput
    )
    Begin {
        $ht = @{}
    }
    Process {
        if ($PSItem) {
            if ($PSItem -match '^\s*(.*?)\s*:\s*(.*?)\s*$') {
                $ht[$Matches[1]] = $Matches[2]
            }
        }
        else {
            if ($ht.Keys.Count) {
                $ht
                $ht = @{}
            }
        }
    }
    End {
        if ($ht.Keys.Count) {
            $ht
        }
    }
}

function Send-LinesToClient {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]$InputObject
    )
    Begin {
        "for-easyinstaller-client-use-start"
    }
    Process {
        foreach ($item in $InputObject) {
            $item 
        }
    }
    End {
        "for-easyinstaller-client-use-end"
    }
}

function Receive-LinesFromServer {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]$toClient,
        [Parameter(Mandatory = $false)][int]$section = 0
    )
    Begin {
        $r = @()
        $started = $false
        $idx = -1
    }
    Process {
        if ($_ -eq "for-easyinstaller-client-use-end") {
            $started = $false
        }
        if ($started -and ($section -eq $idx)) {
            if ($_ -notmatch '^VERBOSE:\s{1}') {
                $_
            }
        }
        if ($_ -eq "for-easyinstaller-client-use-start") {
            $started = $true
            $idx += 1
        }
    }
}

# openssl rsa -in C:\Users\Administrator\192.168.33.110.ifile -pubout -out public_key.pem
function Get-OpenSSLPublicKey {
    $ossl = $Global:configuration.openssl
    $prik = $Global:configuration.PrivateKeyFile
    $tmp = (New-TemporaryFile).FullName
    $cmd = "$ossl rsa -in $prik -pubout -out $tmp"
    $cmd | Write-Verbose
    $r = Invoke-Expression -Command $cmd
    $r | Write-Verbose
    $tmp | Send-LinesToClient
}

<#
.SYNOPSIS
Convert Remains parameters to a hashtable.

.DESCRIPTION
Long description

.PARAMETER hints
Parameter description

.PARAMETER InputObject
From pipeline.

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-RemainParameterHashtable {
    param (
        [Parameter(Mandatory = $false, Position = 0)]$hints,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]$InputObject
    )
    
    Begin {
        $htvars = @{_orphans = @()}
        $lastvar = $null
    } 
    Process {
        if ($hints) {
            $hints | Get-RemainParameterHashtable
        }
        else {
            if ($InputObject -match '^-') {
                #New parameter
                $lastvar = $InputObject -replace '^-'
                $htvars[$lastvar] = $null
            }
            else {
                #Value
                if ($lastvar) {
                    $htvars[$lastvar] = $InputObject
                    $lastvar = $null
                }
                else {
                    $htvars._orphans += $InputObject
                }
            }
        }
    } 
    End {
        $htvars
    }
}

# $SecurePassword = Get-Content C:\Users\tmarsh\Documents\securePassword.txt | ConvertTo-SecureString
# $UnsecurePassword = (New-Object PSCredential "user",$SecurePassword).GetNetworkCredential().Password

function Protect-PasswordByOpenSSLPublicKey {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$PublicKeyFile,
        [Parameter(Mandatory = $false)][securestring]$ss
    )
    $f = New-TemporaryFile
    $outf = New-TemporaryFile
    try {
        if (-not $ss) {
            $ss = Read-Host -AsSecureString -Prompt "Please input the password to protect"
        }
        $plainPassword = (New-Object PSCredential "user", $ss).GetNetworkCredential().Password
        $plainPassword | Out-File -FilePath $f -NoNewline -Encoding ascii
        $openssl = $Global:configuration.ClientOpenssl
        $cmd = "& '${openssl}' pkeyutl -encrypt -inkey $PublicKeyFile -pubin -in $f -out $outf"
        $cmd | Write-Verbose
        Invoke-Expression -Command $cmd
        $s = Get-Base64FromFile $outf
        $s
    }
    finally {
        Remove-Item -Force -Path $f, $outf 
    }
}

function UnProtect-PasswordByOpenSSLPublicKey {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$base64,
        [Parameter(Mandatory = $false, Position = 1)][string]$PrivateKeyFile,
        [Parameter(Mandatory = $false, Position = 2)][string]$OpenSSL
    )
    $f = Get-FileFromBase64 -Base64 $base64
    $outf = New-TemporaryFile
    try {
        if (-not $OpenSSL) {
            $OpenSSL = $Global:configuration.openssl
        }
        if (-not $PrivateKeyFile) {
            $PrivateKeyFile = $Global:configuration.PrivateKeyFile
        }
        $cmd = "& '${OpenSSL}' pkeyutl -decrypt -inkey $PrivateKeyFile -in $f -out $outf"
        $cmd | Write-Verbose
        Invoke-Expression -Command $cmd
        $s = Get-Content -Path $outf -Encoding Ascii
        $s
    }
    finally {
        Remove-Item -Force -Path $f, $outf 
    }
}
function Invoke-ServerRunningPs1 {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Action,
        [parameter(Mandatory = $false)][switch]$notCombineError,
        [parameter(Mandatory = $false)][switch]$NotCleanUp,
        [switch]$Json,
        [parameter(Mandatory = $false,
            ValueFromRemainingArguments = $true)]
        [String[]]
        $hints
    )
    $c = $Global:configuration
    $sshInvoker = Get-SshInvoker

    $osConfig = $c.OsConfig

    # it's a fixed name on server. so it's no necessary to tell the server script where it is.
    # $toServerConfigFile = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath 'config.json'

    $entryPoint = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath $osConfig.ServerSide.EntryPoint

    if ($NotCleanUp) {
        $ncp = "-NotCleanUp"
    }
    else {
        $ncp = ""
    }

    switch ($c.ServerLang) {
        'powershell' { 
            $rcmd = "{0} -f {1} -action {2} {3} {4} {5}" -f $c.ServerExec, $entryPoint, $action, $ncp, (Get-Verbose), ($hints -join ' ')
         }
         'python' {
            $rcmd = "{0} {1} --action={2} {3}" -f $c.ServerExec, $entryPoint, $action, ($hints -join ' ')
         }
        Default {
            throw "unknown ServerLang property in configration file: $($c.ServerLang)"
        }
    }
    $rcmd | Out-String | Write-Verbose
    $sshInvoker.Invoke($rcmd, (-not $notCombineError))
}


trap {
    $Error[0].TargetObject | Send-LinesToClient
    break
}