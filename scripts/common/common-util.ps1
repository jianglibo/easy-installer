﻿class OsDetail {
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
        [Parameter(Mandatory = $true)]
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


function Get-Configuration {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$ConfigFile,
        [Parameter()][switch]$ServerSide
    )
    $vcf = Resolve-Path -Path $ConfigFile -ErrorAction SilentlyContinue

    if (-not $vcf) {
        $m = "ConfigFile ${ConfigFile} doesn't exists."
        Write-ParameterWarning -wstring $m
        return
    }
    $c = Get-Content -Path $vcf | ConvertFrom-Json

    if (-not $ServerSide) {
        if ($c.IdentityFile) {
            if (-not (Test-Path -Path $c.IdentityFile -PathType Leaf)) {
                Write-ParameterWarning -wstring "IdentityFile property in $vcf point to an unexist file."
                return
            }
            else {
                return $c
            }
        }
        
        if (-not $c.ServerPassword) {
            Write-ParameterWarning -wstring "Neither IdentityFile Nor ServerPassword property exists in ${vcf}."
            return
        }
    }
    $c
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

function Get-Verbose {
    $b = [bool](Write-Verbose ([String]::Empty) 4>&1)
    if ($b) {
        "-Verbose"
    }
    else {
        ""
    }
}


function Write-ParameterWarning {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$wstring,
        [Parameter(Mandatory = $false)][int]$level = 1
    )
    $stars = (1..$wstring.Length | ForEach-Object {'*'}) -join ''
    $l = (Get-PSCallStack)[$level].Location
    "`n`n{0}`n`n`{1}`n`n{2}`n`n{3}`n`n" -f $stars, $l, $wstring, $stars | Write-Warning
}

function Get-OsConfiguration {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration
    )
    $osConfig = $configuration.SwitchByOs.($configuration.OsType)

    if (-not $osConfig) {
        $s = "The 'OsType' property is $($configuration.OsType), But there is no corresponding item in 'SwitchByOs': $ConfigFile"
        Write-ParameterWarning -wstring $s -level 2
        throw $s
    }
    $osConfig
}

function Test-SoftwareInstalled {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration
    )

    $osConfig = Get-OsConfiguration -configuration $configuration
    $idt = $osConfig.ServerSide.InstallDetect
    $idt.command | Write-Verbose
    $idt.expect | Write-Verbose
    $idt.unexpect | Write-Verbose
    $r = Invoke-Expression -Command $idt.command
    $r | Write-Verbose
    if ($idt.expect) {
        $idt.expect | Write-Verbose
        $r -match $idt.expect
    }
    else {
        -not ($r -match $idt.unexpect)
    }
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

function Get-ChangedHashtable {
    param (
        [Parameter(Mandatory = $false, Position = 1)]$customob,
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

function Start-PasswordPromptCommand {
    param (
        [Parameter(Mandatory = $true, Position = 1)][string]$Command
    )
    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo.FileName = $Command
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardInput = $true
    $p.StartInfo.Arguments = ""
    # $inputStreamWriter = $p.StandardInput
    $p | Out-Host
    $outvar = @{outstr="55";outp = $p}

    # $outvar | Out-Host

    Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -action {
        # ddkss
        # $EventArgs.data | Write-Host

        # [console]::WriteLine($EventArgs.data)
        # $EventArgs | gm | Out-Host
        # "ssssssss" | Out-Host
        # $Event.MessageData | Out-Host
        # $Event.MessageData.$outstr | Out-Host
        $Event.MessageData.outstr += $EventArgs.data
        $Event.MessageData.outp | Out-Host
        # $Event.MessageData.outp.StandardInput.WriteLine("exit")
        # if (-not [string]::IsNullOrEmpty($EventArgs.data)) {
        #     {
        #         Write-Host "a"
        #     }
        # }
    } -MessageData $outvar

    $running = $true

    Register-ObjectEvent -InputObject $p -EventName Exited -Action {
        $Event.MessageData.outstr | Out-Host
        $running = $false
    } -MessageData $outvar
    
    $p.Start()

    $p.BeginOutputReadLine()

    # do {
    #     if ($outvar.outstr) {
    #         $outvar.outstr | Out-Host
    #         $outvar.outstr = ""
    #     } else {
    #         Start-Sleep -Milliseconds 100
    #     }
    # } while ($running)
    $p.StandardInput.WriteLine("exit")
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