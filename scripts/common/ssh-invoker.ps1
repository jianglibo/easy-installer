enum ShellName {
    bash
    pwsh
}

class SshInvoker {
    [string]$UserName = "root"
    [string]$HostName
    [string]$ifile

    [int]$ExitCode
    [int]$SshPort
    [string[]]$result
    [string]$sshStr
    [string] hidden $ShellName
    [string]$commandName

    SshInvoker([string]$HostName, [string]$ifile, [int]$SshPort) {
        $this.HostName = $HostName
        $this.ShellName = [ShellName]::bash
        $this.ifile = $ifile
        $this.SshPort = $SshPort
        $this.sshStr = "ssh -p $SshPort -i $ifile $($this.UserName)@${HostName}"
    }

    SshInvoker([string]$HostName, [string]$ifile, [int]$SshPort, [ShellName]$ShellName) {
        $this.HostName = $HostName
        $this.ShellName = $ShellName
        $this.ifile = $ifile
        $this.SshPort = $SshPort
        $this.sshStr = "ssh -p $SshPort -i $ifile $($this.UserName)@${HostName}"
    }

    [bool]isCommandNotFound() {
        switch ($this.ShellName) {
            bash { 
                return ($this.result -like "*command not found*")
            }
            Default {}
        }
        return $false
    }

    [bool]exitZero() {
        return ($this.ExitCode -eq 0)
    }

    [bool]isPwshInstalled() {
        return $this.CanInvoke('pwsh -Command echo 0')
    }

    [bool]canInvoke([string]$cmd) {
        $this.Invoke($cmd) | Out-Null
        return (-not $this.IsCommandNotFound())
    }

    [string[]] invoke([string]$cmd) {
        return $this.invoke($cmd, $true)
    }

    [string[]] invoke([string]$cmd, [bool]$combineError) {
        switch ($this.ShellName) {
            bash { 
                return $this.InvokeBash($cmd, $combineError)
            }
            Default {}
        }
        return null
    }

    [string[]] hidden invokeBash([string]$cmd, [bool]$combineError) {
        if ($combineError) {
            $c = "$($this.sshStr) `"$cmd 2>&1`""
        }
        else {
            $c = "$($this.sshStr) `"$cmd`""
        }
        $c | Write-Verbose
        $this.commandName = $c
        $r = Invoke-Expression -Command $c
        $this.ExitCode = $LASTEXITCODE
        $this.result = $r;
        return $r;
    }

    [bool]isFileExists([string]$remotePath) {
        $r = $this.Invoke("ls ${remotePath}")
        return ($r -notlike '*No such file or directory*')
    }

    <#
        remotePath maybe point to a directory or name a file.
    #>
    [string[]] hidden scpInternalTo([string]$localPathes, [string]$remotePath, [bool]$targetIsDir, [bool]$retry) {
        [array]$ary = $localPathes -split ' '

        if ($ary.Count -eq 0) {
            throw "No file to copy."
        }
        $hasDir = $false
        foreach ($localPath in $ary) {
            if (-not (Test-Path -Path $localPath)) {
                throw "Local file $localPath doesn't exist."
            }
            if ((Test-Path -Path $localPath -PathType Container)) {
                $hasDir = $true
            }
        }

        if ($hasDir -and ($ary.Count -gt 1)) {
            throw "If copy a directory then only one directory is allowed."
        }

        $roption = if ($hasDir) {'-r'} else {''}

        $scpStr = "scp -P {0} -i {1} {2} {3} {4}@{5}:{6} 2>&1" -f $this.SshPort, $this.ifile, $roption, $localPathes, $this.UserName, $this.HostName, $remotePath

        $scpStr | Write-Verbose

        $this.commandName = $scpStr

        $r = Invoke-Expression -Command $scpStr
        $this.result = $r
        $this.ExitCode = $LASTEXITCODE
        if ($r -like "*No such file or directory*") {
            if ($retry) {
                throw 1000
            }
            if ($targetIsDir) {
                $this.invoke("mkdir -p ${remotePath}")
            }
            else {
                $this.invoke("mkdir -p $(Split-UniversalPath -Parent $remotePath)")
            }
            return $this.scpInternalTo($localPathes, $remotePath, $targetIsDir, $true)
        }
        else {
            if ($this.ExitCode -ne 0) {
                throw $r
            }
            if ($targetIsDir) {
                return $ary | ForEach-Object {Join-UniversalPath -Path $remotePath -ChildPath (Split-UniversalPath -Path $_)}
            }
            else {
                return $remotePath
            }
        }
    }

    [string[]] hidden scpInternalFrom([string]$remotePath, [string]$localPath, [bool]$RemoteIsDir) {

        $p = Split-Path -Path $localPath -Parent

        if (-not (Test-Path -Path $p)) {
            throw "${p} does'nt exist."
        }

        $roption = if ($RemoteIsDir) {'-r'} else {''}
        $scpStr = "scp -P {0} -i {1} {2} {3}@{4}:{5} {6} 2>&1" -f $this.SshPort, $this.ifile, $roption, $this.UserName, $this.HostName, $remotePath, $localPath

        $scpStr | Write-Verbose

        $this.commandName = $scpStr

        $r = Invoke-Expression -Command $scpStr
        $this.result = $r
        $this.ExitCode = $LASTEXITCODE
        if ($this.ExitCode -ne 0) {
            throw $r
        }
        if (Test-Path -Path $localPath -PathType Container) {
            return (Join-UniversalPath -Path $localPath -ChildPath (Split-UniversalPath -Path $remotePath -Leaf))
        } else {
            return $localPath
        }
    }

    [string[]] hidden scpInternalFroms([string[]]$RemotePathes, [string]$LocalDirectory) {

        if (-not (Test-Path -Path $LocalDirectory -PathType Container)) {
            throw "${LocalDirectory} does'nt exist or is'nt a directory."
        }

        $fns = $RemotePathes -join ' '

        $scpStr = "scp -P {0} -i {1} {2}@{3}:{4} {5} 2>&1" -f $this.SshPort, $this.ifile, $this.UserName, $this.HostName, "`"$fns`"", $LocalDirectory

        $scpStr | Write-Verbose

        $this.commandName = $scpStr

        $r = Invoke-Expression -Command $scpStr
        $this.result = $r
        $this.ExitCode = $LASTEXITCODE
        if ($this.ExitCode -ne 0) {
            throw $r
        }
        $r = @()
        foreach ($rp in $RemotePathes) {
            $r += Join-UniversalPath -Path $LocalDirectory -ChildPath (Split-UniversalPath -Path $rp -Leaf)
        }
        return $r
    }

    [string[]]ScpTo([string]$localPathes, [string]$remotePath, [bool]$targetIsDir) {
        return $this.scpInternalTo($localPathes, $remotePath, $targetIsDir, $false)
    }

    [string[]]ScpFrom([string]$remotePath, [string]$localPath, [bool]$RemoteIsDir) {
        return $this.scpInternalFrom($remotePath, $localPath, $RemoteIsDir)
    }

    [string[]]ScpFrom([string[]]$RemotePathes, [string]$LocalDirectory) {
        return $this.scpInternalFroms($RemotePathes, $LocalDirectory)
    }

    [string]unzip([string]$zipFile, [string]$expandDir) {
        $c = "unzip -d $expandDir $zipFile"
        $this.invoke($c)
        if ($this.isCommandNotFound()) {
            throw "unzip command not found."
        }
        return $expandDir
    }
}
