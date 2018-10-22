$CommonScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $CommonScriptsDir | Split-Path -Parent | Split-Path  -Parent

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

function Get-SoftwarePackages {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$TargetDir,
        [Parameter(Mandatory = $true, Position = 1)]$Softwares
    )
    if (-not (Test-Path -Path $TargetDir -PathType Container)) {
        New-Item -Path $TargetDir -ItemType "directory"
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
function Get-Configuration {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$ConfigFile,
        [Parameter()][switch]$ServerSide
        # [Parameter(Mandatory = $false)][string]$PrivateKeyFile,
        # [Parameter(Mandatory = $false)][string]$OpenSSL
    )
    $vcf = Resolve-Path -Path $ConfigFile -ErrorAction SilentlyContinue
    if (-not $vcf) {
        $m = "ConfigFile ${ConfigFile} doesn't exists."
        Write-ParameterWarning -wstring $m
        return
    }

    # if ($PrivateKeyFile) {
    #     $decrypted = UnProtect-ByOpenSSL -PrivateKeyFile $PrivateKeyFile -CombinedEncriptedFile $vcf -OpenSSL $OpenSSL
    #     $c = Get-Content -Path $decrypted | ConvertFrom-Json
    #     Remove-Item -Path $decrypted -Force
    # }
    # else {
    $c = Get-Content -Path $vcf | ConvertFrom-Json
    # }

    if (-not $ServerSide) {

        if (-not ($c.IdentityFile -or $c.ServerPassword)) {
            Write-ParameterWarning -wstring "Neither IdentityFile Nor ServerPassword property exists in ${vcf}." -ThrowIt
        }
        if ($c.IdentityFile) {
            if (-not (Test-Path -Path $c.IdentityFile -PathType Leaf)) {
                Write-ParameterWarning -wstring "IdentityFile property in $vcf point to an unexist file." -ThrowIt
            }
        }
        # $capp = Get-Content -Path ($ProjectRoot | Join-Path -ChildPath "app.json") | ConvertFrom-Json
        # if (-not (Get-Command $capp.openssl)) {
        #     $s = "$($capp.openssl) does'nt exists."
        #     Write-ParameterWarning -wstring $s    
        #     throw $s        
        # } else {
        #     $c | Add-Member -MemberType NoteProperty -Name "ClientOpenssl" -Value $capp.openssl
        # }
        $c | Add-Member -MemberType ScriptMethod -Name "DownloadPackages" -Value {
            $dl = Join-Path -Path $ProjectRoot -ChildPath "downloads" | Join-Path -ChildPath $this.myname
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

function Test-SoftwareInstalled {
    $osConfig = $Global:configuration.OsConfig
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
            New-Item -Path $dstFolder -ItemType "directory"
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
    Set-Content -Path $OutFile -Value $bytes -Encoding Byte
    $OutFile
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
            $PrivateKeyFile = $Global:PrivateKeyFile
        }
        $cmd = "& '${OpenSSL}' pkeyutl -decrypt -inkey $PrivateKeyFile -in $f -out $outf"
        Invoke-Expression -Command $cmd
        $s = Get-Content -Path $outf -Encoding Ascii
        $s
    }
    finally {
        Remove-Item -Force -Path $f, $outf 
    }
}