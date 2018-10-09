enum ShellName {
    bash
    pwsh
}

class SshInvoker {
    [string]$UserName="root"
    [string]$HostName
    [string]$ifile

    [int]$ExitCode
    [string]$result
    [string]$sshStr
    [string] hidden $ShellName
    [string]$commandName

    SshInvoker([string]$HostName, [string]$ifile){
        $this.HostName = $HostName
        $this.ShellName = [ShellName]::bash
        $this.ifile = $ifile
        $this.sshStr = "ssh -i $ifile $($this.UserName)@${HostName}"
    }

    SshInvoker([string]$HostName, [string]$ifile, [ShellName]$ShellName){
        $this.HostName = $HostName
        $this.ShellName = $ShellName
        $this.ifile = $ifile
        $this.sshStr = "ssh -i $ifile $($this.UserName)@${HostName}"
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

    [string] invoke([string]$cmd) {
        switch ($this.ShellName) {
            bash { 
                return $this.InvokeBash($cmd)
             }
            Default {}
        }
        return null
    }

    [string] hidden invokeBash([string]$cmd) {
        $c =  "$($this.sshStr) `"$cmd 2>&1`""
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
    [string] hidden scpInternal([string]$localPathes, [string]$remotePath, [bool]$targetIsDir, [bool]$retry) {
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

        $scpStr = "scp -i {0} {1} {2} {3}@{4}:{5} 2>&1" -f $this.ifile,$roption,$localPathes,$this.UserName,$this.HostName,$remotePath
        # $scpStr | Out-Host
        # $scpStr = "scp -i $($this.ifile) ${roption} ${localPath} $($this.UserName)@$($this.HostName):${remotePath} 2>&1"

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
            } else {
                $this.invoke("mkdir -p $(Split-UniversalPath -Parent $remotePath)")
            }
            return $this.scpInternal($localPathes, $remotePath, $targetIsDir, $true)
        } else {
            if ($targetIsDir) {
                return $ary | ForEach-Object {Join-UniversalPath -Path $remotePath -ChildPath (Split-UniversalPath -Path $_)}
            } else {
                return $remotePath
            }
        }
    }

    [string]scp([string]$localPathes, [string]$remotePath, [bool]$targetIsDir) {
        return $this.scpInternal($localPathes, $remotePath, $targetIsDir, $false)
    }

    [string]unzip([string]$zipFile, [string]$expandDir) {
        $c = "unzip -d $expandDir $zipFile"
        # $c | Out-Host
        $this.invoke($c)
        if ($this.isCommandNotFound()) {
            throw "unzip command not found."
        }
        return $expandDir
    }
}
