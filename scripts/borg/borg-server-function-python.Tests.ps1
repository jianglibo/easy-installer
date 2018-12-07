$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

. "${ScriptDir}\global-variables.ps1"

$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
# . "$here\$sut"

. "$here\borg-client-function.ps1"

".\ssh-invoker.ps1", ".\common-util.ps1", ".\clientside-util.ps1", "common-for-t.ps1" | ForEach-Object {
    . "${ScriptDir}\common\$_"
}

function Get-ConfigurationForT {
    param(
        [switch]$vb
    )
    $borgDir = $Global:ScriptDir | Join-Path -ChildPath "borg" 
    $PSDefaultParameterValues['*:Verbose'] = $vb
    Copy-TestPsScriptToServer -HerePath $borgDir -Lang python
    Get-Configuration -ConfigFile ( $borgDir | Join-Path -ChildPath "demo-config.python.1.json")
}

Describe "echo" {
    it "should echo." {
        Get-ConfigurationForT -vb
        $r = Invoke-ServerRunningPs1 -action Echo you are always on my mind.
        $r | Write-Verbose
        $r | Receive-LinesFromServer | Should -Be 'you are always on my mind.'
    }
}

Describe "install" {
    it "should install borg." {
        Get-ConfigurationForT -vb
        $Global:sshinvoker.invoke("rm $($Global:configuration.BorgBin)")
        $r = Invoke-ServerRunningPs1 -action Install
        $r | Receive-LinesFromServer | Should -Be 'Install Success.'
        $r = Invoke-ServerRunningPs1 -action Install
        $r | Receive-LinesFromServer | Should -Be 'AlreadyInstalled'
    }
}

Describe "uninstall borg successly." {
    it "should uninstall." {
        Get-ConfigurationForT -vb
        $r = Invoke-ServerRunningPs1 -Action uninstall -notCombineError
        $r | Receive-LinesFromServer | should -Be 'Uninstall successly.'
    }
}

Describe "init borg repo successly." {
    it "should init repo." {
        Get-ConfigurationForT -vb
        $cmd = "rm -rf $($Global:configuration.BorgRepoPath)"
        $Global:sshinvoker.invoke($cmd)
        $r = Invoke-ServerRunningPs1 -Action InitializeRepo
        $r | Write-Verbose
        $r | Receive-LinesFromServer | should -Be 'SUCCESS'

        $r = Invoke-ServerRunningPs1 -Action InitializeRepo
        $r | Write-Verbose
        $rs = [string]$r
        $rs -match 'returned non-zero' | Should -BeTrue
    }
}

Describe "download public key." {
    it "should get public key file name." {
        Get-ConfigurationForT -vb
        $r = Invoke-ServerRunningPs1 -Action DownloadPublicKey
        $v = $r | Receive-LinesFromServer
        $v | Should -Match "^/tmp/.*"
        $r = $Global:sshinvoker.invoke("cat $v")
        $r | Write-Verbose
    }
}

Describe "new borg archive successly." {
    it "should create new borg archive." {
        Get-ConfigurationForT -vb
        $r = Invoke-ServerRunningPs1 -Action Archive
        $r | Write-Verbose
        $r = $r | Receive-LinesFromServer | ConvertFrom-Json
        $r.archive.stats.compressed_size | should -BeTrue
    }
}

Describe "borg prune." {
    it "should prune borg archive." {
        Get-ConfigurationForT -vb
        $r = Invoke-ServerRunningPs1 -Action Prune
        $r | Write-Verbose
        [array]$r = $r | Receive-LinesFromServer
        $r.Count | should -GT 0
    }
}

Describe "download borg repo." {
    it "should download borg repo." {
        Get-ConfigurationForT -vb
        $d = Get-MaxLocalDir
        Remove-Item -Path $d -Recurse -Force
        $r = Copy-BorgRepoFiles
        $r | ConvertTo-Json -Depth 10 | Write-Verbose
        $r.copied.Length | Should -GT 0

        $r = Copy-BorgRepoFiles
        $r | ConvertTo-Json -Depth 10 | Write-Verbose
        $r.copied.Length | Should -Be 0

    }
}

Describe "file hashes in a directory." {
    it "should get file hashes." {
        Get-ConfigurationForT -vb
        $r = Invoke-ServerRunningPs1 -Action FileHashes '/etc/NetworkManager'
        $r | Write-Verbose
        $r = $r | Receive-LinesFromServer | ConvertFrom-Json
        $r.Count | Should -BeGreaterThan 0
        $r[0].Algorithm | Should -BeTrue
        $r | Write-Verbose
    }
}

Describe "copy changed files." {
    it "should copy changed files." {
        Get-ConfigurationForT
        $Error.Clear()
        $repo = Get-MaxLocalDir
        if (Test-Path -Path $repo) {
            Remove-Item -Recurse -Force -Path $repo
        }
        $r = Copy-ChangedFiles -RemoteDirectory '/etc/NetworkManager' -LocalDirectory $repo
        $r | ConvertTo-Json -Depth 10 | Write-Verbose
        $r.failed | Should -BeTrue
        $r.total.files | Should -BeTrue
        $r.total.Length | Should -Be $r.copied.Length
        
        $r = Copy-ChangedFiles -RemoteDirectory '/etc/NetworkManager' -LocalDirectory $repo -OnlySum
        $r | Write-Verbose
        $r.copied.Count | Should -Be 0

        $repo = Get-MaxLocalDir -Next
        if (Test-Path -Path $repo) {
            Remove-Item -Recurse -Force -Path $repo
        }
        $r = Copy-ChangedFiles -RemoteDirectory '/etc/NetworkManager' -LocalDirectory $repo
        $r | ConvertTo-Json | Write-Verbose
        $r.copied.Count | Should -GT 0
    }
}